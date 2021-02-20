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
--	@AudienceType:		BRANCH,WAREHOUSE,X,Y This is a comma seperated filter for repository to retrive related records according to filter(s)
--	@IgnoreRowVersion:	If true, skip rowversion base change detection
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_scriptrepository_downloadfromhost] (@LinkedServerName NVARCHAR(128), @AudienceType NVARCHAR(50)=N'BRANCH', @IgnoreRowVersion BIT = 0) AS
BEGIN
	SET NOCOUNT ON
	SET @LinkedServerName = REPLACE(REPLACE(@LinkedServerName,N'[',N''),N']',N'')
	IF EXISTS(SELECT 1 FROM sys.[servers] WHERE name=@LinkedServerName)
	BEGIN
		DECLARE @myLastChange AS BINARY(8)
		DECLARE @myLastRecord AS BIGINT
		DECLARE @myInnerCommand NVARCHAR(MAX)
		DECLARE @myBigIntMinVal BIGINT
		DECLARE @myAudienceTable TABLE ([Position] INT, [Parameter] NVARCHAR(MAX))
		DECLARE @myAudienceList NVARCHAR(MAX)
		
		SET @myBigIntMinVal=-9223372036854775808
		SET @myAudienceList = CAST(N'' AS NVARCHAR(MAX))
		INSERT INTO @myAudienceTable([Position],[Parameter]) SELECT [myList].[Position], [myList].[Parameter] FROM [dbo].[dbafn_split](',',@AudienceType) AS myList WHERE LEN([myList].[Parameter])>0
		SELECT @myAudienceList=@myAudienceList + N',''''' + [myList].[Parameter] + N'''''' FROM @myAudienceTable AS myList
		SET @myAudienceList = CASE WHEN LEN(@myAudienceList)>0 THEN RIGHT(@myAudienceList,LEN(@myAudienceList)-1) ELSE NULL END
		SET @myLastRecord=ISNULL((SELECT MAX([ScriptRepositoryGuest].[RecordId]) FROM [dbo].[ScriptRepositoryGuest]),@myBigIntMinVal)
		SET @myLastChange=ISNULL((SELECT MAX([RowVersion]) FROM [dbo].[ScriptRepositoryGuest]),0)

		SET @myInnerCommand = N'INSERT INTO [SqlDeep].[dbo].[ScriptRepositoryGuest](RecordId,ScriptText,TargetDatabase,ScriptType,AudienceType,Attachment,CreatedDate,RecordRef,CheckValue,RowVersion) SELECT RecordId,ScriptText,TargetDatabase,ScriptType,AudienceType,Attachment,CreatedDate,RecordRef,CheckValue,RowVersion FROM OPENQUERY([' + @LinkedServerName + '],''Select RecordId,ScriptText,TargetDatabase,ScriptType,AudienceType,Attachment,CreatedDate,RecordRef,CheckValue,RowVersion FROM [SqlDeep].[dbo].[ScriptRepositoryHost] WHERE '+ 
								CASE @IgnoreRowVersion WHEN 0 THEN 'CONVERT(BIGINT,RowVersion) > ' + CAST(CONVERT(BIGINT, @myLastChange) AS NVARCHAR(MAX)) + N' AND ' ELSE N'' END +
								N'RecordId > ' + CAST(@myLastRecord AS NVARCHAR(MAX)) + N' AND AudienceType IN (' + @myAudienceList +')'')'
		PRINT @myInnerCommand
		EXEC sp_executeSQL @myInnerCommand
	END
	ELSE
	BEGIN
		PRINT 'LinkedServerName does not exists.'
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_downloadfromhost', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_downloadfromhost', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_downloadfromhost', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_downloadfromhost', NULL, NULL
GO
