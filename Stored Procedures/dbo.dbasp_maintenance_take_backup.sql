SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/25/2015>
-- Version:		<3.0.0.6>
-- Description:	<Backup database>
-- Input Parameters:
--	@DatabaseNames:				'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@LocalDestinationPath:		'...' //local destination path to saving backup on or multiple path seperated by , sign
--	@BackupExtension:			'xxx' //three character backup file extension
--	@BackupType:				'FULL' or 'LOG' or 'DIFF'
--	@RetainDays:				any int number
--	@SplitThresholdSizeGB:		NULL,Negative,0 or any POSITIVE bigint value in GB scale //Take backup on multiple files if estimated DB\Log Backup size is over @SplitThresholdSizeGB also you can use NULL or 0 or any Negative value if you want one backup file in any situation
--	@DiffOrLogThresholdSizeGB:	NULL,0 or any POSITIVE bigint value in GB scale //Take Diff/Log backup if Data/Log chnaged size from previous backup is greater than or equal to this parameter else ignore backup process
--	@BackupFileNamingType:		'DATE' or 'DATETIME' or 'JDATE' or 'JDATETIME', if 'DATETIME' is used, this SP will add #Time value to backup file name else only use #Date value for backup file name. JDATE and JDATETIME is same as DAT and DATETIME rule but use Jalali calendar instead of Gregorian calendar
--	@BackupCertificateName		NULL,Certificate name used to encrypt backup
--	@PrintOnly:					0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_take_backup]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@LocalDestinationPath NVARCHAR(MAX),
	@BackupExtension NVARCHAR(3) = N'bak',
	@BackupType NVARCHAR(4), 
	@RetainDays INT = 90,
	@SplitThresholdSizeGB BIGINT = 80,
	@DiffOrLogThresholdSizeGB BIGINT = 0,
	@BackupFileNamingType nvarchar(50)=N'DATE',
	@BackupCertificateName sysname=NULL,
	@PrintOnly BIT=0
AS
BEGIN
	SET NOCOUNT ON;
	--=====Internal Parameters
	DECLARE @myIsPrerequisitesPassed BIT;
	DECLARE @myIsCompressionEnabled BIT;
	DECLARE @myNormalCompressionRate DECIMAL(10,3);
	DECLARE @myEstimatedCompressionRate DECIMAL(10,3);
	DECLARE @myEstimatedBackupSize BIGINT;
	DECLARE @myEstimatedCompressedBackupSize BIGINT;
	DECLARE @myCursor Cursor;
	DECLARE @myCursor_Dcm Cursor;
	DECLARE @myDatabase_Name nvarchar(255);
	DECLARE @myDatabase_Id INT;
	DECLARE @myDatabase_RecoveryModel INT;
	DECLARE @myDatabase_LogSizeGB BIGINT;
	DECLARE @myDatabase_RowSizeGB BIGINT;
	DECLARE @myDatabase_FilestreamSizeGB BIGINT;
	DECLARE @myDatabase_FileSizeGB BIGINT;
	DECLARE @myDatabase_BackupFileCount DECIMAL(7,2);
	DECLARE @myDatabase_BackupDestinationCount INT;
	DECLARE @myCalendar_Date nvarchar(10);
	DECLARE @myGregorian_Date datetime;
	DECLARE @myTime Time(0);
	DECLARE @myTimeChar nvarchar(8);
	DECLARE @myFolderDate nvarchar(255);
	DECLARE @myNewFolder NVARCHAR(255)
	DECLARE @myMediaSet_Name nvarchar(255);
	DECLARE @myMediaSet_Desc nvarchar(255);
	DECLARE @myBackupSet_Name nvarchar(255);
	DECLARE @myBackupSet_Desc nvarchar(255);
	DECLARE @myBackupDisks NVARCHAR(MAX);
	DECLARE @myBackupSetId as int;
	DECLARE @myIterator01 INT;
	DECLARE @myIterator02 INT;
	DECLARE @mySQLScript NVARCHAR(MAX);
	DECLARE @myDcmPageLength INT;
	DECLARE @myDcmCurrentFileId INT
	DECLARE @myDcmCurrentPageId INT
	DECLARE @myDcmQueue TABLE (FileId INT,PageId INT)
	DECLARE @myDcmDBCCPAGE TABLE ([ParentObject] VARCHAR(255),[OBJECT] VARCHAR(255),[Field] VARCHAR(255),[VALUE] VARCHAR(255));
	DECLARE @myDiffOrLogChangedSizeGB BIGINT;
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myError_Message nvarchar(255);
	DECLARE @myInfo_Message nvarchar(255);
	DECLARE @myVerifiedBackupCount int;
	DECLARE @myEveryThingIsOK bit;
	DECLARE @mySizeThresholdIsOK bit;
	--=====Parameters Initialization
	SET @myIsPrerequisitesPassed=1;
	SET @myError_Message=N'';
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myDcmPageLength=511232;
	SET @myVerifiedBackupCount=0;								--Equal to @BackupRequestsCount is OK else is Error
	SET @SplitThresholdSizeGB=CASE WHEN ISNULL(@SplitThresholdSizeGB,-1)<=0 THEN -1 ELSE @SplitThresholdSizeGB END
	SET @myNormalCompressionRate=2.499;
	SET @myIsCompressionEnabled = ISNULL((SELECT CAST([myConfig].[value] AS BIT) FROM [sys].[configurations] AS myConfig  WHERE [myConfig].[name] = N'backup compression default'),0)	--Determin Default behaviour of Backup Compression
	SET @BackupFileNamingType=UPPER(@BackupFileNamingType);
	--=====Prerequisites Control
	IF NOT EXISTS (SELECT 1 FROM [dbo].[dbafn_split](N',',@LocalDestinationPath) AS myList WHERE [myList].[Parameter] IS NOT NULL AND LEN(RTRIM(LTRIM([myList].[Parameter])))>0)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myError_Message=@myError_Message + N'@LocalDestinationPath is empty or invalid.' + @myNewLine
	END

	IF NOT EXISTS(Select 1 FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1) as myDBList INNER JOIN sys.databases as myDBState on myDBList.Name collate SQL_Latin1_General_CP1_CI_AS = myDBState.name collate SQL_Latin1_General_CP1_CI_AS)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myError_Message=@myError_Message + N'@DatabaseNames is empty or invalid.' + @myNewLine
	END

	IF @BackupType NOT IN (N'FULL',N'LOG',N'DIFF')
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myError_Message=@myError_Message + N'@BackupType is invalid, valid values are N''FULL'',N''LOG'' or N''DIFF''.' + @myNewLine
	END

	IF @BackupCertificateName IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [master].[sys].[certificates] AS myCert WHERE [myCert].[name] = ISNULL(@BackupCertificateName,'') AND [myCert].[start_date] < getdate() AND [myCert].[expiry_date] > getdate())
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myError_Message=@myError_Message + N'@BackupCertificateName is invalid or certificate is expired.' + @myNewLine
	END

	IF @myIsPrerequisitesPassed=0
	BEGIN
		Print @myError_Message
		Return
	END
	--=====Process Request
	SET @myCursor=CURSOR For
		Select myDBList.[Name],myDBState.recovery_model FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1) as myDBList INNER JOIN sys.databases as myDBState on myDBList.Name collate SQL_Latin1_General_CP1_CI_AS = myDBState.name collate SQL_Latin1_General_CP1_CI_AS WHERE CASE WHEN UPPER(@BackupType)=N'DIFF' AND UPPER([myDBList].[Name])=N'MASTER' THEN 0 ELSE 1 END = 1 -- /*MSSQL can not take diff backup from master database*/ AND myDBState.recovery_model<>3	--Not in simple mode
	
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @myDatabase_Name,@myDatabase_RecoveryModel
			WHILE @@FETCH_STATUS=0
			BEGIN

			SET @myEveryThingIsOK=0;
			SET @mySizeThresholdIsOK=0;
			SET @myGregorian_Date=GETDATE();																				--Calculate current gregorian date
			SET @myTime = CAST(@myGregorian_Date as Time(0))
			SET @myTimeChar = REPLACE(@myTime,':','_')
			SET @myCalendar_Date = CASE 
									WHEN @BackupFileNamingType IN (N'JDATE','JDATETIME') THEN [dbo].[dbafn_miladi2shamsi] (@myGregorian_Date,N'_')		--Calculate current persian or gregorian date
									ELSE CAST(DATEPART(YEAR,@myGregorian_Date) AS NVARCHAR(10)) + N'_' + CASE WHEN DATEPART(MONTH,@myGregorian_Date)<10 THEN N'0' ELSE N'' END + CAST(DATEPART(MONTH,@myGregorian_Date) AS NVARCHAR(10)) + N'_' +  CASE WHEN DATEPART(DAY,@myGregorian_Date)<10 THEN N'0' ELSE N'' END  + CAST(DATEPART(DAY,@myGregorian_Date) AS NVARCHAR(10))		--Calculate current persian or gregorian date
								  END;
			SET @myFolderDate = Left(@myCalendar_Date,7) + N'\' + Right(@myCalendar_Date,2);									--Calculate required sub directories under @Backup_Base structure for storing backup files			
			SET @myEstimatedBackupSize = NULL;
			SET @myEstimatedCompressedBackupSize = NULL;
			SET @myEstimatedCompressionRate = @myNormalCompressionRate;
			SET @myDatabase_Id=DB_ID(@myDatabase_Name);
			SET @myDcmCurrentFileId = NULL;
			SET @myDcmCurrentPageId = NULL;
			SET @myDiffOrLogChangedSizeGB = NULL;
			DELETE FROM @myDcmQueue;
			DELETE FROM @myDcmDBCCPAGE;

			--Determine Destination Path(s)
				CREATE TABLE #myDestinationTable (ID INT IDENTITY,[Path] NVARCHAR(255))
				INSERT INTO [#myDestinationTable]([Path])
				SELECT 
					[myList].[Parameter]+N'\'+ @myFolderDate AS [Path]
				FROM 
					[dbo].[dbafn_split](N',',@LocalDestinationPath) AS myList 
				WHERE 
					[myList].[Parameter] IS NOT NULL AND LEN(RTRIM(LTRIM([myList].[Parameter])))>0
				ORDER BY
					[myList].[Position]

				SELECT @myDatabase_BackupDestinationCount=COUNT(*) FROM #myDestinationTable


			IF @SplitThresholdSizeGB != -1		--User want to use backup split feature
			BEGIN
				--Determin Database File Size
				SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
				SET @mySQLScript=@mySQLScript+
					CAST(
					@myNewLine+N'SELECT '+
					@myNewLine+N'	@myDatabase_LogSizeGB=SUM(CAST(CASE WHEN [myDBFiles].[type] = 1 THEN [myDBFiles].[size] ELSE 0 END AS BIGINT))*8/(1024*1024),'+
					@myNewLine+N'	@myDatabase_RowSizeGB=SUM(CAST(CASE WHEN [myDBFiles].[type] IN (0,3,4) THEN [myDBFiles].[size] ELSE 0 END AS BIGINT))*8/(1024*1024),'+
					@myNewLine+N'	@myDatabase_FilestreamSizeGB=SUM(CAST(CASE WHEN [myDBFiles].[type] = 2 THEN [myDBFiles].[size] ELSE 0 END AS BIGINT))*8/(1024*1024)'+
					@myNewLine+N'FROM ' + CAST(QUOTENAME(@myDatabase_Name) AS NVARCHAR(MAX)) + N'.[sys].[database_files] AS myDBFiles' 
					AS NVARCHAR(MAX))
				BEGIN TRY
					EXECUTE sp_executesql @mySQLScript,N'@myDatabase_LogSizeGB BIGINT OUTPUT,@myDatabase_RowSizeGB BIGINT OUTPUT,@myDatabase_FilestreamSizeGB BIGINT OUTPUT',@myDatabase_LogSizeGB OUTPUT,@myDatabase_RowSizeGB OUTPUT,@myDatabase_FilestreamSizeGB OUTPUT
				END TRY
				BEGIN CATCH
				END CATCH


				--Calculate Estimated values by processing last 30 backup history
				SELECT
					@myEstimatedBackupSize=ISNULL(AVG([myLastSamples].[backup_size_GB]),NULL),
					@myEstimatedCompressedBackupSize=ISNULL(AVG([myLastSamples].[compressed_backup_size_GB]),NULL),
					@myEstimatedCompressionRate=ISNULL(AVG([myLastSamples].[CompressionRate]),@myNormalCompressionRate)
				FROM
					(
					SELECT TOP 30
						[myBackupset].[backup_size]/(1024*1024*1024) AS backup_size_GB,
						[myBackupset].[compressed_backup_size]/(1024*1024*1024) AS compressed_backup_size_GB,
						CASE WHEN [myBackupset].[compressed_backup_size] IS NOT NULL THEN [myBackupset].[backup_size]/[myBackupset].[compressed_backup_size] ELSE NULL END AS CompressionRate
					FROM 
						msdb.dbo.backupset AS myBackupset
					WHERE
						[myBackupset].[database_name]=@myDatabase_Name
						AND [myBackupset].[is_damaged]=0
						AND [myBackupset].[has_incomplete_metadata]=0
						AND [myBackupset].[type]=CASE @BackupType WHEN N'LOG' THEN 'L' WHEN N'FULL' THEN 'D' WHEN 'DIFF' THEN 'I' END
					ORDER BY
						[myBackupset].[backup_finish_date] DESC
					) AS myLastSamples
				

				--Calculate @myDatabase_FileSizeGB
				IF @BackupType=N'LOG'			--Log Backup
				BEGIN
					SET @myDatabase_FileSizeGB=ISNULL(@myDatabase_LogSizeGB,0)
				END
				ELSE IF @BackupType=N'FULL'		--FULL Backup
				BEGIN
					SET @myDatabase_FileSizeGB=
						CASE @myIsCompressionEnabled
							WHEN 1 THEN																		--Compression enabled
								CASE 
									WHEN @myEstimatedCompressionRate=@myNormalCompressionRate THEN (ISNULL(@myDatabase_RowSizeGB,0) / @myEstimatedCompressionRate)+ISNULL(@myDatabase_FilestreamSizeGB,0)	--System could not determine real estimation of CompressionRate
									ELSE (ISNULL(@myDatabase_RowSizeGB,0)+ISNULL(@myDatabase_FilestreamSizeGB,0))/@myEstimatedCompressionRate																--System could determine real estimation of CompressionRate and use it
								END
							ELSE ISNULL(@myDatabase_RowSizeGB,0)+ISNULL(@myDatabase_FilestreamSizeGB,0)		--Compression disabled
						END
				END
				ELSE IF @BackupType=N'DIFF'		--DIFF Backup
				BEGIN
					SET @myDatabase_FileSizeGB=
						CASE @myIsCompressionEnabled
							WHEN 1 THEN																		--Compression enabled
								CASE 
									WHEN @myEstimatedCompressedBackupSize IS NOT NULL THEN @myEstimatedCompressedBackupSize																																--System use estimated backup size value
									WHEN @myEstimatedCompressedBackupSize IS NULL AND @myEstimatedCompressionRate=@myNormalCompressionRate THEN (ISNULL(@myDatabase_RowSizeGB,0) / @myEstimatedCompressionRate)+ISNULL(@myDatabase_FilestreamSizeGB,0)	--System could not use estimated backup size value and also could not determine real estimation of CompressionRate
									ELSE (ISNULL(@myDatabase_RowSizeGB,0)+ISNULL(@myDatabase_FilestreamSizeGB,0))/@myEstimatedCompressionRate																											--System could not use estimated backup size value but could determine real estimation of CompressionRate and use it
								END
							ELSE																			--Compression disabled
								CASE 
									WHEN @myEstimatedBackupSize IS NOT NULL THEN @myEstimatedBackupSize				--There is no Compression and System could not use estimated backup size value
									ELSE ISNULL(@myDatabase_RowSizeGB,0)+ISNULL(@myDatabase_FilestreamSizeGB,0)		--There is no Compression
								END
						END
				END

				--Calculate @myDatabase_BackupFileCount
				SET @myDatabase_BackupFileCount=(@myDatabase_FileSizeGB*1.0)/(@SplitThresholdSizeGB*1.0)					--Split by ThresholdSizeGB
				SET @myDatabase_BackupFileCount=CASE 
													WHEN @myDatabase_BackupFileCount=0 THEN @myDatabase_BackupDestinationCount	--1
													WHEN ((@myDatabase_BackupFileCount*1.0)%(@myDatabase_BackupDestinationCount*1.0))=0 THEN @myDatabase_BackupFileCount	--Current value is OK
													WHEN ((@myDatabase_BackupFileCount*1.0)%(@myDatabase_BackupDestinationCount*1.0))>0 THEN CAST((CAST(((@myDatabase_BackupFileCount*1.0)/(@myDatabase_BackupDestinationCount*1.0)) AS BIGINT)+1)*@myDatabase_BackupDestinationCount AS DECIMAL(7,2))	--Rounding Backup file count to Destination numbers for equal spreading	--AND @myDatabase_BackupFileCount>CAST(@myDatabase_BackupFileCount AS BIGINT) THEN CAST(CAST(@myDatabase_BackupFileCount AS BIGINT)+1 AS DECIMAL(7,2))
													ELSE @myDatabase_BackupFileCount
												END
				SET @myDatabase_BackupFileCount=CASE WHEN @myDatabase_BackupFileCount>64 THEN 64 ELSE @myDatabase_BackupFileCount END	--Maximum number of backup devices is 64 until SQL2017
			END
			ELSE
			BEGIN	--User does not use backup split feature
				SET @myDatabase_BackupFileCount=1
			END


			--Create Destination Path(s) on Physical disk(s) and Assigne @myBackupDisks and @myMediaSet_Name values
				SET @myIterator01=1
				SET @myIterator02=1
				SET @myBackupDisks=CAST(N'' AS NVARCHAR(MAX))
				--PRINT @myDatabase_BackupDestinationCount
				WHILE @myIterator01<=@myDatabase_BackupFileCount
				BEGIN
					SELECT @myNewFolder=[myDestinations].[Path] FROM #myDestinationTable AS myDestinations WHERE [ID]=@myIterator02
										--Validate local storage path folder structure and make directory structure if it does not exists
					IF @myIterator02=@myIterator01
						EXECUTE [dbo].dbasp_make_directory @myNewFolder;
										--Calculate full path of backupfile location (in local disk)
					SET @myBackupDisks=@myBackupDisks + CAST(N'DISK=N''' + @myNewFolder + N'\' + UPPER(@BackupType) +N'_'+ @myDatabase_Name + N'_' + @myCalendar_Date + (CASE WHEN @BackupFileNamingType IN (N'DATETIME',N'JDATETIME') THEN '_on_'+ @myTimeChar ELSE N'' END) + N'_' + CAST(@myIterator01 AS NVARCHAR(MAX)) + N'of' + CAST(CAST(@myDatabase_BackupFileCount AS BIGINT) AS NVARCHAR(MAX)) + N'.' + @BackupExtension + N''','  AS NVARCHAR(MAX))
					SET @myIterator01=@myIterator01+1
					SET @myIterator02=@myIterator02+1
					SET @myIterator02=CASE WHEN @myIterator02>@myDatabase_BackupDestinationCount THEN 1 ELSE @myIterator02 END
				END
				SET @myMediaSet_Name=UPPER(@BackupType) +N'_'+ @myDatabase_Name + N'_' + @myCalendar_Date + (CASE WHEN @BackupFileNamingType IN (N'DATETIME',N'JDATETIME') THEN '_on_'+ @myTimeChar ELSE N'' END)
				SET @myBackupDisks=CASE RIGHT(@myBackupDisks,1) WHEN N',' THEN LEFT(@myBackupDisks,LEN(@myBackupDisks)-1) ELSE @myBackupDisks END
				DROP TABLE #myDestinationTable


			--Determine Changed Size of data (via DCM pages) for Diff backup and current log file size for Log backup and compare it with Backup change size threshold
				IF @BackupType=N'DIFF'		--DIFF Backup
				BEGIN
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
					INSERT INTO @myDcmQueue	([FileId], [PageId]) SELECT [myDCMPages].[file_id],([myDCMPages].[DcmPageNo]*@myDCMpageLength)+6 
					FROM [myDCMPages] 
					ORDER BY [myDCMPages].[file_id],[myDCMPages].[DcmPageNo]
					OPTION (maxrecursion 0)

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
						@myDiffOrLogChangedSizeGB=CAST(SUM([myModifiedPages].[EndPage]-[myModifiedPages].[StartPage]+1) * 8.0 / (1024.0*1024) AS BIGINT) --AS ModifiedPages_GB
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
				END
				ELSE IF @BackupType=N'LOG'		--LOG Backup
				BEGIN
					SET @myDiffOrLogChangedSizeGB = @myDatabase_LogSizeGB
				END
				ELSE IF @BackupType=N'FULL'		--FULL Backup, set @myDiffOrLogChangedSizeGB size equal to @DiffOrLogThresholdSizeGB bacause of This rule should return true for FULL backup in any situation
				BEGIN
					SET @myDiffOrLogChangedSizeGB = @DiffOrLogThresholdSizeGB
				END

				IF ISNULL(@myDiffOrLogChangedSizeGB,0)>=ISNULL(@DiffOrLogThresholdSizeGB,0)
					SET @mySizeThresholdIsOK=1
				--PRINT (N'DiffOrLogThresholdSizeGB is ' + CAST(@DiffOrLogThresholdSizeGB AS NVARCHAR(MAX)) + N', DiffOrLogChangedSizeGB is ' + CAST(@myDiffOrLogChangedSizeGB AS NVARCHAR(MAX)) + N', SizeThresholdIsOK is ' + CAST(@mySizeThresholdIsOK AS nvarchar(MAX)))


			--Determine Backup type and take it
			IF (UPPER(@BackupType)= UPPER('FULL') OR UPPER(@BackupType)= UPPER('LOG') OR UPPER(@BackupType)= UPPER('DIFF')) AND @mySizeThresholdIsOK=1 --Specify BackupType
				BEGIN
					IF UPPER(@BackupType)=UPPER('FULL')
					BEGIN
					------------------------------
					---- Full Backup operation ---
					------------------------------
						--Config parameters
						SET @myMediaSet_Desc=@myMediaSet_Name 																						--Set mediaset description as mediaset name
						SET @myBackupSet_Name=@myMediaSet_Name + (CASE WHEN @BackupFileNamingType IN (N'DATETIME',N'JDATETIME') THEN '_on_' + @myTimeChar ELSE N'' END)	--Specify backupset name default value, the default value is a Full backup (Ex: Full_Kasra_1392_10_01)
						SET @myBackupSet_Desc=@myBackupSet_Name																						--Set backupset description as backupset name
				
						--Generate information about backup
						SET @myInfo_Message='Database='+@myDatabase_Name+', Mediaset='+@myMediaSet_Name+',Backupset='+@myBackupset_Name+','+@myBackupDisks
				
						--=========Take Full Backup
						SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
						SET @mySQLScript=@mySQLScript+
							CAST(
							@myNewLine+N'BACKUP DATABASE ' + CAST(QUOTENAME(@myDatabase_Name) AS NVARCHAR(MAX)) + 
							@myNewLine+N'	TO ' + @myBackupDisks + N' WITH '+
							@myNewLine+N'	NAME = N''' + @myBackupSet_Name + N''','+
							@myNewLine+N'	DESCRIPTION = N''' + @myBackupSet_Desc + N''','+
							@myNewLine+N'	MEDIANAME = N''' + @myMediaSet_Name + N''','+
							@myNewLine+N'	MEDIADESCRIPTION = N''' + @myMediaSet_Desc + N''','+
							@myNewLine+N'	RETAINDAYS = ' + CAST(@RetainDays AS NVARCHAR(MAX)) + N','+
							@myNewLine+N'	NOFORMAT,NOINIT,NOSKIP,COMPRESSION,CHECKSUM,STATS=10'+
							CASE WHEN @BackupCertificateName IS NOT NULL THEN @myNewLine+N'	,ENCRYPTION (ALGORITHM = AES_256,SERVER CERTIFICATE = '+ CAST(@BackupCertificateName AS NVARCHAR(MAX)) +')' ELSE N'' END
							AS NVARCHAR(MAX))
							--, MaxTransferSize=524288 --512KB Read Chunck size for decrese I/O stress
						BEGIN TRY
							EXEC dbo.dbasp_print_text @mySQLScript
							IF @PrintOnly=0
								EXEC sp_executesql @mySQLScript
							SET @myEveryThingIsOK=1
						END TRY
						BEGIN CATCH
							DECLARE @CustomMessage1 nvarchar(255)
							SET @CustomMessage1='Take Full Backup error on ' + @myDatabase_Name
							EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL

							SET @myEveryThingIsOK=0
						END CATCH

						--=========Verification & Checkpoint step
						BEGIN TRY
							IF @myEveryThingIsOK=1 AND @PrintOnly=0
							BEGIN
								SELECT @myBackupSetId = position from msdb.dbo.backupset where [database_name]=@myDatabase_Name and backup_set_id=(select max(backup_set_id) from msdb.dbo.backupset where database_name=@myDatabase_Name)
								IF @myBackupSetId is null
									BEGIN 
										SET @myError_Message='Full Backup verification failed ('+ @myInfo_Message +'). information for database not found.'
										RAISERROR(@myError_Message , 16, 1)
										SET @myEveryThingIsOK=0;
									END
								SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
								SET @mySQLScript=@mySQLScript+CAST(@myNewLine+N'RESTORE VERIFYONLY FROM ' + @myBackupDisks + N' WITH  FILE = ' + CAST(@myBackupSetId AS NVARCHAR(MAX)) + N', NOUNLOAD, NOREWIND' AS NVARCHAR(MAX))
								EXEC sp_executesql @mySQLScript
							END
						END TRY
						BEGIN CATCH
							DECLARE @CustomMessage2 nvarchar(255)
							SET @CustomMessage2='Full Backup Verification or Checkpoint error on ' + @myDatabase_Name
							EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage2,1,0,1,0,NULL

							SET @myEveryThingIsOK=0
						END CATCH
					END
			
					IF UPPER(@BackupType)=UPPER('LOG') AND @myDatabase_RecoveryModel<>3	--not in Simple Recovery Model
					BEGIN
					------------------------------
					---- Log Backup operation ----
					------------------------------
						--Config parameters
						SET @myMediaSet_Desc=@myMediaSet_Name																						--Set mediaset description as mediaset name
						SET @myBackupSet_Name=@myMediaSet_Name + (CASE WHEN @BackupFileNamingType IN (N'DATETIME',N'JDATETIME') THEN '_on_' + @myTimeChar ELSE N'' END)	--Specify backupset name default value, the default value is a Full backup (Ex: Full_Kasra_1392_10_01)
						SET @myBackupSet_Desc=@myBackupSet_Name																						--Set backupset description as backupset name

						--Generate information about backup
						SET @myInfo_Message='Database='+@myDatabase_Name+', Mediaset='+@myMediaSet_Name+',Backupset='+@myBackupset_Name+','+@myBackupDisks
				
						--=========Take Log Backup
						SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
						SET @mySQLScript=@mySQLScript+
							CAST(
							@myNewLine+N'BACKUP LOG ' + CAST(QUOTENAME(@myDatabase_Name) AS NVARCHAR(MAX)) + 
							@myNewLine+N'	TO ' + @myBackupDisks + N' WITH '+
							@myNewLine+N'	NAME = N''' + @myBackupSet_Name + N''','+
							@myNewLine+N'	DESCRIPTION = N''' + @myBackupSet_Desc + N''','+
							@myNewLine+N'	MEDIANAME = N''' + @myMediaSet_Name + N''','+
							@myNewLine+N'	MEDIADESCRIPTION = N''' + @myMediaSet_Desc + N''','+
							@myNewLine+N'	RETAINDAYS = ' + CAST(@RetainDays AS NVARCHAR(MAX)) + N','+
							@myNewLine+N'	NOFORMAT,NOINIT,NOSKIP,COMPRESSION,CHECKSUM,STATS=10'+
							CASE WHEN @BackupCertificateName IS NOT NULL THEN @myNewLine+N'	,ENCRYPTION (ALGORITHM = AES_256,SERVER CERTIFICATE = '+ CAST(@BackupCertificateName AS NVARCHAR(MAX)) +')' ELSE N'' END
							AS NVARCHAR(MAX))
							--, MaxTransferSize=524288 --512KB Read Chunck size for decrese I/O stress
						BEGIN TRY
							EXEC dbo.dbasp_print_text @mySQLScript
							IF @PrintOnly=0
								EXEC sp_executesql @mySQLScript
							SET @myEveryThingIsOK=1
						END TRY
						BEGIN CATCH
							DECLARE @CustomMessage3 nvarchar(255)
							SET @CustomMessage3='Take Log Backup error on ' + @myDatabase_Name
							EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage3,1,0,1,0,NULL

							SET @myEveryThingIsOK=0
						END CATCH

						--=========Verification & Checkpoint step
						BEGIN TRY
							IF @myEveryThingIsOK=1 AND @PrintOnly=0
							BEGIN
								SELECT @myBackupSetId = position FROM msdb.dbo.backupset WHERE [database_name]=@myDatabase_Name and backup_set_id=(select max(backup_set_id) from msdb.dbo.backupset where database_name=@myDatabase_Name )
								IF @myBackupSetId is null 
									BEGIN 
										SET @myError_Message='Log Backup verification failed ('+ @myInfo_Message +'). information for database not found.'
										RAISERROR(@myError_Message , 16, 1) 
										SET @myEveryThingIsOK=0;
									END
								SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
								SET @mySQLScript=@mySQLScript+CAST(@myNewLine+N'RESTORE VERIFYONLY FROM ' + @myBackupDisks + N' WITH  FILE = ' + CAST(@myBackupSetId AS NVARCHAR(MAX)) + N', NOUNLOAD, NOREWIND' AS NVARCHAR(MAX))
								EXEC sp_executesql @mySQLScript
							END
						END TRY
						BEGIN CATCH
							DECLARE @CustomMessage4 nvarchar(255)
							SET @CustomMessage4='Log Backup Verification or Checkpoint error on ' + @myDatabase_Name
							EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage4,1,0,1,0,NULL

							SET @myEveryThingIsOK=0
						END CATCH
					END

					IF UPPER(@BackupType)=UPPER('DIFF')
					BEGIN
					------------------------------
					---- DIFF Backup operation ---
					------------------------------
						--Config parameters
						SET @myMediaSet_Desc=@myMediaSet_Name																						--Set mediaset description as mediaset name
						SET @myBackupSet_Name=@myMediaSet_Name + (CASE WHEN @BackupFileNamingType IN (N'DATETIME',N'JDATETIME') THEN '_on_' + @myTimeChar ELSE N'' END)	--Specify backupset name default value, the default value is a Full backup (Ex: Full_Kasra_1392_10_01)
						SET @myBackupSet_Desc=@myBackupSet_Name																						--Set backupset description as backupset name

						--Generate information about backup
						SET @myInfo_Message='Database='+@myDatabase_Name+', Mediaset='+@myMediaSet_Name+',Backupset='+@myBackupset_Name+','+@myBackupDisks
				
						--=========Take Diff Backup
						SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
						SET @mySQLScript=@mySQLScript+
							CAST(
							@myNewLine+N'BACKUP DATABASE ' + CAST(QUOTENAME(@myDatabase_Name) AS NVARCHAR(MAX)) + 
							@myNewLine+N'	TO ' + @myBackupDisks + N' WITH '+
							@myNewLine+N'	NAME = N''' + @myBackupSet_Name + N''','+
							@myNewLine+N'	DESCRIPTION = N''' + @myBackupSet_Desc + N''','+
							@myNewLine+N'	MEDIANAME = N''' + @myMediaSet_Name + N''','+
							@myNewLine+N'	MEDIADESCRIPTION = N''' + @myMediaSet_Desc + N''','+
							@myNewLine+N'	RETAINDAYS = ' + CAST(@RetainDays AS NVARCHAR(MAX)) + N','+
							@myNewLine+N'	NOFORMAT,NOINIT,NOSKIP,COMPRESSION,CHECKSUM,STATS=10,DIFFERENTIAL'+
							CASE WHEN @BackupCertificateName IS NOT NULL THEN @myNewLine+N'	,ENCRYPTION (ALGORITHM = AES_256,SERVER CERTIFICATE = '+ CAST(@BackupCertificateName AS NVARCHAR(MAX)) +')' ELSE N'' END
							AS NVARCHAR(MAX))
							--, MaxTransferSize=524288 --512KB Read Chunck size for decrese I/O stress
						BEGIN TRY
							EXEC dbo.dbasp_print_text @mySQLScript
							IF @PrintOnly=0
								EXEC sp_executesql @mySQLScript
							SET @myEveryThingIsOK=1
						END TRY
						BEGIN CATCH
							DECLARE @CustomMessage5 NVARCHAR(255)
							SET @CustomMessage5='Take Differential Backup error on ' + @myDatabase_Name
							EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage5,1,0,1,0,NULL

							SET @myEveryThingIsOK=0
						END CATCH

						--=========Verification & Checkpoint step
						BEGIN TRY
							IF @myEveryThingIsOK=1 AND @PrintOnly=0
							BEGIN
								SELECT @myBackupSetId = position FROM msdb.dbo.backupset WHERE [database_name]=@myDatabase_Name AND backup_set_id=(SELECT MAX(backup_set_id) FROM msdb.dbo.backupset WHERE database_name=@myDatabase_Name )
								IF @myBackupSetId IS NULL 
									BEGIN 
										SET @myError_Message='Differential Backup verification failed ('+ @myInfo_Message +'). information for database not found.'
										RAISERROR(@myError_Message , 16, 1)
										SET @myEveryThingIsOK=0;
									END
								SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
								SET @mySQLScript=@mySQLScript+CAST(@myNewLine+N'RESTORE VERIFYONLY FROM ' + @myBackupDisks + N' WITH  FILE = ' + CAST(@myBackupSetId AS NVARCHAR(MAX)) + N', NOUNLOAD, NOREWIND' AS NVARCHAR(MAX))
								EXEC sp_executesql @mySQLScript
							END
						END TRY
						BEGIN CATCH
							DECLARE @CustomMessage6 NVARCHAR(255)
							SET @CustomMessage6='Differential Backup Verification or Checkpoint error on ' + @myDatabase_Name
							EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage6,1,0,1,0,NULL

							SET @myEveryThingIsOK=0
						END CATCH
					END
					--====================================================================================================
					--Print backup information
					PRINT @myInfo_Message
					IF @myEveryThingIsOK = 1
						SET @myVerifiedBackupCount = @myVerifiedBackupCount+1;
				END
				ELSE
				BEGIN
					IF @mySizeThresholdIsOK=0
					BEGIN
						PRINT 'LOG or DIFF size is less than DiffOrLogThresholdSizeGB'
					END
					ELSE
                    BEGIN
						PRINT '@BackupType value should be FULL or LOG or DIFF'
					END
				END
				FETCH NEXT FROM @myCursor INTO @myDatabase_Name,@myDatabase_RecoveryModel
			END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;

	RETURN @myVerifiedBackupCount
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_take_backup', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-25', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_take_backup', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2022-12-19', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_take_backup', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.6', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_take_backup', NULL, NULL
GO
