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
-- Input Parameters:
--	@LinkedServerName:	Central management host LinkedServer name
--	@@Tags:				BRANCH,WAREHOUSE,X,Y This is a comma seperated filter for repository to retrive related records according to filter(s)
-- =============================================
CREATE PROCEDURE [repository].[dbasp_download_from_publisher] (@LinkedServerName NVARCHAR(128), @Tags NVARCHAR(4000)=N'TSX') AS
BEGIN
	SET NOCOUNT ON
	SET @LinkedServerName = REPLACE(REPLACE(@LinkedServerName,N'[',N''),N']',N'')
	IF EXISTS(SELECT 1 FROM [sys].[servers] WHERE name=@LinkedServerName)
	BEGIN
		DECLARE @myStatement NVARCHAR(MAX)
		DECLARE @myStatementParams NVARCHAR(255)
		DECLARE @myLinkedServerName NVARCHAR(128)
		DECLARE @myRequestedTags NVARCHAR(4000)
		
		SET @myLinkedServerName=@LinkedServerName
		SET @myRequestedTags=@Tags
		SET @myLinkedServerName = REPLACE(REPLACE(@myLinkedServerName,N'[',N''),N']',N'')
		SET @myStatementParams=N'@LinkedServerName NVARCHAR(128),@RequestedTags NVARCHAR(4000)'
		SET @myStatement='
		MERGE [repository].[Subscriber] AS mySubscriber
		USING ( SELECT [myPublisherResult].* FROM OPENQUERY(['+@myLinkedServerName+'],''
				SELECT DISTINCT [ItemId],[ItemName],[ItemType],[ItemVersion],[ItemContent],[Tags],[CreateDate],[UpdateDate],[Description],[IsEnabled],CAST([Metadata] AS NVARCHAR(MAX)) AS [Metadata],[ItemChecksum],[RowVersion] 
				FROM [repository].[Publisher] 
				CROSS APPLY [SqlDeep].[dbo].[dbafn_split]('''','''',[Tags]) AS myPublisherTags 
				INNER JOIN (SELECT [myRequestedTags].[Position], [myRequestedTags].[Parameter] FROM [dbo].[dbafn_split]('''','''','''''+ @myRequestedTags +''''') AS myRequestedTags WHERE LEN([myRequestedTags].[Parameter])>0) AS myRequestedTags ON [myPublisherTags].[Parameter]=[myRequestedTags].[Parameter]
				'') AS myPublisherResult
				) AS myPublisher
		ON ([mySubscriber].[ItemId] = [myPublisher].[ItemId] AND [mySubscriber].[PublisherName]=@LinkedServerName)
		WHEN MATCHED AND ([mySubscriber].[ItemChecksum]<>[myPublisher].[ItemChecksum] OR [mySubscriber].[RowVersion]<>[myPublisher].[RowVersion]) THEN 
			UPDATE SET 
			[SubscriberDownloadDate] = getdate(),
			[SubscriberExecutionResult] = N''NOT EXECUTED'',
			[PublisherName] = @LinkedServerName,
			[ItemId] = [myPublisher].[ItemId],
			[ItemName] = [myPublisher].[ItemName],
			[ItemType] = [myPublisher].[ItemType],
			[ItemVersion] = [myPublisher].[ItemVersion],
			[ItemContent] = [myPublisher].[ItemContent],
			[Tags] = [myPublisher].[Tags],
			[CreateDate] = [myPublisher].[CreateDate],
			[UpdateDate] = [myPublisher].[UpdateDate],
			[Description] = [myPublisher].[Description],
			[IsEnabled] = [myPublisher].[IsEnabled],
			[Metadata] = [myPublisher].[Metadata],
			[ItemChecksum] = [myPublisher].[ItemChecksum],
			[RowVersion] = [myPublisher].[RowVersion]
		WHEN NOT MATCHED BY TARGET THEN
			INSERT ([SubscriberDownloadDate],[SubscriberExecutionResult],[PublisherName],[ItemId],[ItemName],[ItemType],[ItemVersion],[ItemContent],[Tags],[CreateDate],[UpdateDate],[Description],[IsEnabled],[Metadata],[ItemChecksum],[RowVersion])
			VALUES (getdate(),N''NOT EXECUTED'',@LinkedServerName,[myPublisher].[ItemId],[myPublisher].[ItemName],[myPublisher].[ItemType],[myPublisher].[ItemVersion],[myPublisher].[ItemContent],[myPublisher].[Tags],[myPublisher].[CreateDate],[myPublisher].[UpdateDate],[myPublisher].[Description],[myPublisher].[IsEnabled],[myPublisher].[Metadata],[myPublisher].[ItemChecksum],[myPublisher].[RowVersion])
		WHEN NOT MATCHED BY SOURCE AND [mySubscriber].[PublisherName]=@LinkedServerName AND [mySubscriber].[Tags] IN (SELECT CAST([Parameter] AS NVARCHAR(4000)) FROM [dbo].[dbafn_split]('','',@RequestedTags) WHERE LEN([Parameter])>0) THEN
			DELETE;
		'
		Print @myStatement
		EXECUTE sp_executesql @myStatement,@myStatementParams,@LinkedServerName=@myLinkedServerName,@RequestedTags=@myRequestedTags
	END
	ELSE
	BEGIN
		PRINT 'LinkedServerName does not exists.'
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_download_from_publisher', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_download_from_publisher', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_download_from_publisher', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_download_from_publisher', NULL, NULL
GO
