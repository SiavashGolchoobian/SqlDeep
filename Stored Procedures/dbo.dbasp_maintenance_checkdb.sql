SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/21/2015>
-- Version:		<3.0.0.0>
-- Description:	<Run DBCC Checkdb to correct any database errors>
-- Input Parameters:
--	@DatabaseNames:					'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@SnapshotPathForReadonlyFiles:	a Folder path for saving snapshot of possible readonly database filegroups
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_checkdb]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>'
	,@SnapshotPathForReadonlyFiles NVARCHAR(256)=NULL
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @DatabaseforCheck nvarchar(255);
	DECLARE @SnapshotSuffix nvarchar(20);
	DECLARE @SnapshotCreated bit
	DECLARE @SnapshotDropCmd nvarchar(MAX);
	DECLARE @myCursor Cursor;
	
	SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,0,1)
	
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
			WHILE @@FETCH_STATUS=0
			BEGIN
				SET @DatabaseforCheck=@Database_Name
				SET @SnapshotCreated=0
				
				--Phase0: Check for any read-only filegroup existence, so if existed sp will run dbcc on snapshot of database
				IF EXISTS(SELECT 1 FROM sys.master_files WHERE is_read_only=1 AND database_id=DB_ID(@Database_Name))
				BEGIN
					SET @SnapshotSuffix = N'_' + REPLACE(CAST(CAST(GETDATE() as DATE) as nvarchar(10)), N'-',N'')+ N'_' +CAST(ABS(CHECKSUM(NewId())) % 100 as nvarchar(3))
					SET @DatabaseforCheck=@Database_Name + @SnapshotSuffix
					--==========Start of Creating SNAPSHOT
					BEGIN TRY
						EXECUTE dbo.dbasp_create_snapshot @Database_Name, @SnapshotSuffix,@SnapshotPathForReadonlyFiles,0
					END TRY
					BEGIN CATCH
						DECLARE @CustomMessage1 NVARCHAR(255)
						SET @CustomMessage1='Create Snapshot error on ' + @Database_Name
						EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
					END CATCH
					--==========END of Creating SNAPSHOT
					IF EXISTS(SELECT 1 FROM sys.databases WHERE name=@DatabaseforCheck AND source_database_id IS NOT NULL)
						SET @SnapshotCreated=1
				END
				
				--Phase1: Run DBCC Checkdb
				BEGIN TRY
				IF EXISTS(SELECT 1 FROM sys.databases WHERE [name]=@DatabaseforCheck)
					DBCC CHECKDB (@DatabaseforCheck) WITH NO_INFOMSGS, ALL_ERRORMSGS;
				END TRY
				BEGIN CATCH
					EXECUTE [dbo].[dbasp_get_error_info] 'DBCC CHECKDB error',1,0,1,0,NULL
				END CATCH

				--Phase2: Drop created snapshot
				IF @SnapshotCreated=1 AND EXISTS(SELECT 1 FROM sys.databases WHERE name=@DatabaseforCheck AND source_database_id IS NOT NULL)
				BEGIN
					--============Start of Removing any existence snapshot
					BEGIN TRY
						SET @SnapshotDropCmd=CAST(N'' AS NVARCHAR(MAX))
						SET @SnapshotDropCmd=@SnapshotDropCmd+CAST(N'msdb.dbo.sp_delete_database_backuphistory @database_name = N''' + @DatabaseforCheck + '''' AS NVARCHAR(MAX))
						EXECUTE sp_executesql @SnapshotDropCmd;
						SET @SnapshotDropCmd=CAST(N'' AS NVARCHAR(MAX))
						SET @SnapshotDropCmd=@SnapshotDropCmd+CAST(N'USE [master]; DROP DATABASE ' + QUOTENAME(@DatabaseforCheck)+N';' AS NVARCHAR(MAX))
						--SET @SnapshotDropCmd='DROP DATABASE ' + QUOTENAME(@DatabaseforCheck)
						EXECUTE sp_executesql @SnapshotDropCmd;
					END TRY
					BEGIN CATCH
						DECLARE @CustomMessage2 NVARCHAR(255)
						SET @CustomMessage2='Droping snapshot error for ' + @Database_Name
						EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage2,1,0,1,0,NULL
					END CATCH
					--============End of Removing any existence snapshot
				END
				
				FETCH NEXT FROM @myCursor INTO @Database_Name
			END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;

END




GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_checkdb', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_checkdb', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_checkdb', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_checkdb', NULL, NULL
GO
