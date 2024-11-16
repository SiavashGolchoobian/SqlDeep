CREATE TABLE [trace].[ResourceLogHistory]
(
[Id] [bigint] NOT NULL IDENTITY(1, 1),
[MemoryBroker_Allocations_KB_Internal] [bigint] NOT NULL,
[MemoryBroker_Allocations_KB_Defult] [bigint] NOT NULL,
[MemoryConsumers_Allocated_KB] [bigint] NOT NULL,
[MemoryConsumers_Used_KB] [bigint] NOT NULL,
[LogTime] [datetime] NULL CONSTRAINT [DF_trace_ResourceLogHistory_LogTime] DEFAULT (getdate()),
[SysRowVersion] [timestamp] NOT NULL
) ON [Data_OLTP]
WITH
(
DATA_COMPRESSION = PAGE
)
GO
ALTER TABLE [trace].[ResourceLogHistory] ADD CONSTRAINT [PK_trace_ResourceLogHistory] PRIMARY KEY CLUSTERED ([Id]) WITH (FILLFACTOR=90, PAD_INDEX=ON, DATA_COMPRESSION = PAGE) ON [Data_OLTP]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'trace', 'TABLE', N'ResourceLogHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2024-11-16', 'SCHEMA', N'trace', 'TABLE', N'ResourceLogHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2024-11-16', 'SCHEMA', N'trace', 'TABLE', N'ResourceLogHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'trace', 'TABLE', N'ResourceLogHistory', NULL, NULL
GO
