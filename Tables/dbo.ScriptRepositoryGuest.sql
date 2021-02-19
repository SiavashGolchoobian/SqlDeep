CREATE TABLE [dbo].[ScriptRepositoryGuest]
(
[RecordId] [bigint] NOT NULL,
[ScriptText] [nvarchar] (max) COLLATE Arabic_CI_AS NOT NULL,
[TargetDatabase] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL,
[ScriptType] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[AudienceType] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_ScriptRepositoryGuest_AudienceType] DEFAULT (N'BRANCH'),
[Attachment] [varbinary] (max) NULL,
[CreatedDate] [datetime] NOT NULL,
[RecordRef] [bigint] NULL,
[CheckValue] [int] NOT NULL,
[RowVersion] [binary] (8) NOT NULL,
[CalculatedCheckValue] AS (binary_checksum([RecordId],[ScriptText],[TargetDatabase],[ScriptType],[AudienceType],[CreatedDate],[RecordRef],[Attachment])) PERSISTED,
[DownloadDate] [datetime] NOT NULL CONSTRAINT [DF__ScriptRep__Downl__329245C1] DEFAULT (getdate()),
[IsEnabled] [bit] NOT NULL CONSTRAINT [DF_ScriptRepositoryGuest_IsEnabled] DEFAULT ((1)),
[LastExecutionDate] [datetime] NULL,
[LastExecutionStatus] [nvarchar] (50) COLLATE Arabic_CI_AS NULL,
[ExecutionLog] [nvarchar] (max) COLLATE Arabic_CI_AS NULL
) ON [PRIMARY]
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
CREATE TRIGGER [dbo].[ScriptRepositoryGuest_U]
   ON  [dbo].[ScriptRepositoryGuest]
   AFTER UPDATE
AS 
BEGIN
	IF (@@ROWCOUNT=0)
		RETURN;

	IF UPDATE([RecordId]) OR UPDATE([ScriptText]) OR UPDATE([TargetDatabase]) OR UPDATE([ScriptType]) OR UPDATE([AudienceType]) OR UPDATE([Attachment]) OR UPDATE([CreatedDate]) OR UPDATE([RecordRef]) OR UPDATE([CheckValue]) OR UPDATE([RowVersion]) OR UPDATE([DownloadDate])
	BEGIN
		PRINT ('Updating for some field(s) is not permitted.')
		ROLLBACK
	END
END
GO
ALTER TABLE [dbo].[ScriptRepositoryGuest] ADD CONSTRAINT [PK__ScriptRe__FBDF78E9963EEBBD] PRIMARY KEY CLUSTERED  ([RecordId]) WITH (FILLFACTOR=85) ON [PRIMARY]
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
CREATE UNIQUE NONCLUSTERED INDEX [UNQ_ReferencceChain] ON [dbo].[ScriptRepositoryGuest] ([RecordRef]) WHERE ([RecordRef] IS NOT NULL) WITH (FILLFACTOR=85) ON [PRIMARY]
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
