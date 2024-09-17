CREATE TABLE [dbo].[ScriptRepositoryGuest]
(
[RecordId] [bigint] NOT NULL,
[FileUniqueName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[FileType] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[FileContent] [varbinary] (max) NOT NULL,
[AudienceType] [nvarchar] (4000) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_ScriptRepositoryGuest_AudienceType] DEFAULT (N'BRANCH'),
[AudienceDatabase] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL,
[CreatedDate] [datetime] NOT NULL,
[IsEnabled] [bit] NOT NULL CONSTRAINT [DF_ScriptRepositoryGuest_IsEnabled] DEFAULT ((1)),
[RecordRef] [bigint] NULL,
[HostChecksum] [int] NOT NULL,
[RowVersion] [binary] (8) NOT NULL,
[GuestChecksum] AS (binary_checksum([RecordId],[FileUniqueName],[FileType],[FileContent],[AudienceType],[AudienceDatabase],[CreatedDate],[IsEnabled],[RecordRef])) PERSISTED,
[DownloadDate] [datetime] NOT NULL CONSTRAINT [DF_ScriptRepositoryGuest_DownloadDate] DEFAULT (getdate()),
[LastExecutionDate] [datetime] NULL,
[LastExecutionStatus] [nvarchar] (50) COLLATE Arabic_CI_AS NULL,
[ExecutionLog] [nvarchar] (max) COLLATE Arabic_CI_AS NULL
) ON [PRIMARY]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ScriptRepositoryGuest_U]
   ON  [dbo].[ScriptRepositoryGuest]
   AFTER UPDATE
AS 
BEGIN
	IF (@@ROWCOUNT=0)
		RETURN;

	IF UPDATE([RecordId]) OR UPDATE([FileUniqueName]) OR UPDATE([FileType]) OR UPDATE([FileContent]) OR UPDATE([AudienceDatabase]) OR UPDATE([AudienceType]) OR UPDATE([CreatedDate]) OR UPDATE([IsEnabled]) OR UPDATE([RecordRef]) OR UPDATE([HostChecksum]) OR UPDATE([RowVersion]) OR UPDATE([DownloadDate])
	BEGIN
		PRINT ('Updating for some field(s) is not permitted.')
		ROLLBACK
	END
END
GO
ALTER TABLE [dbo].[ScriptRepositoryGuest] ADD CONSTRAINT [CHK_dbo_ScriptRepositoryGuest_FileType] CHECK (([FileType]='OTHER' OR [FileType]='POWERSHELL' OR [FileType]='TSQL' OR [FileType]='CMD'))
GO
ALTER TABLE [dbo].[ScriptRepositoryGuest] ADD CONSTRAINT [PK_dbo_ScriptRepositoryGuest] PRIMARY KEY CLUSTERED ([RecordId]) WITH (FILLFACTOR=85) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [UNQ_dbo_ScriptRepositoryGuest_FileUniqueName] ON [dbo].[ScriptRepositoryGuest] ([FileUniqueName]) WITH (FILLFACTOR=85) ON [PRIMARY]
GO
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING ON
GO
SET ANSI_WARNINGS ON
GO
SET CONCAT_NULL_YIELDS_NULL ON
GO
SET ARITHABORT ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE UNIQUE NONCLUSTERED INDEX [UNQ_dbo_ScriptRepositoryGuest_ReferencceChain] ON [dbo].[ScriptRepositoryGuest] ([RecordRef]) WHERE ([RecordRef] IS NOT NULL) WITH (FILLFACTOR=85) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'ATTENTION', N'این جدول در سرور مرکزی مورد نیاز نمیباشد، این جدول را باید در دیتابیس DBA در سرورهای شعب ایجاد کنید', 'SCHEMA', N'dbo', 'TABLE', N'ScriptRepositoryGuest', NULL, NULL
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'TABLE', N'ScriptRepositoryGuest', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'dbo', 'TABLE', N'ScriptRepositoryGuest', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'dbo', 'TABLE', N'ScriptRepositoryGuest', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TABLE', N'ScriptRepositoryGuest', NULL, NULL
GO
