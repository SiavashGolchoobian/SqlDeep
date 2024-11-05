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
CREATE PROCEDURE [repository].[dbasp_upload_to_publisher_byfilepath] (
	@ItemName NVARCHAR(255),
	@ItemType NVARCHAR(50),
	@ItemVersion NVARCHAR(50),
	@FilePath NVARCHAR(256),
	@Tags NVARCHAR(4000),
	@Description NVARCHAR(4000),
	@IsEnabled BIT=1,
	@Metadata XML,
	@AllowToReplaceIfExist BIT=1,
	@AllowGenerateMetadata BIT=0
	) AS
BEGIN
	SET NOCOUNT ON
	DECLARE @myStatement NVARCHAR(MAX)
	DECLARE @myStatementParams NVARCHAR(255)
	DECLARE @ItemContent VARBINARY(MAX)
	
	SET @myStatementParams=N'@ItemContent VARBINARY(MAX) OUTPUT'
	SET @myStatement=N'SET @ItemContent=(SELECT [FileContent].* FROM OPENROWSET (BULK N''' + @FilePath + ''', SINGLE_BLOB) AS [FileContent])'
	EXECUTE sp_executesql @myStatement,@myStatementParams,@ItemContent=@ItemContent OUTPUT
	EXECUTE [repository].[dbasp_upload_to_publisher] @ItemName,@ItemType,@ItemVersion,@ItemContent,@Tags,@Description,@IsEnabled,@Metadata,@AllowToReplaceIfExist,@AllowGenerateMetadata
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_upload_to_publisher_byfilepath', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_upload_to_publisher_byfilepath', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_upload_to_publisher_byfilepath', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_upload_to_publisher_byfilepath', NULL, NULL
GO
