#!/usr/bin/env dotnet
#:package Npgsql@10.*
#:package Refit.HttpClientFactory@16.*
#:package Microsoft.Extensions.Hosting@10.*
#:package Microsoft.Extensions.Http@10.*
#:property PublishAot=false

using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Npgsql;
using NpgsqlTypes;
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
    .AddRefitGeneratedClient<ISequinStreamApi>(new RefitSettings
    {
        AuthorizationHeaderValueGetter = (_, _) => ValueTask.FromResult(sequinApiToken)
    })
    .ConfigureHttpClient(client =>
    {
        client.BaseAddress = new Uri(sequinBaseUrl + "/");
        client.Timeout = TimeSpan.FromSeconds(60);
    });

builder.Services.AddHostedService<AuditStreamConsumerHostedService>();

await builder.Build().RunAsync();

static string RequireEnv(string name) =>
    Environment.GetEnvironmentVariable(name)
    ?? throw new InvalidOperationException($"Missing required env var: {name}");

static int ParseInt(string name, int fallback) =>
    int.TryParse(Environment.GetEnvironmentVariable(name), out var value) ? value : fallback;

sealed record WorkerSettings(string ConsumerName, int BatchSize, int WaitForMs, int PollIdleMs);

[Headers("Authorization: Bearer")]
public interface ISequinStreamApi
{
    [Get("/api/http_pull_consumers/{consumer}/receive")]
    Task<ApiResponse<SequinReceiveResponse>> ReceiveAsync(
        string consumer,
        [Query] int batch_size,
        [Query] int wait_for,
        CancellationToken ct);

    [Post("/api/http_pull_consumers/{consumer}/ack")]
    Task<IApiResponse> AckAsync(string consumer, [Body] AckRequest body, CancellationToken ct);
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

sealed record AuditRow(
    Guid Id,
    DateTime OccurredAt,
    string SchemaName,
    string TableName,
    string OperationType,
    string RowIdentity,
    string? RowChanges,
    long CommitLsn,
    string? UserId);

sealed class AuditStreamConsumerHostedService(
    ISequinStreamApi sequin,
    NpgsqlDataSource dataSource,
    WorkerSettings settings,
    ILogger<AuditStreamConsumerHostedService> logger) : BackgroundService
{
    private const string CreateTempSql = """
        CREATE TEMP TABLE tmp_audit_logs (
            id uuid,
            occurred_at timestamptz,
            schema_name varchar(70),
            table_name varchar(70),
            operation_type varchar(1),
            row_identity jsonb,
            row_changes jsonb,
            commit_lsn bigint,
            user_id varchar(70)
        ) ON COMMIT DROP
        """;

    private const string CopySql = """
        COPY tmp_audit_logs (
            id, occurred_at, schema_name, table_name, operation_type,
            row_identity, row_changes, commit_lsn, user_id
        ) FROM STDIN (FORMAT BINARY)
        """;

    private const string MergeSql = """
        INSERT INTO public.audit_logs (
            id, occurred_at, schema_name, table_name, operation_type,
            row_identity, row_changes, commit_lsn, user_id
        )
        SELECT
            id, occurred_at, schema_name, table_name, operation_type,
            row_identity, row_changes, commit_lsn, user_id
        FROM tmp_audit_logs
        ON CONFLICT (row_identity, commit_lsn) DO UPDATE SET
            occurred_at = EXCLUDED.occurred_at,
            schema_name = EXCLUDED.schema_name,
            table_name = EXCLUDED.table_name,
            operation_type = EXCLUDED.operation_type,
            row_changes = EXCLUDED.row_changes,
            user_id = EXCLUDED.user_id
        """;

    // ApiException = HTTP error response
    // ApiRequestException = connection/transport failure (e.g. refused)
    private const string SequinUnavailableMessage =
        "No connection could be made to the Sequin stream API";

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
                var messages = await ReceiveMessagesAsync(stoppingToken);
                if (messages is null)
                {
                    if (!await DelayOrStopAsync(stoppingToken))
                        break;
                    continue;
                }

                if (messages.Count == 0)
                {
                    if (!await DelayOrStopAsync(stoppingToken))
                        break;
                    continue;
                }

                var ackIds = new List<string>(messages.Count);
                var rows = new List<AuditRow>(messages.Count);

                foreach (var msg in messages)
                {
                    ackIds.Add(msg.AckId);

                    if (msg.Action is not ("insert" or "update" or "delete"))
                        continue;

                    if (msg.Metadata.TableSchema == "public" &&
                        msg.Metadata.TableName == "audit_logs")
                        continue;

                    var operationType = msg.Action switch
                    {
                        "insert" => "i",
                        "update" => "u",
                        "delete" => "d",
                        _ => throw new InvalidOperationException($"Unexpected action: {msg.Action}")
                    };

                    string? rowChanges = msg.Action == "delete"
                        ? null
                        : msg.Record.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null
                            ? null
                            : msg.Record.GetRawText();

                    rows.Add(new AuditRow(
                        Guid.CreateVersion7(),
                        msg.Metadata.CommitTimestamp.UtcDateTime,
                        msg.Metadata.TableSchema,
                        msg.Metadata.TableName,
                        operationType,
                        JsonSerializer.Serialize(msg.Metadata.RecordPks),
                        rowChanges,
                        msg.Metadata.CommitLsn,
                        TryReadUserId(msg.Metadata.TransactionAnnotations)));
                }

                if (rows.Count > 0)
                    await BulkUpsertAsync(rows, stoppingToken);

                if (ackIds.Count > 0 && !await AckMessagesAsync(ackIds, stoppingToken))
                {
                    if (!await DelayOrStopAsync(stoppingToken))
                        break;
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Audit stream poll failed; will retry");
                if (!await DelayOrStopAsync(stoppingToken))
                    break;
            }
        }
    }

    private async Task<List<SequinMessage>?> ReceiveMessagesAsync(CancellationToken ct)
    {
        try
        {
            var data = await sequin.ReceiveAsync(
                settings.ConsumerName,
                settings.BatchSize,
                settings.WaitForMs,
                ct);
            await data.EnsureSuccessfulAsync();
            return data.Content?.Data ?? [];
        }
        catch (Exception ex) when (ex is ApiException or ApiRequestException)
        {
            logger.LogError(ex, "{Message}", SequinUnavailableMessage);
            return null;
        }
    }

    private async Task<bool> AckMessagesAsync(List<string> ackIds, CancellationToken ct)
    {
        try
        {
            var data = await sequin.AckAsync(
                settings.ConsumerName,
                new AckRequest { AckIds = ackIds.ToArray() },
                ct);
            await data.EnsureSuccessfulAsync();
            return true;
        }
        catch (Exception ex) when (ex is ApiException or ApiRequestException)
        {
            logger.LogError(ex, "{Message}", SequinUnavailableMessage);
            return false;
        }
    }

    private async Task BulkUpsertAsync(List<AuditRow> rows, CancellationToken stoppingToken)
    {
        await using var conn = await dataSource.OpenConnectionAsync(stoppingToken);
        await using var tx = await conn.BeginTransactionAsync(stoppingToken);

        await using (var createCmd = new NpgsqlCommand(CreateTempSql, conn, tx))
        {
            await createCmd.ExecuteNonQueryAsync(stoppingToken);
        }

        await using (var writer = await conn.BeginBinaryImportAsync(CopySql, stoppingToken))
        {
            foreach (var row in rows)
            {
                await writer.StartRowAsync(stoppingToken);
                await writer.WriteAsync(row.Id, NpgsqlDbType.Uuid, stoppingToken);
                await writer.WriteAsync(row.OccurredAt, NpgsqlDbType.TimestampTz, stoppingToken);
                await writer.WriteAsync(row.SchemaName, NpgsqlDbType.Varchar, stoppingToken);
                await writer.WriteAsync(row.TableName, NpgsqlDbType.Varchar, stoppingToken);
                await writer.WriteAsync(row.OperationType, NpgsqlDbType.Varchar, stoppingToken);
                await writer.WriteAsync(row.RowIdentity, NpgsqlDbType.Jsonb, stoppingToken);

                if (row.RowChanges is null)
                    await writer.WriteNullAsync(stoppingToken);
                else
                    await writer.WriteAsync(row.RowChanges, NpgsqlDbType.Jsonb, stoppingToken);

                await writer.WriteAsync(row.CommitLsn, NpgsqlDbType.Bigint, stoppingToken);

                if (row.UserId is null)
                    await writer.WriteNullAsync(stoppingToken);
                else
                    await writer.WriteAsync(row.UserId, NpgsqlDbType.Varchar, stoppingToken);
            }

            await writer.CompleteAsync(stoppingToken);
        }

        await using (var mergeCmd = new NpgsqlCommand(MergeSql, conn, tx))
        {
            await mergeCmd.ExecuteNonQueryAsync(stoppingToken);
        }

        await tx.CommitAsync(stoppingToken);
    }

    private async Task<bool> DelayOrStopAsync(CancellationToken stoppingToken)
    {
        try
        {
            await Task.Delay(settings.PollIdleMs, stoppingToken);
            return true;
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            return false;
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
