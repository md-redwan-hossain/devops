DECLARE
    v_schema_name VARCHAR2(10) := 'YOUR_SCHEMA_NAME'; -- Replace with your schema name
BEGIN
--     Disable all foreign key constraints
    FOR c IN ( SELECT constraint_name, table_name
               FROM all_constraints
               WHERE owner = v_schema_name AND constraint_type = 'R' )
        LOOP
            EXECUTE IMMEDIATE 'ALTER TABLE ' || v_schema_name || '.' || c.table_name || ' DISABLE CONSTRAINT ' ||
                              c.constraint_name;
        END LOOP;

    -- Truncate all tables except migration history
    FOR t IN ( SELECT table_name FROM all_tables WHERE owner = v_schema_name AND table_name <> '__EFMigrationsHistory' )
        LOOP
            EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || v_schema_name || '.' || t.table_name;
        END LOOP;

    -- Re-enable all foreign key constraints
    FOR c IN ( SELECT constraint_name, table_name
               FROM all_constraints
               WHERE owner = v_schema_name AND constraint_type = 'R' )
        LOOP
            EXECUTE IMMEDIATE 'ALTER TABLE ' || v_schema_name || '.' || c.table_name || ' ENABLE CONSTRAINT ' ||
                              c.constraint_name;
        END LOOP;
END;
/

 ALTER TABLE IGMT4.SEW_PROCESS_OB || '.' || c.table_name || ' DISABLE CONSTRAINT ' ||
                              c.constraint_name;