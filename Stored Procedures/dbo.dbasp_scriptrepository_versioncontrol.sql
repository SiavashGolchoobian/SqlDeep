SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <06/04/2019>
-- Version:		<3.0.0.0>
-- Description:	<Detect inconsustency and prepare repository for resync>
-- Implementation Note:	You should deploy "dbasp_scriptrepository_downloadfromhost" , "dbasp_scriptrepository_versioncontrol" and "dbasp_scriptrepository_executeonguest" sp's in the guest machine(s) and also you should create "ScriptRepositoryGuest" table on that guest machine(s) too.
--						IN Host machine you need to have only "ScriptRepositoryHost" table and insert your script's in this table as a central repository.
--						After these settings, in guest machine(s) you should create a LinkedServer to HostMachine and create then a job on guest machine(s) to run "dbasp_scriptrepository_downloadfromhost" sp at the first step, then "dbasp_scriptrepository_versioncontrol" at the second step and "dbasp_scriptrepository_executeonguest" sp at the last step, also that job should be fail and stop if each step is failed and does not go to next step
-- Input Parameters:
--	@IgnoreCheckValue:	Igonre compare Hash check, recommended to set this value to 0
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_scriptrepository_versioncontrol] (@IgnoreCheckValue BIT=0) AS
BEGIN
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myStatus_SUCCEED NVARCHAR(50);
	DECLARE @myStatus_CANCELED NVARCHAR(50);
	DECLARE @myStatus_FAILED NVARCHAR(50);
	DECLARE @myStatus_INPROGRESS NVARCHAR(50);
	DECLARE @myDatabaseNames NVARCHAR(MAX);
	DECLARE @myCurrentDatabase NVARCHAR(255);
	DECLARE @myDatabaseRepositoryVersion BIGINT;
	DECLARE @myDatabaseRepositoryMaxVersion BIGINT;
	DECLARE @myCursor Cursor;
	DECLARE @myEPVersionKey AS NVARCHAR(255);
	DECLARE @myStatement NVARCHAR(MAX);
	DECLARE @myEPTable TABLE ([DatabaseName] NVARCHAR(256),[EPName] NVARCHAR(MAX), [EPValue] NVARCHAR(max) DEFAULT(N'-9223372036854775808'), [RepositoryValue] BIGINT DEFAULT(-9223372036854775808), [RepositoryMaxValue] BIGINT DEFAULT(-9223372036854775808));
	DECLARE @myAppliedTable TABLE (RecordId BIGINT);
	DECLARE @myNotAppliedTable TABLE (RecordId BIGINT);
	DECLARE @myInconsistencyDetected BIT;
	DECLARE @myLastAppliedRecordId BIGINT;
	DECLARE @myErrorMessage NVARCHAR(4000)
	DECLARE @myErrorState INT
	DECLARE @myErrorCount INT
	DECLARE @myIgnoreCheckValue BIT;
	DECLARE @myBigIntMinVal BIGINT;

	SET @myIgnoreCheckValue=@IgnoreCheckValue
	SET @myBigIntMinVal=-9223372036854775808
	SET @myErrorCount=0
	SET @myErrorState=1
	SET @myErrorMessage=CAST(N'' AS NVARCHAR(4000))
	SET @myInconsistencyDetected=0
	SET @myEPVersionKey=N'Build'
	SET @myDatabaseNames=N'<ALL_DATABASES>'
	SET @myStatus_SUCCEED=N'SUCCEED'
	SET @myStatus_CANCELED=N'CANCELED'
	SET @myStatus_FAILED=N'FAILED'
	SET @myStatus_INPROGRESS=N'INPROGRESS'
	SET @myNewLine=CHAR(13)+CHAR(10)
	
	SET NOCOUNT ON;
	--Phase 1: Detecting any inconsistency between versions of Repository and EP for all databases
	SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@myDatabaseNames,1,0,1,0,1)

	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @myCurrentDatabase
		WHILE @@FETCH_STATUS=0
		BEGIN
			--Get Version of each database from EP and Repository
			DELETE FROM @myAppliedTable
			DELETE FROM @myNotAppliedTable
			SET @myDatabaseRepositoryVersion=@myBigIntMinVal
			SET @myStatement=CAST (N'' AS NVARCHAR(MAX))
			SET @myStatement=@myStatement+CAST(N'SELECT ''' + @myCurrentDatabase + ''',CAST([name] as nvarchar(max)), CAST([value] as nvarchar(max)) from ' + CAST(QUOTENAME(@myCurrentDatabase) AS NVARCHAR(MAX)) + N'.sys.extended_properties WHERE class=0' AS NVARCHAR(MAX))
			INSERT INTO @myEPTable ([DatabaseName],[EPName],[EPValue]) EXECUTE sp_executesql @myStatement
			INSERT INTO @myAppliedTable ([RecordId]) SELECT RecordId FROM [DBA].[dbo].[ScriptRepositoryGuest] WHERE [TargetDatabase]=@myCurrentDatabase AND [IsEnabled]=1 AND CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [CalculatedCheckValue] END = CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [CheckValue] END AND [LastExecutionStatus] IN (@myStatus_SUCCEED,@myStatus_CANCELED) 
			INSERT INTO @myNotAppliedTable ([RecordId]) SELECT RecordId FROM [DBA].[dbo].[ScriptRepositoryGuest] WHERE [TargetDatabase]=@myCurrentDatabase AND [IsEnabled]=1 AND CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [CalculatedCheckValue] END = CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [CheckValue] END AND ISNULL([LastExecutionStatus],N'') NOT IN (@myStatus_SUCCEED,@myStatus_CANCELED)
			SELECT @myDatabaseRepositoryVersion=MAX([RecordId]) FROM @myAppliedTable WHERE [@myAppliedTable].[RecordId]<(SELECT MIN(RecordId) FROM @myNotAppliedTable) OR NOT EXISTS (SELECT 1 FROM @myNotAppliedTable)
			SELECT @myDatabaseRepositoryMaxVersion=MAX([RecordId]) FROM @myAppliedTable
			IF EXISTS (SELECT 1 FROM @myEpTable WHERE [@myEPTable].[DatabaseName]=@myCurrentDatabase AND [@myEPTable].[EPName]=@myEPVersionKey AND ISNUMERIC([@myEPTable].[EPValue])=1)
			BEGIN	--If current database has specified extended property and has numeric value
				SET @myDatabaseRepositoryVersion=ISNULL(@myDatabaseRepositoryVersion,@myBigIntMinVal)
				SET @myDatabaseRepositoryMaxVersion=ISNULL(@myDatabaseRepositoryMaxVersion,@myBigIntMinVal)
				UPDATE @myEPTable SET [RepositoryValue]=@myDatabaseRepositoryVersion,[RepositoryMaxValue]=@myDatabaseRepositoryMaxVersion WHERE [DatabaseName]=@myCurrentDatabase AND [EPName]=@myEPVersionKey
			END
            ELSE
            BEGIN	--If current database does not have specified extended property or does not have numeric value for that property
				IF @myDatabaseRepositoryMaxVersion IS NOT NULL	--If current database has any script in repository and we expect to has specified extended property
				BEGIN
					SET @myErrorMessage = @myErrorMessage + QUOTENAME(@myCurrentDatabase) + N' database does not have "' + @myEPVersionKey + N'" key in its extended properties or value of that key is not numeric.' + @myNewLine
					SET @myErrorCount=@myErrorCount+1
				END
				ELSE
				BEGIN	--If current database has not any script in repository and does not need to have extended property
					PRINT QUOTENAME(@myCurrentDatabase) + N' database does not participate in version control.' + @myNewLine
				END
			END
			FETCH NEXT FROM @myCursor INTO @myCurrentDatabase
		END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;

	--If some databases does not have expected extended properties or this property was defined but has not numeric value, we should raise error and finish job
	IF @myErrorCount>0
	BEGIN
		PRINT @myErrorMessage
		RAISERROR (
					@myErrorMessage, -- Message text.
					11 ,--@ErrorSeverity, -- Severity.
					@myErrorState -- State.
					) WITH LOG;
		RETURN
	END

	--If any incosisteny detected we set @myInconsistencyDetected flag to 1
	IF EXISTS (SELECT 1 FROM @myEPTable WHERE [EPName]=@myEPVersionKey AND CAST([EPValue] AS BIGINT) <> [RepositoryValue])
		SET @myInconsistencyDetected=1

	--Phase 2: Redo unapplied repository commands if Guest is in incosistent state (resolve inconsistenct situation)
	IF @myInconsistencyDetected=1
	BEGIN
		--Scenario #1: Database version is higher than repository version: We should upgrade repository High Water Mark to Database version
		UPDATE myRepository SET 
			[myRepository].[LastExecutionDate]=GETDATE(),
			[myRepository].[LastExecutionStatus]=@myStatus_CANCELED,
			[myRepository].[ExecutionLog] = CAST(N'Canceled on ' AS NVARCHAR(MAX)) + CAST(GETDATE() AS NVARCHAR(MAX)) + CAST(N' - ' + @myNewLine AS NVARCHAR(MAX)) + CAST(N'Because of version synchronization between Database version and repository version, DB version is higher: ' AS NVARCHAR(MAX)) + CAST([myVersionInfo].[DatabaseValue] AS NVARCHAR(MAX)) + CAST(@myNewLine + N'-----' AS NVARCHAR(MAX)) + ISNULL(CAST([myRepository].[ExecutionLog] AS NVARCHAR(MAX)),CAST(N'' AS NVARCHAR(MAX)))
		FROM
			[DBA].[dbo].[ScriptRepositoryGuest] AS myRepository
			INNER JOIN
				(
				SELECT
					[DatabaseName],
					CAST([EPValue] AS BIGINT) AS DatabaseValue,
					[RepositoryValue]
				FROM
					@myEPTable 
				WHERE 
					[EPName]=@myEPVersionKey 
					AND CAST([EPValue] AS BIGINT) > [RepositoryValue]
				) AS myVersionInfo ON [myVersionInfo].[DatabaseName]=[myRepository].[TargetDatabase]
		WHERE
			[myRepository].[IsEnabled]=1 
			AND CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myRepository].[CalculatedCheckValue] END = CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myRepository].[CheckValue] END
			AND [myRepository].[RecordId]>[myVersionInfo].[RepositoryValue]
			AND [myRepository].[RecordId]<=[myVersionInfo].[DatabaseValue]

		--Scenario #2: Database version is lower than repository version: We should apply uncommited commands from repository to database
		--Check for existance of older records in repository
		IF NOT EXISTS (
						SELECT 
							1 
						FROM 
							(
							SELECT 
								[@myEPTable].[DatabaseName],
								CAST([@myEPTable].[EPValue] AS BIGINT) AS MinRecordId 
							FROM 
								@myEPTable 
							WHERE 
								[@myEPTable].[EPName]=@myEPVersionKey 
								AND CAST([@myEPTable].[EPValue] AS BIGINT) < [@myEPTable].[RepositoryValue]
							) AS myEPMinRequiredRecordId
							LEFT OUTER JOIN [DBA].[dbo].[ScriptRepositoryGuest]  AS myRepository ON myRepository.TargetDatabase=myEPMinRequiredRecordId.[DatabaseName] AND myRepository.RecordId=myEPMinRequiredRecordId.MinRecordId
						WHERE
							myRepository.[RecordId] IS NULL
						)
		BEGIN	--Minimum required RecordId's for all expected database(s) is found in local repository and we can sync correctly
			--Set Execution status of tasks needed to replay, to Null
			UPDATE myRepository SET 
				[myRepository].[LastExecutionDate]=NULL,
				[myRepository].[LastExecutionStatus]=NULL,
				[myRepository].[ExecutionLog] = CAST(N'Nulled on ' AS NVARCHAR(MAX)) + CAST(GETDATE() AS NVARCHAR(MAX)) + CAST(N' - ' + @myNewLine AS NVARCHAR(MAX)) + CAST(N'Because of version synchronization between Database version and repository, DB version is lower: ' AS NVARCHAR(MAX)) + CAST([myVersionInfo].[DatabaseValue] AS NVARCHAR(MAX)) + CAST(@myNewLine + N'-----' AS NVARCHAR(MAX)) + ISNULL(CAST([myRepository].[ExecutionLog] AS NVARCHAR(MAX)),CAST(N'' AS NVARCHAR(MAX)))
			FROM
				[DBA].[dbo].[ScriptRepositoryGuest] AS myRepository
				INNER JOIN
					(
					SELECT
						[DatabaseName],
						CAST([EPValue] AS BIGINT) AS DatabaseValue,
						[RepositoryValue],
						[@myEPTable].[RepositoryMaxValue]
					FROM
						@myEPTable 
					WHERE 
						[EPName]=@myEPVersionKey 
						AND CAST([EPValue] AS BIGINT) < [RepositoryValue]
					) AS myVersionInfo ON [myVersionInfo].[DatabaseName]=[myRepository].[TargetDatabase]
			WHERE
				[myRepository].[IsEnabled]=1 
				AND CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myRepository].[CalculatedCheckValue] END = CASE @myIgnoreCheckValue WHEN 1 THEN 1 ELSE [myRepository].[CheckValue] END
				AND [myRepository].[RecordId]>[myVersionInfo].[DatabaseValue]
				AND [myRepository].[RecordId]<=[myVersionInfo].[RepositoryMaxValue]
				AND ([myRepository].[RecordRef] IS NULL OR [myRepository].[RecordRef]>[myVersionInfo].[DatabaseValue])
		END
		ELSE
		BEGIN	--Minimum required RecordId for some database(s) is not found in local repository and we should download it from centeral repository to local repoitory
			SET @myErrorMessage=N'Minimum required RecordId for some database(s) is not found in local repository and you should download RecordId(s) equal and greater than that, from centeral repository to local repoitory, you can find required minimum RecordId(s) for those database in the resutset.'

			SELECT 
				myEPMinRequiredRecordId.*
			FROM 
				(
				SELECT 
					[@myEPTable].[DatabaseName],
					CAST([@myEPTable].[EPValue] AS BIGINT) AS MinRecordId 
				FROM 
					@myEPTable 
				WHERE 
					[@myEPTable].[EPName]=@myEPVersionKey 
					AND CAST([@myEPTable].[EPValue] AS BIGINT) < [@myEPTable].[RepositoryValue]
				) AS myEPMinRequiredRecordId
				LEFT OUTER JOIN [DBA].[dbo].[ScriptRepositoryGuest]  AS myRepository ON myRepository.TargetDatabase=myEPMinRequiredRecordId.[DatabaseName] AND myRepository.RecordId=myEPMinRequiredRecordId.MinRecordId
			WHERE
				myRepository.[RecordId] IS NULL

			PRINT @myErrorMessage
			RAISERROR (
						@myErrorMessage, -- Message text.
						11 ,--@ErrorSeverity, -- Severity.
						@myErrorState -- State.
						) WITH LOG;
			RETURN			
		END
		--SELECT * FROM @myEPTable
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_versioncontrol', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_versioncontrol', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_versioncontrol', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_scriptrepository_versioncontrol', NULL, NULL
GO
