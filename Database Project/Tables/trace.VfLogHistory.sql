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
ALTER TABLE [trace].[VfLogHistory] ADD CONSTRAINT [PK_VfLogHistory] PRIMARY KEY CLUSTERED ([RecordId]) WITH (FILLFACTOR=90, PAD_INDEX=ON) ON [Data_OLTP]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'trace', 'TABLE', N'VfLogHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-06-25', 'SCHEMA', N'trace', 'TABLE', N'VfLogHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'trace', 'TABLE', N'VfLogHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'trace', 'TABLE', N'VfLogHistory', NULL, NULL
GO
