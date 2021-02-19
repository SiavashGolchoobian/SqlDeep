CREATE TABLE [maintenance].[BackupCatalogs_Primary]
(
[PrimaryID] [int] NOT NULL IDENTITY(1, 1),
[BackupRequestRef] [int] NOT NULL,
[DestinationPath] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[BackupDate] [datetime] NOT NULL CONSTRAINT [DF_BackupCatalogs_StartDate] DEFAULT (getdate()),
[ExpiredDate] [date] NOT NULL,
[FileDate] [datetime] NOT NULL,
[FileSize] [varchar] (100) COLLATE Arabic_CI_AS NOT NULL,
[Deleted] [bit] NOT NULL CONSTRAINT [DF_BackupCatalogs_Primary_Deleted] DEFAULT ((0)),
[LogDate] [datetime] NOT NULL CONSTRAINT [DF_BackupCatalogs_Primary_LogDate] DEFAULT (getdate())
) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[BackupCatalogs_Primary] ADD CONSTRAINT [PK_BackupCatalogs_Primary] PRIMARY KEY CLUSTERED  ([PrimaryID]) WITH (FILLFACTOR=80, PAD_INDEX=ON) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [MissedIDX01_BackupRequestRefDestinationPath] ON [maintenance].[BackupCatalogs_Primary] ([BackupRequestRef], [DestinationPath]) WITH (FILLFACTOR=80, PAD_INDEX=ON, DATA_COMPRESSION = PAGE) ON [Index_All]
GO
CREATE NONCLUSTERED INDEX [MissedIDX02_Deleted1] ON [maintenance].[BackupCatalogs_Primary] ([Deleted]) INCLUDE ([BackupRequestRef], [DestinationPath], [BackupDate], [ExpiredDate]) WITH (FILLFACTOR=80, PAD_INDEX=ON, DATA_COMPRESSION = PAGE) ON [Index_All]
GO
ALTER TABLE [maintenance].[BackupCatalogs_Primary] ADD CONSTRAINT [FK_BackupCatalogs_Primary_BackupRequests] FOREIGN KEY ([BackupRequestRef]) REFERENCES [maintenance].[BackupRequests] ([BackupRequestID]) ON UPDATE CASCADE
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'BackupCatalogs_Primary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-08-10', 'SCHEMA', N'maintenance', 'TABLE', N'BackupCatalogs_Primary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'BackupCatalogs_Primary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'BackupCatalogs_Primary', NULL, NULL
GO
