CREATE TABLE [dbo].[ScriptRepositoryHost]
(
[RecordId] [bigint] NOT NULL IDENTITY(-9223372036854775807, 1),
[FileUniqueName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[FileType] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_ScriptRepositoryHost_ScriptType] DEFAULT (N'TSQL'),
[FileContent] [varbinary] (max) NOT NULL,
[AudienceType] [nvarchar] (4000) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_ScriptRepositoryHost_AudienceType] DEFAULT (N'BRANCH'),
[AudienceDatabase] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_ScriptRepositoryHost_TargetDatabase] DEFAULT (N'master'),
[CreatedDate] [datetime] NOT NULL CONSTRAINT [DF_ScriptRepositoryHost_CreatedDate] DEFAULT (getdate()),
[Description] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[IsEnabled] [bit] NOT NULL CONSTRAINT [DF_ScriptRepositoryHost_IsEnabled] DEFAULT ((0)),
[RecordRef] [bigint] NULL,
[HostChecksum] AS (binary_checksum([RecordId],[FileUniqueName],[FileType],[FileContent],[AudienceType],[AudienceDatabase],[CreatedDate],[IsEnabled],[RecordRef])) PERSISTED,
[RowVersion] [timestamp] NOT NULL
) ON [Data_OLTP]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE TRIGGER [dbo].[ScriptRepositoryHost_UD]
   ON  [dbo].[ScriptRepositoryHost]
   AFTER DELETE,UPDATE
AS 
BEGIN
	IF (@@ROWCOUNT=0)
		RETURN;

	PRINT ('Update and Delete is prevented on this table because possibiliy of orders conflict.')
	ROLLBACK
END
GO
ALTER TABLE [dbo].[ScriptRepositoryHost] ADD CONSTRAINT [CHK_dbo_ScriptRepositoryHost_FileType] CHECK (([FileType]='OTHER' OR [FileType]='POWERSHELL' OR [FileType]='TSQL' OR [FileType]='CMD'))
GO
ALTER TABLE [dbo].[ScriptRepositoryHost] ADD CONSTRAINT [PK_dbo_ScriptRepositoryHost] PRIMARY KEY CLUSTERED ([RecordId]) WITH (FILLFACTOR=85) ON [Data_OLTP]
GO
CREATE UNIQUE NONCLUSTERED INDEX [UNQ_FileUniqueName] ON [dbo].[ScriptRepositoryHost] ([FileUniqueName]) WITH (FILLFACTOR=85, PAD_INDEX=ON) ON [Index_All]
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
CREATE UNIQUE NONCLUSTERED INDEX [UNQ_ReferencceChain] ON [dbo].[ScriptRepositoryHost] ([RecordRef]) WHERE ([RecordRef] IS NOT NULL) WITH (FILLFACTOR=85) ON [Index_All]
GO
ALTER TABLE [dbo].[ScriptRepositoryHost] ADD CONSTRAINT [FK_ScriptRepositoryHost_ScriptRepositoryHost] FOREIGN KEY ([RecordRef]) REFERENCES [dbo].[ScriptRepositoryHost] ([RecordId])
GO
GRANT SELECT ON  [dbo].[ScriptRepositoryHost] TO [role_sqldeep_repo]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'TABLE', N'ScriptRepositoryHost', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'dbo', 'TABLE', N'ScriptRepositoryHost', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'dbo', 'TABLE', N'ScriptRepositoryHost', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TABLE', N'ScriptRepositoryHost', NULL, NULL
GO
