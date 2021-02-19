CREATE TABLE [maintenance].[Lookup_BackupTypes]
(
[BackupType] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[Abbreviation] [char] (1) COLLATE Arabic_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[Lookup_BackupTypes] ADD CONSTRAINT [PK_BackupTypes] PRIMARY KEY CLUSTERED  ([BackupType]) WITH (FILLFACTOR=100, PAD_INDEX=ON) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[Lookup_BackupTypes] ADD CONSTRAINT [UNQ_BackupTypes] UNIQUE NONCLUSTERED  ([Abbreviation]) WITH (FILLFACTOR=100, PAD_INDEX=ON, DATA_COMPRESSION = PAGE) ON [Index_All]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'Lookup_BackupTypes', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-12', 'SCHEMA', N'maintenance', 'TABLE', N'Lookup_BackupTypes', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'Lookup_BackupTypes', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'Lookup_BackupTypes', NULL, NULL
GO
