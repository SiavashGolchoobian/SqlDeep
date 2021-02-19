CREATE TABLE [dbo].[DisplayToID]
(
[GUID] [uniqueidentifier] NOT NULL,
[RunID] [int] NULL,
[DisplayString] [varchar] (1024) COLLATE Arabic_CI_AS NOT NULL,
[LogStartTime] [char] (24) COLLATE Arabic_CI_AS NULL,
[LogStopTime] [char] (24) COLLATE Arabic_CI_AS NULL,
[NumberOfRecords] [int] NULL,
[MinutesToUTC] [int] NULL,
[TimeZoneName] [char] (32) COLLATE Arabic_CI_AS NULL
) ON [Data_OLTP]
GO
ALTER TABLE [dbo].[DisplayToID] ADD CONSTRAINT [PK__DisplayT__15B69B8E0F975522] PRIMARY KEY CLUSTERED  ([GUID]) WITH (FILLFACTOR=100, PAD_INDEX=ON) ON [Data_OLTP]
GO
ALTER TABLE [dbo].[DisplayToID] ADD CONSTRAINT [UQ__DisplayT__FA63CFA61273C1CD] UNIQUE NONCLUSTERED  ([DisplayString]) WITH (FILLFACTOR=100, PAD_INDEX=ON, DATA_COMPRESSION = PAGE) ON [Index_All]
GO
GRANT INSERT ON  [dbo].[DisplayToID] TO [role_kpi_insert]
GO
GRANT SELECT ON  [dbo].[DisplayToID] TO [role_kpi_insert]
GO
GRANT SELECT ON  [dbo].[DisplayToID] TO [role_kpi_select]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'TABLE', N'DisplayToID', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-01-01', 'SCHEMA', N'dbo', 'TABLE', N'DisplayToID', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'TABLE', N'DisplayToID', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TABLE', N'DisplayToID', NULL, NULL
GO
