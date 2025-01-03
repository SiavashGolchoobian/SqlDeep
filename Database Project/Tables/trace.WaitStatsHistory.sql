CREATE TABLE [trace].[WaitStatsHistory]
(
[RecordId] [bigint] NOT NULL IDENTITY(1, 1),
[WaitType] [nvarchar] (60) COLLATE Arabic_CI_AS NOT NULL,
[Wait_Sec] [decimal] (14, 2) NULL,
[Resource_Sec] [decimal] (14, 2) NULL,
[Signal_Sec] [decimal] (14, 2) NULL,
[WaitCount] [bigint] NOT NULL,
[Percentage] [decimal] (4, 2) NULL,
[AvgWait_Sec] [decimal] (14, 4) NULL,
[AvgRes_Sec] [decimal] (14, 4) NULL,
[AvgSig_Sec] [decimal] (14, 4) NULL,
[LogTime] [datetime] NOT NULL
) ON [Data_OLTP]
GO
ALTER TABLE [trace].[WaitStatsHistory] ADD CONSTRAINT [PK_trace_WaitStatsHistory] PRIMARY KEY CLUSTERED ([RecordId]) WITH (FILLFACTOR=85) ON [Data_OLTP]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'trace', 'TABLE', N'WaitStatsHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-06-25', 'SCHEMA', N'trace', 'TABLE', N'WaitStatsHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'trace', 'TABLE', N'WaitStatsHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'trace', 'TABLE', N'WaitStatsHistory', NULL, NULL
GO
