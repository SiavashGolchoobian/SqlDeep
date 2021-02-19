CREATE TABLE [maintenance].[FileBaseRequests]
(
[BackupRequestRef] [int] NOT NULL,
[ScenarioName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_FileBaseRequests_ScenarioName] DEFAULT ('Clone Original Backup Scenario'),
[TransferSeries] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[Enabled] [bit] NOT NULL CONSTRAINT [DF_FileBaseRequests_Enabled] DEFAULT ((1))
) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[FileBaseRequests] ADD CONSTRAINT [PK_FileBaseRequests_1] PRIMARY KEY CLUSTERED  ([BackupRequestRef], [ScenarioName]) WITH (FILLFACTOR=100, PAD_INDEX=ON) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[FileBaseRequests] ADD CONSTRAINT [FK_FileBaseRequests_BackupRequests] FOREIGN KEY ([BackupRequestRef]) REFERENCES [maintenance].[BackupRequests] ([BackupRequestID]) ON UPDATE CASCADE
GO
ALTER TABLE [maintenance].[FileBaseRequests] ADD CONSTRAINT [FK_FileBaseRequests_Lookup_TransferSeries] FOREIGN KEY ([TransferSeries]) REFERENCES [maintenance].[Lookup_TransferSeries] ([TransferSeries])
GO
ALTER TABLE [maintenance].[FileBaseRequests] ADD CONSTRAINT [FK_FileBaseRequests_TimeBaseScenarios] FOREIGN KEY ([ScenarioName]) REFERENCES [maintenance].[TimeBaseScenarios] ([ScenarioName]) ON UPDATE CASCADE
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'FileBaseRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-16', 'SCHEMA', N'maintenance', 'TABLE', N'FileBaseRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'FileBaseRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'FileBaseRequests', NULL, NULL
GO
