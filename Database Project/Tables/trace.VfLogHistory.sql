CREATE TABLE [trace].[VfLogHistory]
(
[RecordId] [bigint] NOT NULL IDENTITY(1, 1),
[SnapshotId] [bigint] NOT NULL,
[database_id] [smallint] NOT NULL,
[file_id] [smallint] NOT NULL,
[num_of_reads] [bigint] NOT NULL,
[io_stall_read_ms] [bigint] NOT NULL,
[num_of_writes] [bigint] NOT NULL,
[io_stall_write_ms] [bigint] NOT NULL,
[io_stall] [bigint] NOT NULL,
[num_of_bytes_read] [bigint] NOT NULL,
[num_of_bytes_written] [bigint] NOT NULL,
[file_handle] [varbinary] (8) NOT NULL,
[LogTime] [datetime] NOT NULL
) ON [Data_OLTP]
GO
ALTER TABLE [trace].[VfLogHistory] ADD CONSTRAINT [PK_VfLogHistory] PRIMARY KEY CLUSTERED  ([RecordId]) WITH (FILLFACTOR=90, PAD_INDEX=ON) ON [Data_OLTP]
GO
