SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <06/04/2019>
-- Version:		<3.0.0.0>
-- Description:	<Download new and modified scripts from dbo.ScriptRepositoryHost table on central management host>
-- Implementation Note:	You should deploy "dbasp_scriptrepository_downloadfromhost" , "dbasp_scriptrepository_versioncontrol" and "dbasp_scriptrepository_executeonguest" sp's in the guest machine(s) and also you should create "ScriptRepositoryGuest" table on that guest machine(s) too.
--						IN Host machine you need to have only "ScriptRepositoryHost" table and insert your script's in this table as a central repository.
--						After these settings, in guest machine(s) you should create a LinkedServer to HostMachine and create then a job on guest machine(s) to run "dbasp_scriptrepository_downloadfromhost" sp at the first step, then "dbasp_scriptrepository_versioncontrol" at the second step and "dbasp_scriptrepository_executeonguest" sp at the last step, also that job should be fail and stop if each step is failed and does not go to next step
-- =============================================
CREATE PROCEDURE [repository].[dbasp_upload_to_publisher] (
	@ItemName nvarchar(255),
	@ItemType nvarchar(50),
	@ItemVersion nvarchar(50),
	@FilePath nvarchar(256),
	@Tags nvarchar(4000),
	@Description nvarchar(4000),
	@IsEnabled bit=1,
	@Metadata xml
	) AS
BEGIN
	SET NOCOUNT ON
	DECLARE @myStatement NVARCHAR(MAX)
	DECLARE @myStatementParams NVARCHAR(255)
	SET @myStatementParams=N'@myItemName nvarchar(255),@myItemType nvarchar(50),@myItemVersion nvarchar(50),@myTags nvarchar(4000),@myDescription nvarchar(4000),@myIsEnabled bit,@myMetadata xml'
	SET @myStatement=N'
	INSERT INTO [repository].[Publisher]
           ([ItemName]
           ,[ItemType]
           ,[ItemVersion]
           ,[ItemContent]
           ,[Tags]
           ,[CreateDate]
           ,[UpdateDate]
           ,[Description]
           ,[IsEnabled]
           ,[Metadata])
     VALUES
           (@myItemName,
           @myItemType,
           @myItemVersion,
           (SELECT [FileContent].* FROM OPENROWSET (BULK N''' + @FilePath + ''', SINGLE_BLOB) AS [FileContent]),
           @myTags,
           GETDATE(),
           GETDATE(),
           @myDescription,
           @myIsEnabled,
           @myMetadata)
	'
	Print @myStatement
	EXECUTE sp_executesql @myStatement,@myStatementParams,@myItemName=@ItemName,@myItemType=@ItemType,@myItemVersion=@ItemVersion,@myTags=@Tags,@myDescription=@Description,@myIsEnabled=@IsEnabled,@myMetadata=@Metadata
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_upload_to_publisher', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_upload_to_publisher', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_upload_to_publisher', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_upload_to_publisher', NULL, NULL
GO
