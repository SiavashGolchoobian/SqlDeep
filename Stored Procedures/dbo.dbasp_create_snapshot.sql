SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/21/2015>
-- Version:		<3.0.0.1>
-- Description:	<Create database snapshot>
-- Input Parameters:
--	@DatabaseNames:				'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@SnapshotNameSuffix:		Suffix of database snapshot name
--	@SnapshotFolderLocation:	Folder path of snapshot \\ Ex:F:\SnapshotFolder
--	@PrintOnly:		0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_create_snapshot]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>'
	,@SnapshotNameSuffix NVARCHAR(20) = N'_snp'
	,@SnapshotFolderLocation NVARCHAR(256)
	,@PrintOnly bit=0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myOsPathSeperator CHAR(1);
	DECLARE @Database_Name nvarchar(255);
	DECLARE @SnapshotArray dbo.ConcatTableType_v03;
	DECLARE @SqlCmd nvarchar(MAX);
	DECLARE @myCursor Cursor;
	
	SET @myOsPathSeperator = CASE WHEN CHARINDEX('Linux',@@VERSION,1)<>0 THEN N'/' ELSE N'\' END
	SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,0,0)
		
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
			WHILE @@FETCH_STATUS=0
			BEGIN
				SET @SqlCmd=CAST(N'' AS NVARCHAR(MAX))
				DELETE FROM @SnapshotArray
				INSERT INTO @SnapshotArray
				SELECT 
					'(NAME = ''' + myDbFiles.name + 
					''', FileName=''' + @SnapshotFolderLocation + @myOsPathSeperator + @SnapshotNameSuffix +'_' + myDbFiles.[name] + '_' + CAST(myDbFiles.file_id as nvarchar) + '_' + CAST(NEWID() AS NVARCHAR(50)) + '.snp'')' 
				FROM 
					sys.master_files as myDbFiles 
				WHERE 
					myDbFiles.[type] NOT IN (1,2) --1:Log File, 2:Filestream Folder
					AND myDbFiles.database_id=DB_ID(@Database_Name)
				
				SET @SqlCmd	= @SqlCmd + N'CREATE DATABASE ' + QUOTENAME(@Database_Name + @SnapshotNameSuffix) + N' ON ' + 
								dbo.dbafn_concat(@SnapshotArray,N',') + 
								N' AS SNAPSHOT OF ' + QUOTENAME(@Database_Name)
				
				EXEC [dbo].[dbasp_print_text] @SqlCmd;
				--==========Start of creating Snapshot
				BEGIN TRY
					IF @PrintOnly=0
						EXECUTE (@SqlCmd);
				END TRY
				BEGIN CATCH
					DECLARE @CustomMessage nvarchar(255)
					SET @CustomMessage='Create Snapshot error on ' + @Database_Name
					EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
				END CATCH
				--==========Enf of creating Snapshot
				FETCH NEXT FROM @myCursor INTO @Database_Name
			END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_create_snapshot', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_create_snapshot', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_create_snapshot', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_create_snapshot', NULL, NULL
GO
