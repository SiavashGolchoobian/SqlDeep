CREATE TABLE [maintenance].[BackupRequests]
(
[BackupRequestID] [int] NOT NULL,
[ServerName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[InstanceName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_BackupRequests_InstanceName] DEFAULT (N'MSSQLSERVER'),
[DBName] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[BackupType] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_BackupRequests_BackupType] DEFAULT ('FULL'),
[DestVarFolderPath] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_BackupRequests_DestVarFolderPath] DEFAULT ('D:\Backup\{%INSTANCE_ADDRESS%}\{%JL_YEAR_NUM%}\{%JL_MONTH_NUM%}\{%JL_DAYOFMONTH_NUM%}'),
[DestVarFilename] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_BackupRequests_DestVarFilename] DEFAULT ('{%BACKUP_TYPE%}_{%DBNAME%}_{%JL_YEAR_NUM%}_{%JL_MONTH_NUM%}_{%JL_DAYOFMONTH_NUM%}_on_{%HOUR%}_{%MINUTE%}_{%SECOND%}.bak'),
[RetantionDays] [int] NOT NULL CONSTRAINT [DF_BackupRequests_RetantionDays] DEFAULT ((31)),
[CopyOnlyMode] [bit] NOT NULL CONSTRAINT [DF_Backups_BackupInCopyOnlyMode] DEFAULT ((0)),
[ShrinkLogToSizeMB] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_BackupRequests_ShrinkLogToSizeMB] DEFAULT ((-1)),
[TransferSeries] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[Enabled] [bit] NOT NULL CONSTRAINT [DF_BackupRequests_Enabled] DEFAULT ((1))
) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[BackupRequests] ADD CONSTRAINT [PK_BackupRequests] PRIMARY KEY CLUSTERED  ([BackupRequestID]) WITH (FILLFACTOR=90, PAD_INDEX=ON) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[BackupRequests] ADD CONSTRAINT [FK_BackupRequests_Lookup_TransferSeries] FOREIGN KEY ([TransferSeries]) REFERENCES [maintenance].[Lookup_TransferSeries] ([TransferSeries]) ON UPDATE CASCADE
GO
ALTER TABLE [maintenance].[BackupRequests] ADD CONSTRAINT [FK_Backups_BackupTypes] FOREIGN KEY ([BackupType]) REFERENCES [maintenance].[Lookup_BackupTypes] ([BackupType]) ON UPDATE CASCADE
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'BackupRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-14', 'SCHEMA', N'maintenance', 'TABLE', N'BackupRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'BackupRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'BackupRequests', NULL, NULL
GO
