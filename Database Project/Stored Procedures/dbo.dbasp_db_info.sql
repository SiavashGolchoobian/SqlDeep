SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Golchoobian>
-- Create date: <5/19/2018>
-- Version:		<3.0.0.0>
-- Description:	<Get statistics about databases>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_db_info] (@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>')
AS
	SET NOCOUNT ON;
	--=====Internal Parameters
	DECLARE @myIsPrerequisitesPassed BIT;
	DECLARE @myCursor Cursor;
	DECLARE @myCursor_Dcm Cursor;
	DECLARE @myDatabase_Name nvarchar(255);
	DECLARE @myDatabase_Id INT;
	DECLARE @myDatabase_Collation NVARCHAR(MAX);
	DECLARE @myDatabase_RecoveryModel INT;
	DECLARE @myDatabase_RecoveryModelDesc NVARCHAR(MAX);
	DECLARE @myTotal_LogSize_KB BIGINT;
	DECLARE @myUsed_LogSize_KB BIGINT;
	DECLARE @myUnallocated_LogSize_KB BIGINT;
	DECLARE @myCountOfVLFs BIGINT;
	DECLARE @myTotal_RowSize_KB BIGINT;
	DECLARE @myUsed_RowSize_KB BIGINT;
	DECLARE @myUnallocated_RowSize_KB BIGINT;
	DECLARE @myTotal_FilestreamSize_KB BIGINT;
	DECLARE @myDatabase_Filestats TABLE([file_id] INT, [file_group_id] INT, [total_extents] INT, [used_extents] INT, [logical_file_name] NVARCHAR(500) collate database_default, [physical_file_name] NVARCHAR(500) collate database_default);
	DECLARE @mySQLScript NVARCHAR(MAX);
	DECLARE @myDcmPageLength INT;
	DECLARE @myDcmCurrentFileId INT
	DECLARE @myDcmCurrentPageId INT
	DECLARE @myDcmQueue TABLE (FileId INT,PageId INT)
	DECLARE @myDcmDBCCPAGE TABLE ([ParentObject] VARCHAR(255),[OBJECT] VARCHAR(255),[Field] VARCHAR(255),[VALUE] VARCHAR(255));
	DECLARE @myTotal_DiffChangedSize_KB BIGINT;
	DECLARE @versionString NVARCHAR(20);
	DECLARE @serverVersion DECIMAL(10,5);
	DECLARE @sqlServer2012Version DECIMAL(10,5);
	DECLARE @myLogInfoResult2012 TABLE ([RecoveryUnitId] INT NULL, [FileId]	INT NULL,[FileSize]	BIGINT NULL, [StartOffset] BIGINT NULL, [FSeqNo] INT NULL, [Status] INT NULL, [Parity] TINYINT NULL, [CreateLSN] NUMERIC(25, 0) NULL)
	DECLARE @myLogInfoResult2008 TABLE ([FileId] INT NULL, [FileSize] BIGINT NULL, [StartOffset] BIGINT NULL, [FSeqNo] INT NULL, [Status] INT NULL, [Parity] TINYINT NULL, [CreateLSN] NUMERIC(25, 0) NULL)
	DECLARE @myLogSpaceUsedResult2012 TABLE ([Database Name] sysname NULL, [Log Size (MB)] FLOAT NULL, [Log Space Used (%)] FLOAT NULL, [Status] BIGINT NULL)
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myError_Message nvarchar(255);
	DECLARE @myResult TABLE ([database_id] INT, [database_name] NVARCHAR(255),[ItemId] INT, [ItemDesc] NVARCHAR(50), [Value] NVARCHAR(MAX), [Comment] NVARCHAR(max))

	--=====Parameters Initialization
	SET @myIsPrerequisitesPassed=1;
	SET @versionString = CAST(SERVERPROPERTY('productversion') AS NVARCHAR(20))
	SET @serverVersion = CAST(LEFT(@versionString,CHARINDEX('.', @versionString)) AS DECIMAL(10,5))
	SET @sqlServer2012Version = 11.0 -- SQL Server 2012
	SET @myError_Message=N'';
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myDcmPageLength=511232;

	--=====Prerequisites Control
	IF NOT EXISTS(Select 1 FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1) as myDBList INNER JOIN sys.databases as myDBState on myDBList.Name collate SQL_Latin1_General_CP1_CI_AS = myDBState.name collate SQL_Latin1_General_CP1_CI_AS)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myError_Message=@myError_Message + N'@DatabaseNames is empty or invalid.' + @myNewLine
	END

	IF @myIsPrerequisitesPassed=0
	BEGIN
		Print @myError_Message
		SELECT [database_id] , [database_name], [ItemId], [ItemDesc], [Value], [Comment] FROM @myResult;
		RETURN
	END
	--=====Process Request
	SET @myCursor=CURSOR For
		Select [myDBList].[Name],[myDBState].[recovery_model],[myDBState].[collation_name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1) as myDBList INNER JOIN sys.databases as myDBState on myDBList.Name collate SQL_Latin1_General_CP1_CI_AS = myDBState.name collate SQL_Latin1_General_CP1_CI_AS
	
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @myDatabase_Name,@myDatabase_RecoveryModel,@myDatabase_Collation
		WHILE @@FETCH_STATUS=0
		BEGIN
			SET @myDatabase_Id=DB_ID(@myDatabase_Name);
			SET @myDatabase_RecoveryModelDesc=NULL;
			SET @myTotal_LogSize_KB = NULL
			SET @myUsed_LogSize_KB = NULL;
			SET @myUnallocated_LogSize_KB = NULL;
			SET @myCountOfVLFs = NULL;
			SET @myTotal_RowSize_KB = NULL;
			SET @myUsed_RowSize_KB = NULL;
			SET @myUnallocated_RowSize_KB = NULL;
			SET @myTotal_FilestreamSize_KB = NULL;
			SET @myTotal_DiffChangedSize_KB = NULL;
			SET @myDcmCurrentFileId = NULL;
			SET @myDcmCurrentPageId = NULL;
			DELETE FROM @myDatabase_Filestats;
			DELETE FROM @myDcmQueue;
			DELETE FROM @myDcmDBCCPAGE;
			DELETE FROM @myLogInfoResult2012;
			DELETE FROM @myLogInfoResult2008;
			DELETE FROM @myLogSpaceUsedResult2012;

			--Determin Database Total File Size
			SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
			SET @mySQLScript=@mySQLScript+
				CAST(
				@myNewLine+N'SELECT '+
				@myNewLine+N'	@myTotal_LogSize_KB=SUM(CAST(CASE WHEN [myDBFiles].[type] = 1 THEN [myDBFiles].[size] ELSE 0 END AS FLOAT))*8,'+
				@myNewLine+N'	@myTotal_RowSize_KB=SUM(CAST(CASE WHEN [myDBFiles].[type] IN (0,3,4) THEN [myDBFiles].[size] ELSE 0 END AS FLOAT))*8,'+
				@myNewLine+N'	@myTotal_FilestreamSize_KB=SUM(CAST(CASE WHEN [myDBFiles].[type] = 2 THEN [myDBFiles].[size] ELSE 0 END AS FLOAT))*8'+
				@myNewLine+N'FROM ' + CAST(QUOTENAME(@myDatabase_Name) AS NVARCHAR(MAX)) + N'.[sys].[database_files] AS myDBFiles' 
				AS NVARCHAR(MAX))
			BEGIN TRY
				EXECUTE sp_executesql @mySQLScript,N'@myTotal_LogSize_KB BIGINT OUTPUT,@myTotal_RowSize_KB BIGINT OUTPUT,@myTotal_FilestreamSize_KB BIGINT OUTPUT',@myTotal_LogSize_KB OUTPUT,@myTotal_RowSize_KB OUTPUT,@myTotal_FilestreamSize_KB OUTPUT
			END TRY
			BEGIN CATCH
			END CATCH

			--Determin Database Used File Size
			SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
			SET @mySQLScript=@mySQLScript+
				CAST('Use ' + QUOTENAME(@myDatabase_Name) +';DBCC SHOWFILESTATS;' AS NVARCHAR(MAX))
			Delete from @myDatabase_Filestats
			Insert into @myDatabase_Filestats exec (@mySQLScript)
			Select @myUsed_RowSize_KB = SUM([used_extents])*64 FROM @myDatabase_Filestats

			--Determine Changed Size of data (via DCM pages) for Diff backup and current log file size for Log backup and compare it with Backup change size threshold
			;WITH myDCMPages AS (
				SELECT 
					[file_id],
					(([size]-6)/@myDCMpageLength) AS DcmPageNo
				FROM 
					sys.master_files 
				WHERE 
					[database_id]=@myDatabase_Id
					AND [type]=0
				UNION ALL
				SELECT 
					[myDCMPages].[file_id],
					[myDCMPages].[DcmPageNo]-1 AS DcmPageNo
				FROM 
					[myDCMPages]
				WHERE 
					[myDCMPages].[DcmPageNo]>0
				)
			INSERT INTO @myDcmQueue	([FileId], [PageId]) SELECT [myDCMPages].[file_id],([myDCMPages].[DcmPageNo]*@myDCMpageLength)+6 FROM [myDCMPages] ORDER BY [myDCMPages].[file_id],[myDCMPages].[DcmPageNo]
			SET @myCursor_Dcm=CURSOR FOR SELECT [FileId],[PageId] FROM @myDcmQueue
			Open @myCursor_Dcm
				FETCH NEXT FROM @myCursor_Dcm INTO @myDcmCurrentFileId,@myDcmCurrentPageId
					WHILE @@FETCH_STATUS=0
					BEGIN
						SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
						SET @mySQLScript=@mySQLScript+
							CAST(N'Use ' + QUOTENAME(@myDatabase_Name) + N';dbcc page(' + CAST(@myDatabase_Id AS NVARCHAR(MAX)) + N',' + CAST(@myDcmCurrentFileId AS NVARCHAR(MAX)) + ',' + CAST(@myDcmCurrentPageId AS NVARCHAR(MAX)) + N',3) WITH TABLERESULTS;' AS NVARCHAR(MAX))
						--PRINT @mySQLScript
						INSERT INTO @myDcmDBCCPAGE exec(@mySQLScript)
						FETCH NEXT FROM @myCursor_Dcm INTO @myDcmCurrentFileId,@myDcmCurrentPageId
					END
			CLOSE @myCursor_Dcm;
			DEALLOCATE @myCursor_Dcm;

			SELECT
				@myTotal_DiffChangedSize_KB=CAST(SUM([myModifiedPages].[EndPage]-[myModifiedPages].[StartPage]+1) * 8.0 AS BIGINT) --AS ModifiedPages_KB
			FROM
				(
				SELECT
					[mySecondPart].[Field],
					[mySecondPart].[StartPage],
					CAST(
						CASE 
							WHEN [mySecondPart].[SecondColon]=0 THEN [mySecondPart].[StartPage] + 7
							ELSE SUBSTRING([mySecondPart].[Field],[mySecondPart].[SecondColon]+1,[mySecondPart].[SecondBrace]-[mySecondPart].[SecondColon]-1) + 7
						END	AS BIGINT
						) AS EndPage
				FROM
					(
					SELECT
						[myFirstPart].[Field],
						CHARINDEX(':',[myFirstPart].[Field],[myFirstPart].[FirstBrace]+1) AS SecondColon,
						CHARINDEX(')',[myFirstPart].[Field],[myFirstPart].[FirstBrace]+1) AS SecondBrace,
						CAST(SUBSTRING([myFirstPart].[Field],[myFirstPart].[FirstColon]+1,[myFirstPart].[FirstBrace]-[myFirstPart].[FirstColon]-1) AS BIGINT) AS StartPage
					FROM
						(
						SELECT
							[myDiff].[Field],
							CHARINDEX(':',[myDiff].[Field],0) AS FirstColon,
							CHARINDEX(')',[myDiff].[Field],0) AS FirstBrace
						FROM 
							@myDcmDBCCPAGE AS myDiff 
						WHERE 
							[myDiff].[ParentObject] LIKE 'DIFF_MAP%' 
							AND [myDiff].[VALUE]='    CHANGED'
						) AS myFirstPart
					) AS mySecondPart
				) AS myModifiedPages

			--Determine Estimated Active Portion of Log File size
			IF(@serverVersion >= @sqlServer2012Version)
			BEGIN
				-- Use the new version of the table  
				SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
				SET @mySQLScript=@mySQLScript+
					CAST('Use ' + QUOTENAME(@myDatabase_Name) +';DBCC LOGINFO;' AS NVARCHAR(MAX))
				Insert into @myLogInfoResult2012 exec (@mySQLScript)
				Select @myUsed_LogSize_KB = SUM(filesize)/1024, @myCountOfVLFs=COUNT(*) FROM @myLogInfoResult2012 WHERE [Status]=2
			
				--In AlwaysOn enabled database usally all VLF files have [Status] value of 2 in DBCC LogInfo because of compatibility issues, then you should estimating log free space with SQLPERF(LOGSPACE) command
				IF ISNULL(@myUsed_LogSize_KB,-1)=-1
				BEGIN
					SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
					SET @mySQLScript=@mySQLScript+
						CAST('Use ' + QUOTENAME(@myDatabase_Name) +';DBCC SQLPERF(LOGSPACE);' AS NVARCHAR(MAX))
					Insert into @myLogSpaceUsedResult2012 exec (@mySQLScript)
					SELECT @myUsed_LogSize_KB=CAST(ISNULL((((100-[Log Space Used (%)])*[Log Size (MB)])/100)*(1024),0) AS BIGINT) FROM @myLogSpaceUsedResult2012 WHERE [Database Name]=@myDatabase_Name
				END
			END  
			ELSE  
			BEGIN
				-- Use the old version of the table
				SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
				SET @mySQLScript=@mySQLScript+
					CAST('Use ' + QUOTENAME(@myDatabase_Name) +';dbcc loginfo;' AS NVARCHAR(MAX))
				Insert into @myLogInfoResult2012 exec (@mySQLScript)
				Select @myUsed_LogSize_KB = SUM(filesize)/1024, @myCountOfVLFs=COUNT(*) FROM @myLogInfoResult2012 WHERE [Status]=2
 			END

			--Calculations
			SET @myUnallocated_LogSize_KB=ISNULL(@myTotal_LogSize_KB,0)-ISNULL(@myUsed_LogSize_KB,0)
			SET @myUnallocated_RowSize_KB=ISNULL(@myTotal_RowSize_KB,0)-ISNULL(@myUsed_RowSize_KB,0)
			SET @myDatabase_RecoveryModelDesc=CASE @myDatabase_RecoveryModel WHEN 1 THEN N'FULL' WHEN 2 THEN N'BULK_LOGGED' WHEN 3 THEN N'SIMPLE' END

			--Generate Resultset
			INSERT INTO @myResult ([database_id], [database_name], [ItemId], [ItemDesc], [Value], [Comment]) VALUES 
				(@myDatabase_Id,@myDatabase_Name,1,N'RecoveryModel',CAST(@myDatabase_RecoveryModelDesc AS NVARCHAR(MAX)),NULL),
				(@myDatabase_Id,@myDatabase_Name,2,N'Total_LogSize_KB',CAST(@myTotal_LogSize_KB AS NVARCHAR(MAX)),NULL),
				(@myDatabase_Id,@myDatabase_Name,3,N'Used_LogSize_KB',CAST(@myUsed_LogSize_KB AS NVARCHAR(MAX)),NULL),
				(@myDatabase_Id,@myDatabase_Name,4,N'Unallocated_LogSize_KB',CAST(@myUnallocated_LogSize_KB AS NVARCHAR(MAX)),NULL),
				(@myDatabase_Id,@myDatabase_Name,5,N'Count of VLFs',CAST(@myCountOfVLFs AS NVARCHAR(MAX)),N'For regular databases it''s better to have less than 20 VLFs, also 20 to 50 VLFs have few performance issues but having more than 50 VLFs has serious performance issue BUT in very large HIGH OLTP databases you should not have more than 200 VLFs.'),
				(@myDatabase_Id,@myDatabase_Name,6,N'Total_RowSize_KB',CAST(@myTotal_RowSize_KB AS NVARCHAR(MAX)),NULL),
				(@myDatabase_Id,@myDatabase_Name,7,N'Used_RowSize_KB',CAST(@myUsed_RowSize_KB AS NVARCHAR(MAX)),NULL),
				(@myDatabase_Id,@myDatabase_Name,8,N'Unallocated_RowSize_KB',CAST(@myUnallocated_RowSize_KB AS NVARCHAR(MAX)),NULL),
				(@myDatabase_Id,@myDatabase_Name,9,N'Total_FilestreamSize_KB',CAST(@myTotal_FilestreamSize_KB AS NVARCHAR(MAX)),NULL),
				(@myDatabase_Id,@myDatabase_Name,10,N'Total_DiffChangedSize_KB',CAST(@myTotal_DiffChangedSize_KB AS NVARCHAR(MAX)),N'Size of modified pages since last full backup.')
				
			FETCH NEXT FROM @myCursor INTO @myDatabase_Name,@myDatabase_RecoveryModel,@myDatabase_Collation
		END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;

	SELECT [database_id] , [database_name], [ItemId], [ItemDesc], [Value], [Comment] FROM @myResult;
	RETURN
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_db_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2018-05-19', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_db_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-05-19', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_db_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_db_info', NULL, NULL
GO
