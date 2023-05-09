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
ALTER TABLE [trace].[WaitStatsHistory] ADD CONSTRAINT [PK__WaitStat__FBDF78E9E5AE38EF] PRIMARY KEY CLUSTERED ([RecordId]) WITH (FILLFACTOR=85) ON [Data_OLTP]
GO
