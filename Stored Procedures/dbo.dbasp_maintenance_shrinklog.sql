SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/21/2015>
-- Version:		<3.0.0.2>
-- Description:	<Shrink log file>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@TargetSizeMB:	'0' or (any positive value) or 'EP:xxx' (for extended properties with name of xxx that can be replace with any string) or 'Auto' (for Auto that not recommended) //if you use TargetSize less than zero, sp automatically determine and use current log size value of database(s) as TargetSizeMB but this value IS NOT RECOMMENDED!!!
--	@Print_Only:	0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_shrinklog]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@TargetSizeMB NVARCHAR(255) = N'0',
	@Print_Only BIT=0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	Declare @Database_Id int;
	DECLARE @ActualShrinkableLogSizePage bigint;
	DECLARE @TargetSizeMBValue bigint;
	DECLARE @IsTargetSizeMBValueSet bit;
	DECLARE @EP_cmd nvarchar(MAX);
	DECLARE @EP_tbl TABLE (ShrinkSize bigint);
	DECLARE @TargetSizePage bigint;
	DECLARE @CurrentLogSizePage bigint
	DECLARE @ShrinkToSizePage bigint;
	DECLARE @ShrinkToSizeMB bigint;
    DECLARE @LogicalName sysname;
	DECLARE @LogFile_Id int;
    DECLARE @RecoveryModel nvarchar(20);
    DECLARE @Command as nvarchar(4000)
    DECLARE @CommandParameters as nvarchar(255)
    DECLARE @Error_Message nvarchar(255);
    DECLARE @ReturnValue bit;
	DECLARE @versionString NVARCHAR(20);
	DECLARE @serverVersion DECIMAL(10,5);
	DECLARE @sqlServer2012Version DECIMAL(10,5);

    SET @ReturnValue=0;
    SET @Error_Message=''; 
	SET @versionString = CAST(SERVERPROPERTY('productversion') AS NVARCHAR(20))
	SET @serverVersion = CAST(LEFT(@versionString,CHARINDEX('.', @versionString)) AS DECIMAL(10,5))
	SET @sqlServer2012Version = 11.0 -- SQL Server 2012

    SET @myCursor=CURSOR For
		Select 
			myDbList.[Name] AS DbName,
			[myLogFiles].[database_id] AS [DbId],
			[myLogFiles].name AS LogName,
			[myLogFiles].file_id AS [file_id]
		FROM 
			[dbo].[dbafn_database_list](@DatabaseNames,1,0,1,1,1) AS myDbList
			INNER JOIN master.sys.master_files AS myLogFiles ON [myDbList].[Name]=DB_NAME([myLogFiles].[database_id])
		WHERE 
			[myLogFiles].type=1

    Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name,@Database_Id,@LogicalName,@LogFile_Id
		WHILE @@FETCH_STATUS=0
			BEGIN
				--Extract @TargetSizeMBValue: Start
				SET @TargetSizeMBValue=0
				SET @IsTargetSizeMBValueSet=0
				IF (@IsTargetSizeMBValueSet=0) AND (ISNUMERIC(@TargetSizeMB)=1)
					BEGIN
					SET @TargetSizeMBValue=CAST(@TargetSizeMB as bigint)
					SET @IsTargetSizeMBValueSet=1
					END
				IF (@IsTargetSizeMBValueSet=0) AND (UPPER(@TargetSizeMB)=UPPER(N'AUTO'))
					BEGIN
					SET @TargetSizeMBValue=-1
					SET @IsTargetSizeMBValueSet=1
					END
				IF (@IsTargetSizeMBValueSet=0) AND (LEFT(UPPER(@TargetSizeMB),3)=UPPER(N'EP:'))
					BEGIN
					SET @EP_cmd=CAST (N'' AS NVARCHAR(MAX))
					SET @EP_cmd=@EP_cmd+CAST(N'SELECT CAST(value as bigint) as ShrinkSize from ' + CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N'.sys.extended_properties WHERE class=0 and name=''' + CAST(RIGHT(@TargetSizeMB,LEN(@TargetSizeMB)-3) AS NVARCHAR(MAX)) + '''' AS NVARCHAR(MAX))
					DELETE FROM @EP_tbl
					INSERT INTO @EP_tbl (ShrinkSize) EXECUTE sp_executesql @EP_cmd
					SET @TargetSizeMBValue= ISNULL((Select Top 1 ShrinkSize FROM @EP_tbl),0)
					SET @IsTargetSizeMBValueSet=1
					END
				--Extract @TargetSizeMBValue: End

				SET @TargetSizePage = @TargetSizeMBValue * 1024 / 8
				--Select @LogicalName=name, @CurrentLogSizePage=size from master.sys.master_files where database_id=@Database_Id and type=1
				Select @CurrentLogSizePage=BytesOnDisk/(1024*8) from sys.fn_virtualfilestats(@Database_Id,@LogFile_Id)
				If Not @LogicalName Is null					--If Databse is valid and has a log file
					BEGIN
						SELECT @RecoveryModel=recovery_model_desc from sys.databases where name=@Database_Name
						IF UPPER(@RecoveryModel) IN ('FULL','BULK_LOGGED','SIMPLE')			--If Database is in Full or Bulk recovery model
						BEGIN
						
							--Determine Initial log size value in MB for less than zero TargetSizeMB parameters
							IF @TargetSizePage < 0 
								SET @TargetSizePage = @CurrentLogSizePage
								
							IF(@serverVersion >= @sqlServer2012Version)
								BEGIN
									-- Use the new version of the table  
									DECLARE @logInfoResult2012 TABLE
										(
										[RecoveryUnitId]    INT NULL,
										[FileId]            INT NULL,
										[FileSize]            BIGINT NULL,
										[StartOffset]        BIGINT NULL,
										[FSeqNo]            INT NULL,
										[Status]            INT NULL,
										[Parity]            TINYINT NULL,
										[CreateLSN]            NUMERIC(25, 0) NULL
										)
										
									DECLARE @logSpaceUsedResult2012 TABLE
										(
										[Database Name]			sysname NULL,
										[Log Size (MB)]			FLOAT NULL,
										[Log Space Used (%)]	FLOAT NULL,
										[Status]				BIGINT NULL
										)

									SET @Command='Use ' + QUOTENAME(@Database_Name) +';DBCC LOGINFO;'
									Delete from @LogInfoResult2012
									Insert into @LogInfoResult2012 exec (@Command)
									Delete from @LogInfoResult2012 WHERE [FileId] != @LogFile_Id

									--Select @ActualLogSize = SUM(filesize)/(1024*1024)from @logInfoResult2012 where Status=0 group by fileid
									Select @ActualShrinkableLogSizePage = @CurrentLogSizePage - ISNULL(SUM(filesize)/(1024*8),@CurrentLogSizePage) FROM @logInfoResult2012 WHERE StartOffset > (SELECT MAX(myActivePortion.StartOffset) as LastActiveOffset From @logInfoResult2012 as myActivePortion WHERE myActivePortion.Status=2) AND Status=0
									
									--In AlwaysOn enabled database usally all VLF files have [Status] value of 2 in DBCC LogInfo because of compatibility issues, then you should estimating log free space with SQLPERF(LOGSPACE) command
									IF @ActualShrinkableLogSizePage=0
									BEGIN
										SET @Command='Use ' + QUOTENAME(@Database_Name) +';DBCC SQLPERF(LOGSPACE);'
										Delete from @logSpaceUsedResult2012
										Insert into @logSpaceUsedResult2012 exec (@Command)
										SELECT @ActualShrinkableLogSizePage=CAST(ISNULL(((([Log Space Used (%)])*[Log Size (MB)])/100)*(1024/8),0) AS BIGINT) FROM @logSpaceUsedResult2012 WHERE [Database Name]=@Database_Name
									END
								END  
							ELSE  
								BEGIN
									-- Use the old version of the table
									DECLARE @logInfoResult2008 TABLE
										(
										[FileId]            INT NULL,
										[FileSize]            BIGINT NULL,
										[StartOffset]        BIGINT NULL,
										[FSeqNo]            INT NULL,
										[Status]            INT NULL,
										[Parity]            TINYINT NULL,
										[CreateLSN]            NUMERIC(25, 0) NULL
										)

									SET @Command='Use ' + QUOTENAME(@Database_Name) +';dbcc loginfo;'
									Delete from @LogInfoResult2008
									Insert into @LogInfoResult2008 exec (@Command)
									Delete from @LogInfoResult2008 WHERE [FileId]!=@LogFile_Id

									--Select @ActualLogSize = SUM(filesize)/(1024*1024)from @logInfoResult2008 where Status=0 group by fileid
									Select @ActualShrinkableLogSizePage = @CurrentLogSizePage - ISNULL(SUM(filesize)/(1024*8),@CurrentLogSizePage) FROM @logInfoResult2008 WHERE StartOffset > (SELECT MAX(myActivePortion.StartOffset) as LastActiveOffset From @logInfoResult2008 as myActivePortion WHERE myActivePortion.Status=2) AND Status=0
 								END

							
							IF @TargetSizePage < @CurrentLogSizePage	--Requested size should not be greater than Current size
								BEGIN
									IF @TargetSizePage >= @ActualShrinkableLogSizePage
									BEGIN	--If Target size is greater than shrinkable size then use target size to do shrink
										SET @ShrinkToSizePage = @TargetSizePage
									END
									ELSE
									BEGIN	--If Target size is less than shrinkable size then use shrinkable size to do shrink
										SET @ShrinkToSizePage = @ActualShrinkableLogSizePage
									END
								END
								ELSE
								BEGIN
									SET @ShrinkToSizePage = @TargetSizePage
								END
								
							IF @ShrinkToSizePage < @CurrentLogSizePage
								BEGIN
									SET @ShrinkToSizeMB = @ShrinkToSizePage * 8 / 1024
									SET @Command='USE ' + QUOTENAME(@Database_Name) +'; '
									SET @Command= @Command + 'CHECKPOINT;'
									SET @Command= @Command + 'DBCC SHRINKFILE ('''+ CAST(@LogicalName as nvarchar(255)) + ''',' + CAST(@ShrinkToSizeMB as nvarchar(255)) + ');'
									Print @Command
									--==============Start of Shrinking log
									BEGIN TRY
										IF @Print_Only=0
											EXEC (@Command)
									END TRY
									BEGIN CATCH
										DECLARE @CustomMessage nvarchar(255)
										SET @CustomMessage='Shrink log error on ' + @Database_Name
										EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
									END CATCH
									--dbcc shrinkfile (@LogicalName,@ShrinkToSizeMB);
									--==============End of Shrinking log
								END
						END		--If Database is in Full or Bulk recovery model
						ELSE
						BEGIN	--If Database is in SIMPLE recovery model
							Print (' - ' + @Database_Name + ' is in SIMPLE recovery model and you can not shrink it.')
							--SET @Error_Message = @Error_Message + ' - you can not shrinking log in simple recovery model for ' + @Database_Name;
							--SET @ReturnValue=1;
						END
					END		--If Databse is valid and has a log file
				ELSE									--Raise Error if Database name is not valid or has not any log file
					BEGIN
						SET @Error_Message = @Error_Message + ' - shrink log failed for ' + @Database_Name;
						SET @ReturnValue=1;
					END
				FETCH NEXT FROM @myCursor INTO @Database_Name,@Database_Id,@LogicalName,@LogFile_Id
			END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;

	If @ReturnValue=1										--Send error message to caller
		Begin
			raiserror(@Error_Message , 16, 1);
		End
	
	Return @ReturnValue
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_shrinklog', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_shrinklog', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-04-01', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_shrinklog', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.2', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_shrinklog', NULL, NULL
GO
