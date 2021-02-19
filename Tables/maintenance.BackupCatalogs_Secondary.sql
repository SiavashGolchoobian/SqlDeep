CREATE TABLE [maintenance].[BackupCatalogs_Secondary]
(
[SecondaryID] [int] NOT NULL IDENTITY(1, 1),
[PrimaryRef] [int] NOT NULL,
[ScenarioName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[ScenarioRuleRef] [int] NOT NULL,
[DestinationPath] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[ExpiredDate] [date] NOT NULL,
[FileDate] [datetime] NOT NULL,
[FileSize] [varchar] (100) COLLATE Arabic_CI_AS NOT NULL,
[Deleted] [bit] NOT NULL CONSTRAINT [DF_BackupCatalogs_Secondary_Deleted] DEFAULT ((0)),
[LogDate] [datetime] NOT NULL CONSTRAINT [DF_BackupCatalogs_Secondary_LogDate] DEFAULT (getdate())
) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[BackupCatalogs_Secondary] ADD CONSTRAINT [PK_BackupCatalogs_Secondary] PRIMARY KEY CLUSTERED  ([SecondaryID]) WITH (FILLFACTOR=80, PAD_INDEX=ON) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [MissedIDX01_Deleted] ON [maintenance].[BackupCatalogs_Secondary] ([Deleted]) INCLUDE ([SecondaryID], [ScenarioName], [ScenarioRuleRef], [DestinationPath], [ExpiredDate]) WITH (FILLFACTOR=80, PAD_INDEX=ON, DATA_COMPRESSION = PAGE) ON [Index_All]
GO
ALTER TABLE [maintenance].[BackupCatalogs_Secondary] ADD CONSTRAINT [UNQ_BackupCatalogs_Secondary] UNIQUE NONCLUSTERED  ([DestinationPath]) WITH (FILLFACTOR=90, PAD_INDEX=ON, DATA_COMPRESSION = PAGE) ON [Index_All]
GO
ALTER TABLE [maintenance].[BackupCatalogs_Secondary] ADD CONSTRAINT [FK_BackupCatalogs_Secondary_BackupCatalogs_Primary] FOREIGN KEY ([PrimaryRef]) REFERENCES [maintenance].[BackupCatalogs_Primary] ([PrimaryID]) ON DELETE CASCADE ON UPDATE CASCADE
GO
ALTER TABLE [maintenance].[BackupCatalogs_Secondary] ADD CONSTRAINT [FK_BackupCatalogs_Secondary_TimeBaseScenarioRules] FOREIGN KEY ([ScenarioName], [ScenarioRuleRef]) REFERENCES [maintenance].[TimeBaseScenarioRules] ([ScenarioName], [RuleID]) ON DELETE CASCADE ON UPDATE CASCADE
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'BackupCatalogs_Secondary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-08-10', 'SCHEMA', N'maintenance', 'TABLE', N'BackupCatalogs_Secondary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'BackupCatalogs_Secondary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'BackupCatalogs_Secondary', NULL, NULL
GO
