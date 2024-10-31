SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <06/04/2019>
-- Version:		<3.0.0.0>
-- Description:	<Insert or Update a new asset into dbo.ScriptRepositoryHost table on central management host>
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
	@Metadata XML,
	@AllowToReplaceIfExist BIT=1,
	@AllowGenerateMetadata BIT=0
	) AS
BEGIN
	SET NOCOUNT ON
	DECLARE @myLatestItemVersion nvarchar(50)
	DECLARE @myStatement NVARCHAR(MAX)
	DECLARE @myStatementParams NVARCHAR(255)
	
	SET @myLatestItemVersion =(SELECT TOP 1 [ItemVersion] FROM [repository].[Publisher] WHERE ItemName=@ItemName ORDER BY [ItemVersion] DESC)
	IF @AllowGenerateMetadata=1
	BEGIN
		EXEC [repository].[dbasp_analyze_file_dependencies] @FilePath,@Metadata OUTPUT
	END

	IF @myLatestItemVersion IS NOT NULL AND @AllowToReplaceIfExist=1 AND @ItemVersion IS NULL
	BEGIN
		SET @ItemVersion=@myLatestItemVersion
	END
	ELSE IF @ItemVersion IS NULL
	BEGIN
		SET @ItemVersion=N'1.0'
	END

	IF EXISTS (SELECT [ItemVersion] FROM [repository].[Publisher] WHERE ItemName=@ItemName AND [ItemVersion]=@ItemVersion)
	BEGIN
		SET @myStatementParams=N'@myItemName nvarchar(255),@myItemType nvarchar(50),@myItemVersion nvarchar(50),@myTags nvarchar(4000),@myDescription nvarchar(4000),@myIsEnabled bit,@myMetadata xml'
		SET @myStatement=N'
		UPDATE [repository].[Publisher] SET
			   [ItemType]=ISNULL(@myItemType,[ItemType]),
			   [ItemContent]=ISNULL( (SELECT [FileContent].* FROM OPENROWSET (BULK N''' + @FilePath + ''', SINGLE_BLOB) AS [FileContent]) , [ItemContent]),
			   [Tags]=ISNULL(@myTags,[Tags]),
			   [Description]=ISNULL(@myDescription,[Description]),
			   [IsEnabled]=ISNULL(@myIsEnabled,[IsEnabled]),
			   [Metadata]=ISNULL(@myMetadata,[Metadata])
		WHERE
			   [ItemName]=@myItemName
			   AND [ItemVersion]=@myItemVersion
		'
	END
	ELSE
	BEGIN
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
	END

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
