CREATE TABLE [repository].[Publisher]
(
[ItemId] [bigint] NOT NULL IDENTITY(-9223372036854775807, 1),
[ItemName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[ItemType] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_Repository_Publisher_ItemType] DEFAULT (N'TSQL'),
[ItemVersion] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[ItemContent] [varbinary] (max) NOT NULL,
[Tags] [nvarchar] (4000) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_Repository_Publisher_Tags] DEFAULT (N'TSX'),
[CreateDate] [datetime] NOT NULL CONSTRAINT [DF_Repository_Publisher_CreateDate] DEFAULT (getdate()),
[UpdateDate] [datetime] NOT NULL CONSTRAINT [DF_Repository_Publisher_UpdateDate] DEFAULT (getdate()),
[Description] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[IsEnabled] [bit] NOT NULL CONSTRAINT [DF_Repository_Publisher_IsEnabled] DEFAULT ((0)),
[Metadata] [xml] NULL,
[ItemChecksum] AS (binary_checksum([ItemId],[ItemName],[ItemType],[ItemContent],[Metadata])) PERSISTED,
[RowVersion] [timestamp] NOT NULL
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
CREATE TRIGGER [repository].[repository_Publisher_D]
   ON  [repository].[Publisher]
   INSTEAD OF DELETE
AS 
BEGIN
	UPDATE [repository].[Publisher] SET UpdateDate=getdate(),IsEnabled=0 WHERE [ItemId] IN (Select ItemId FROM [deleted])
END
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
CREATE TRIGGER [repository].[repository_Publisher_U]
   ON  [repository].[Publisher]
   AFTER UPDATE
AS 
BEGIN
	UPDATE [repository].[Publisher] SET UpdateDate=getdate() WHERE [ItemId] IN (Select ItemId FROM [inserted])
END
GO
ALTER TABLE [repository].[Publisher] ADD CONSTRAINT [CHK_Repository_Publisher_ItemType] CHECK (([ItemType]='CMD' OR [ItemType]='TSQL' OR [ItemType]='POWERSHELL' OR [ItemType]='OTHER'))
GO
CREATE UNIQUE CLUSTERED INDEX [PK_Repository_Publisher] ON [repository].[Publisher] ([ItemId]) WITH (FILLFACTOR=85) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [UNQ_Repository_Publisher] ON [repository].[Publisher] ([ItemName], [ItemVersion]) WITH (FILLFACTOR=85) ON [PRIMARY]
GO
GRANT SELECT ON  [repository].[Publisher] TO [role_sqldeep_repo]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'repository', 'TABLE', N'Publisher', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'repository', 'TABLE', N'Publisher', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'repository', 'TABLE', N'Publisher', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'repository', 'TABLE', N'Publisher', NULL, NULL
GO
