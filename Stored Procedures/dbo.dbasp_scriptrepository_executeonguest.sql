SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Golchoobian>
-- Create date: <06/04/2019>
-- Version:		<3.0.0.0>
-- Description:	<Execute downloaded scripts that archived on Guest dbo.ScriptRepositoryGuest in sequentialy order>
-- Implementation Note:	You should deploy "dbasp_scriptrepository_downloadfromhost" , "dbasp_scriptrepository_versioncontrol" and "dbasp_scriptrepository_executeonguest" sp's in the guest machine(s) and also you should create "ScriptRepositoryGuest" table on that guest machine(s) too.
--						IN Host machine you need to have only "ScriptRepositoryHost" table and insert your script's in this table as a central repository.
--						After these settings, in guest machine(s) you should create a LinkedServer to HostMachine and create then a job on guest machine(s) to run "dbasp_scriptrepository_downloadfromhost" sp at the first step, then "dbasp_scriptrepository_versioncontrol" at the second step and "dbasp_scriptrepository_executeonguest" sp at the last step, also that job should be fail and stop if each step is failed and does not go to next step
-- Input Parameters:
--	@IgnoreCheckValue:	Igonre compare Hash check, recommended to set this value to 0
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_scriptrepository_executeonguest] (@IgnoreCheckValue BIT=0) AS
BEGIN
	DECLARE @myCurrentDate DATETIME
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myRecordId BIGINT
	DECLARE @myScriptText NVARCHAR(MAX)
	DECLARE @myTargetDatabase NVARCHAR(128)
	DECLARE @myLastExecutionStatus NVARCHAR(50)
	DECLARE @myReplacedRecordId BIGINT
	DECLARE @myHighWaterMarkRecordId BIGINT
	DECLARE @myStatus_SUCCEED NVARCHAR(50)
	DECLARE @myStatus_CANCELED NVARCHAR(50)
	DECLARE @myStatus_FAILED NVARCHAR(50)
	DECLARE @myStatus_INPROGRESS NVARCHAR(50)
	DECLARE @myErrorMessage NVARCHAR(4000)
	DECLARE @myErrorState INT
	DECLARE @myEPVersionKey NVARCHAR(255)
	DECLARE @myIgnoreCheckValue BIT
	DECLARE @myBigIntMinVal BIGINT;

	SET @myIgnoreCheckValue=@IgnoreCheckValue
	SET @myBigIntMinVal=-9223372036854775808
	SET @myErrorState=1
	SET @myEPVersionKey=N'Build'
	SET @myStatus_SUCCEED=N'SUCCEED'
	SET @myStatus_CANCELED=N'CANCELED'
	SET @myStatus_FAILED=N'FAILED'
	SET @myStatus_INPROGRESS=N'INPROGRESS'
	SET @myNewLine=CHAR(13)+CHAR(10)
	
	--Phase 3: Execute downloaded commands from local repository
	WHILE EXISTS (	SELECT 1 
					FROM [dbo].[ScriptRepositoryGuest] AS myGuest 
					WHERE	[myGuest].[IsEnabled]=1
							AND CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myGuest].[CalculatedCheckValue] END = CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myGuest].[CheckValue] END
							AND ISNULL([myGuest].[LastExecutionStatus], N'') NOT IN (@myStatus_SUCCEED,@myStatus_CANCELED)
				 )
	BEGIN
		SET @myCurrentDate=GETDATE()
		SET @myScriptText = CAST(N'' AS NVARCHAR(MAX))
		SELECT TOP 1
			@myRecordId=[myGuest].[RecordId],
			@myLastExecutionStatus=[myGuest].[LastExecutionStatus]
		FROM 
			[dbo].[ScriptRepositoryGuest] AS myGuest 
		WHERE	
			[myGuest].[IsEnabled]=1
			AND CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myGuest].[CalculatedCheckValue] END = CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myGuest].[CheckValue] END
			AND ISNULL([myGuest].[LastExecutionStatus], N'') NOT IN (@myStatus_SUCCEED,@myStatus_CANCELED)
		ORDER BY 
			[myGuest].[RecordId]

		--Step 01: Raise erroe for InProgress pending task
			IF @myLastExecutionStatus=@myStatus_INPROGRESS
			BEGIN
				SET @myErrorMessage=CAST(N'Script Id #' AS NVARCHAR(MAX)) + CAST(@myRecordId AS NVARCHAR(MAX)) + N' stoped in ''InProgress'' status.'
				RAISERROR (
					@myErrorMessage, -- Message text.
					11 ,--@ErrorSeverity, -- Severity.
					@myErrorState -- State.
					) WITH LOG;
				--BREAK
			END

		--Step 02: Replacing this order with last newer related order
			SET @myHighWaterMarkRecordId=@myRecordId
			IF EXISTS (SELECT 1 FROM [dbo].[ScriptRepositoryGuest] WHERE [RecordId]>@myRecordId AND [IsEnabled]=1 AND CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [CalculatedCheckValue] END = CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [CheckValue] END AND [RecordRef]=@myRecordId)
			BEGIN
				SET @myReplacedRecordId=NULL
				CREATE TABLE #ReferenceChain (RecordId BIGINT, RecordRef BIGINT, [Level] INT);
				WITH myReferenceChain AS (
					SELECT [RecordId],[RecordRef],0 AS [Level] FROM [dbo].[ScriptRepositoryGuest] WHERE [RecordId]=@myRecordId
					UNION ALL
					SELECT [myChild].[RecordId],[myChild].[RecordRef],[myReferenceChain].[Level]+1 AS [Level] FROM [dbo].[ScriptRepositoryGuest] AS myChild INNER JOIN [myReferenceChain] ON [myReferenceChain].[RecordId] = [myChild].[RecordRef] WHERE [myChild].[RecordId]!=@myRecordId AND [myChild].[IsEnabled]=1 AND CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myChild].[CalculatedCheckValue] END = CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myChild].[CheckValue] END
				)
				INSERT INTO [#ReferenceChain] ([RecordId],[RecordRef],[Level]) SELECT [RecordId],[RecordRef],[Level] FROM [myReferenceChain]
				SELECT TOP 1 @myReplacedRecordId=[RecordId] FROM [#ReferenceChain] ORDER BY [Level] DESC
				UPDATE [mySource] SET 
					[LastExecutionStatus]=@myStatus_CANCELED,
					[ExecutionLog]=CAST(N'Canceled on ' AS NVARCHAR(MAX)) + CAST(@myCurrentDate AS NVARCHAR(MAX)) + CAST(N' - ' + @myNewLine AS NVARCHAR(MAX)) + CAST(N'Because of replaced RecordId ' AS NVARCHAR(MAX)) + CAST(@myReplacedRecordId AS NVARCHAR(MAX)) + CAST(@myNewLine + N'-----' AS NVARCHAR(MAX)) + ISNULL(CAST([mySource].[ExecutionLog] AS NVARCHAR(MAX)),CAST(N'' AS NVARCHAR(MAX)))
				FROM
					[dbo].[ScriptRepositoryGuest] AS mySource
					INNER JOIN [#ReferenceChain] AS myChain ON [myChain].[RecordId] = [mySource].[RecordId]
				WHERE
					[mySource].[RecordId] <> @myReplacedRecordId
				DROP TABLE [#ReferenceChain]
				SET @myRecordId=@myReplacedRecordId
			END

		--Sep03: Retriving order parameters
			SELECT TOP 1
				@myScriptText=[myGuest].[ScriptText],
				@myTargetDatabase=[myGuest].[TargetDatabase],
				@myLastExecutionStatus=[myGuest].[LastExecutionStatus]
			FROM 
				[dbo].[ScriptRepositoryGuest] AS myGuest 
			WHERE	
				[myGuest].[IsEnabled]=1
				AND CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myGuest].[CalculatedCheckValue] END = CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myGuest].[CheckValue] END
				AND ISNULL([myGuest].[LastExecutionStatus], N'') NOT IN (@myStatus_SUCCEED,@myStatus_CANCELED)
				AND [myGuest].[RecordId]=@myRecordId

			BEGIN TRY
				SET @myScriptText = 
					N'USE [' + @myTargetDatabase + '] '+
					@myNewLine + 'DECLARE @myScript NVARCHAR(MAX)'+
					@myNewLine + 'SET @myScript = ''' + REPLACE(@myScriptText,'''','''''') + N''''+
					@myNewLine + 'EXECUTE sp_executesql @myScript'

				UPDATE [dbo].[ScriptRepositoryGuest] SET [LastExecutionStatus]=@myStatus_INPROGRESS,[LastExecutionDate]=GETDATE() WHERE [RecordId]=@myRecordId
				EXECUTE (@myScriptText);
				UPDATE [dbo].[ScriptRepositoryGuest] SET [LastExecutionStatus]=@myStatus_SUCCEED WHERE [RecordId]=@myRecordId
				--Update Database Version
				SET @myScriptText = N'
				IF EXISTS(SELECT 1 FROM [' + @myTargetDatabase + N'].sys.extended_properties WHERE class=0 AND name=N'''+ @myEPVersionKey +''')
				BEGIN
					EXEC [' + @myTargetDatabase + N'].sys.sp_updateextendedproperty @name=N''' + @myEPVersionKey + ''', @value=''' + CAST(@myHighWaterMarkRecordId as nvarchar(max)) + N'''
				END
				ELSE
				BEGIN
					EXEC [' + @myTargetDatabase + N'].sys.sp_addextendedproperty @name=N''' + @myEPVersionKey + ''', @value=''' + CAST(@myHighWaterMarkRecordId as nvarchar(max)) + N'''
				END'
				EXECUTE (@myScriptText);
			END TRY
			BEGIN CATCH
				UPDATE [dbo].[ScriptRepositoryGuest] SET [LastExecutionStatus]=@myStatus_FAILED, [ExecutionLog]=CAST(N'FAILED on ' AS NVARCHAR(MAX)) + CAST(GETDATE() AS NVARCHAR(MAX)) + CAST(N' - ' + @myNewLine AS NVARCHAR(MAX)) + CAST(ERROR_MESSAGE() AS NVARCHAR(MAX)) + CAST(@myNewLine + N'-----' AS NVARCHAR(MAX)) + ISNULL(CAST([ExecutionLog] AS NVARCHAR(MAX)),CAST(N'' AS NVARCHAR(MAX))) WHERE [RecordId]=@myRecordId

				SET @myErrorMessage=CAST(N'Script Id #' AS NVARCHAR(MAX)) + CAST(@myRecordId AS NVARCHAR(MAX)) + N' Failed: ' + @myNewLine+ + CAST(ERROR_MESSAGE() AS NVARCHAR(3600))
				RAISERROR (
					@myErrorMessage, -- Message text.
					11 ,--@ErrorSeverity, -- Severity.
					@myErrorState -- State.
					) WITH LOG;
				BREAK
			END CATCH
	END
	
	--Phase 4: Find Last applied version from repository and reset Database version with that value for preventing from incoorect database version because of replaced recordId's
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_executeonguest', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_executeonguest', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_executeonguest', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_executeonguest', NULL, NULL
GO
