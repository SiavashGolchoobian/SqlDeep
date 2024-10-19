CREATE TABLE [trace].[DBCCMemoryStatus]
(
[IDCol] [int] NOT NULL IDENTITY(1, 1),
[MemObjType] [varchar] (1200) COLLATE Arabic_CI_AS NULL,
[MemObjName] [varchar] (1200) COLLATE Arabic_CI_AS NULL,
[MemObjValue] [bigint] NULL,
[ValueType] [varchar] (20) COLLATE Arabic_CI_AS NULL
) ON [Index_All]
GO
ALTER TABLE [trace].[DBCCMemoryStatus] ADD CONSTRAINT [UNQ_IDCol] UNIQUE CLUSTERED ([IDCol]) WITH (FILLFACTOR=100, PAD_INDEX=ON) ON [Index_All]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'trace', 'TABLE', N'DBCCMemoryStatus', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-06-25', 'SCHEMA', N'trace', 'TABLE', N'DBCCMemoryStatus', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'trace', 'TABLE', N'DBCCMemoryStatus', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'trace', 'TABLE', N'DBCCMemoryStatus', NULL, NULL
GO
