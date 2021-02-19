CREATE TABLE [dbo].[CounterData]
(
[GUID] [uniqueidentifier] NOT NULL,
[CounterID] [int] NOT NULL,
[RecordIndex] [int] NOT NULL,
[CounterDateTime] [char] (24) COLLATE Arabic_CI_AS NOT NULL,
[CounterValue] [float] NOT NULL,
[FirstValueA] [int] NULL,
[FirstValueB] [int] NULL,
[SecondValueA] [int] NULL,
[SecondValueB] [int] NULL,
[MultiCount] [int] NULL
) ON [Data_OLTP]
GO
ALTER TABLE [dbo].[CounterData] ADD CONSTRAINT [PK__CounterD__1FB2147B1A14E395] PRIMARY KEY CLUSTERED  ([GUID], [CounterID], [RecordIndex]) WITH (FILLFACTOR=100, PAD_INDEX=ON) ON [Data_OLTP]
GO
CREATE NONCLUSTERED INDEX [IX_CounterID_CounterDateTime] ON [dbo].[CounterData] ([CounterID], [CounterDateTime]) INCLUDE ([CounterValue]) WITH (FILLFACTOR=100, PAD_INDEX=ON, DATA_COMPRESSION = PAGE) ON [Index_All]
GO
CREATE NONCLUSTERED INDEX [MissedIDX01_GuidRecordIndex] ON [dbo].[CounterData] ([GUID], [RecordIndex]) WITH (FILLFACTOR=80, PAD_INDEX=ON, DATA_COMPRESSION = PAGE) ON [Index_All]
GO
ALTER TABLE [dbo].[CounterData] WITH NOCHECK ADD CONSTRAINT [FK_CounterData_CounterDetails] FOREIGN KEY ([CounterID]) REFERENCES [dbo].[CounterDetails] ([CounterID])
GO
ALTER TABLE [dbo].[CounterData] WITH NOCHECK ADD CONSTRAINT [FK_CounterData_DisplayToID] FOREIGN KEY ([GUID]) REFERENCES [dbo].[DisplayToID] ([GUID])
GO
GRANT INSERT ON  [dbo].[CounterData] TO [role_kpi_insert]
GO
GRANT SELECT ON  [dbo].[CounterData] TO [role_kpi_insert]
GO
GRANT SELECT ON  [dbo].[CounterData] TO [role_kpi_select]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'TABLE', N'CounterData', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-01-01', 'SCHEMA', N'dbo', 'TABLE', N'CounterData', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'TABLE', N'CounterData', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TABLE', N'CounterData', NULL, NULL
GO
