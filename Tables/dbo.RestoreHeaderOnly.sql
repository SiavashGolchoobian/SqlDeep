CREATE TABLE [dbo].[RestoreHeaderOnly]
(
[RecordId] [bigint] NOT NULL IDENTITY(1, 1),
[BackupName] [nvarchar] (128) COLLATE Arabic_CI_AS NULL,
[BackupDescription] [nvarchar] (255) COLLATE Arabic_CI_AS NULL,
[BackupType] [smallint] NULL,
[ExpirationDate] [datetime] NULL,
[Compressed] [bit] NULL,
[Position] [smallint] NULL,
[DeviceType] [tinyint] NULL,
[UserName] [nvarchar] (128) COLLATE Arabic_CI_AS NULL,
[ServerName] [nvarchar] (128) COLLATE Arabic_CI_AS NULL,
[DatabaseName] [nvarchar] (128) COLLATE Arabic_CI_AS NULL,
[DatabaseVersion] [int] NULL,
[DatabaseCreationDate] [datetime] NULL,
[BackupSize] [numeric] (20, 0) NULL,
[FirstLSN] [numeric] (25, 0) NULL,
[LastLSN] [numeric] (25, 0) NULL,
[CheckpointLSN] [numeric] (25, 0) NULL,
[DatabaseBackupLSN] [numeric] (25, 0) NULL,
[BackupStartDate] [datetime] NULL,
[BackupFinishDate] [datetime] NULL,
[SortOrder] [smallint] NULL,
[CodePage] [smallint] NULL,
[UnicodeLocaleId] [int] NULL,
[UnicodeComparisonStyle] [int] NULL,
[CompatibilityLevel] [tinyint] NULL,
[SoftwareVendorId] [int] NULL,
[SoftwareVersionMajor] [int] NULL,
[SoftwareVersionMinor] [int] NULL,
[SoftwareVersionBuild] [int] NULL,
[MachineName] [nvarchar] (128) COLLATE Arabic_CI_AS NULL,
[Flags] [int] NULL,
[BindingID] [uniqueidentifier] NULL,
[RecoveryForkID] [uniqueidentifier] NULL,
[Collation] [nvarchar] (128) COLLATE Arabic_CI_AS NULL,
[FamilyGUID] [uniqueidentifier] NULL,
[HasBulkLoggedData] [bit] NULL,
[IsSnapshot] [bit] NULL,
[IsReadOnly] [bit] NULL,
[IsSingleUser] [bit] NULL,
[HasBackupChecksums] [bit] NULL,
[IsDamaged] [bit] NULL,
[BeginsLogChain] [bit] NULL,
[HasIncompleteMetaData] [bit] NULL,
[IsForceOffline] [bit] NULL,
[IsCopyOnly] [bit] NULL,
[FirstRecoveryForkID] [uniqueidentifier] NULL,
[ForkPointLSN] [numeric] (25, 0) NULL,
[RecoveryModel] [nvarchar] (60) COLLATE Arabic_CI_AS NULL,
[DifferentialBaseLSN] [numeric] (25, 0) NULL,
[DifferentialBaseGUID] [uniqueidentifier] NULL,
[BackupTypeDescription] [nvarchar] (60) COLLATE Arabic_CI_AS NULL,
[BackupSetGUID] [uniqueidentifier] NULL,
[CompressedBackupSize] [bigint] NULL,
[containment] [tinyint] NULL,
[KeyAlgorithm] [nvarchar] (32) COLLATE Arabic_CI_AS NULL,
[EncryptorThumbprint] [varbinary] (20) NULL,
[EncryptorType] [nvarchar] (32) COLLATE Arabic_CI_AS NULL,
[FileFullName] [nvarchar] (255) COLLATE Arabic_CI_AS NULL,
[LastExecutionStatus] [varchar] (50) COLLATE Arabic_CI_AS NULL,
[LastExecutionDate] [datetime] NULL
) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'TABLE', N'RestoreHeaderOnly', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-12-10', 'SCHEMA', N'dbo', 'TABLE', N'RestoreHeaderOnly', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'dbo', 'TABLE', N'RestoreHeaderOnly', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'dbo', 'TABLE', N'RestoreHeaderOnly', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TABLE', N'RestoreHeaderOnly', NULL, NULL
GO
