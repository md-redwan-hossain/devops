#!/usr/bin/env dotnet
#:package Npgsql@10.*
#:package Dapper@2.*
#:package Refit.HttpClientFactory@8.*
#:package Microsoft.Extensions.Hosting@10.*
#:package Microsoft.Extensions.Http@10.*
#:property PublishAot=false

using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Serialization;
using Dapper;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Npgsql;
using Refit;

var builder = Host.CreateApplicationBuilder(args);

var auditDb = RequireEnv("AUDIT_DB");
var sequinBaseUrl = RequireEnv("SEQUIN_BASE_URL").TrimEnd('/');
var sequinApiToken = RequireEnv("SEQUIN_API_TOKEN");
var consumerName = Environment.GetEnvironmentVariable("SEQUIN_CONSUMER_NAME") ?? "audit-stream";
var batchSize = ParseInt("BATCH_SIZE", 50);
var waitForMs = ParseInt("WAIT_FOR_MS", 5000);
var pollIdleMs = ParseInt("POLL_IDLE_MS", 1000);

builder.Services.AddSingleton(new WorkerSettings(
    consumerName,
    batchSize,
    waitForMs,
    pollIdleMs));

builder.Services.AddSingleton(_ => NpgsqlDataSource.Create(auditDb));

builder.Services
    .AddRefitClient<ISequinStreamApi>(new RefitSettings
    {
        ContentSerializer = new SystemTextJsonContentSerializer(new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        })
    })
    .ConfigureHttpClient(c =>
    {
        c.BaseAddress = new Uri(sequinBaseUrl + "/");
        c.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", sequinApiToken);
    });

builder.Services.AddHostedService<AuditStreamConsumerHostedService>();

await builder.Build().RunAsync();

static string RequireEnv(string name) =>
    Environment.GetEnvironmentVariable(name)
    ?? throw new InvalidOperationException($"Missing required env var: {name}");

static int ParseInt(string name, int fallback) =>
    int.TryParse(Environment.GetEnvironmentVariable(name), out var value) ? value : fallback;

sealed record WorkerSettings(string ConsumerName, int BatchSize, int WaitForMs, int PollIdleMs);

public interface ISequinStreamApi
{
    [Get("/api/http_pull_consumers/{consumer}/receive")]
    Task<SequinReceiveResponse> ReceiveAsync(
        string consumer,
        [Query] int batch_size,
        [Query] int wait_for,
        CancellationToken ct);

    [Post("/api/http_pull_consumers/{consumer}/ack")]
    Task AckAsync(string consumer, [Body] AckRequest body, CancellationToken ct);
}

public sealed class SequinReceiveResponse
{
    public List<SequinMessage> Data { get; set; } = [];
}

public sealed class SequinMessage
{
    [JsonPropertyName("ack_id")]
    public required string AckId { get; set; }

    public required string Action { get; set; }

    public JsonElement Record { get; set; }

    public required SequinMetadata Metadata { get; set; }
}

public sealed class SequinMetadata
{
    [JsonPropertyName("table_schema")]
    public required string TableSchema { get; set; }

    [JsonPropertyName("table_name")]
    public required string TableName { get; set; }

    [JsonPropertyName("commit_timestamp")]
    public DateTimeOffset CommitTimestamp { get; set; }

    [JsonPropertyName("commit_lsn")]
    public long CommitLsn { get; set; }

    [JsonPropertyName("record_pks")]
    public List<string> RecordPks { get; set; } = [];

    [JsonPropertyName("transaction_annotations")]
    public JsonElement? TransactionAnnotations { get; set; }
}

public sealed class AckRequest
{
    [JsonPropertyName("ack_ids")]
    public required string[] AckIds { get; init; }
}

sealed class AuditStreamConsumerHostedService(
    ISequinStreamApi sequin,
    NpgsqlDataSource dataSource,
    WorkerSettings settings,
    ILogger<AuditStreamConsumerHostedService> logger) : BackgroundService
{
    private const string UpsertSql = """
        INSERT INTO public.audit_logs (
            id, occurred_at, schema_name, table_name, operation_type,
            row_identity, row_changes, commit_lsn, user_id
        )
        VALUES (
            @Id, @OccurredAt, @SchemaName, @TableName, @OperationType,
            CAST(@RowIdentity AS jsonb), CAST(@RowChanges AS jsonb),
            @CommitLsn, @UserId
        )
        ON CONFLICT (row_identity, commit_lsn) DO UPDATE SET
            occurred_at = EXCLUDED.occurred_at,
            schema_name = EXCLUDED.schema_name,
            table_name = EXCLUDED.table_name,
            operation_type = EXCLUDED.operation_type,
            row_changes = EXCLUDED.row_changes,
            user_id = EXCLUDED.user_id
        """;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation(
            "Audit stream consumer started; consumer={Consumer} batch={Batch}",
            settings.ConsumerName,
            settings.BatchSize);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var messages = await sequin.ReceiveAsync(
                    settings.ConsumerName,
                    settings.BatchSize,
                    settings.WaitForMs,
                    stoppingToken);

                if (messages.Data.Count == 0)
                {
                    await Task.Delay(settings.PollIdleMs, stoppingToken);
                    continue;
                }

                var ackIds = new List<string>(messages.Data.Count);

                await using var conn = await dataSource.OpenConnectionAsync(stoppingToken);
                await using var tx = await conn.BeginTransactionAsync(stoppingToken);

                foreach (var msg in messages.Data)
                {
                    if (msg.Action is not ("insert" or "update" or "delete"))
                    {
                        ackIds.Add(msg.AckId);
                        continue;
                    }

                    if (msg.Metadata.TableSchema == "public" &&
                        msg.Metadata.TableName == "audit_logs")
                    {
                        ackIds.Add(msg.AckId);
                        continue;
                    }

                    var rowIdentity = JsonSerializer.Serialize(msg.Metadata.RecordPks);

                    string? rowChanges = msg.Action == "delete"
                        ? null
                        : msg.Record.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null
                            ? null
                            : msg.Record.GetRawText();

                    var operationType = msg.Action switch
                    {
                        "insert" => "i",
                        "update" => "u",
                        "delete" => "d",
                        _ => throw new InvalidOperationException($"Unexpected action: {msg.Action}")
                    };

                    var userId = TryReadUserId(msg.Metadata.TransactionAnnotations);

                    await conn.ExecuteAsync(new CommandDefinition(
                        UpsertSql,
                        new
                        {
                            Id = Guid.CreateVersion7(),
                            OccurredAt = msg.Metadata.CommitTimestamp.UtcDateTime,
                            SchemaName = msg.Metadata.TableSchema,
                            TableName = msg.Metadata.TableName,
                            OperationType = operationType,
                            RowIdentity = rowIdentity,
                            RowChanges = rowChanges,
                            CommitLsn = msg.Metadata.CommitLsn,
                            UserId = userId
                        },
                        transaction: tx,
                        cancellationToken: stoppingToken));

                    ackIds.Add(msg.AckId);
                }

                await tx.CommitAsync(stoppingToken);

                if (ackIds.Count > 0)
                {
                    await sequin.AckAsync(
                        settings.ConsumerName,
                        new AckRequest { AckIds = ackIds.ToArray() },
                        stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Audit stream poll failed; will retry");
                try
                {
                    await Task.Delay(settings.PollIdleMs, stoppingToken);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
            }
        }
    }

    private static string? TryReadUserId(JsonElement? annotations)
    {
        if (annotations is not { } el)
            return null;

        if (el.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null or JsonValueKind.False)
            return null;

        if (el.ValueKind != JsonValueKind.Object)
            return null;

        if (!el.TryGetProperty("user_id", out var userIdEl))
            return null;

        return userIdEl.ValueKind switch
        {
            JsonValueKind.String => userIdEl.GetString(),
            JsonValueKind.Number => userIdEl.GetRawText(),
            _ => null
        };
    }
}
