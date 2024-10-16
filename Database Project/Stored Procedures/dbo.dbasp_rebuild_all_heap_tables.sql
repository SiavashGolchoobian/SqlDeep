SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/21/2015>
-- Version:		<3.0.0.0>
-- Description:	<Rebuild all heaped tables of databases>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@PrintOnly:		0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_rebuild_all_heap_tables]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@PrintOnly BIT=0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @Database_ID nvarchar(10);
	DECLARE @Database_IsReadOnly bit;
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);
	
	SET @myNewLine=CHAR(13)+CHAR(10)
    SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
		
	IF @PrintOnly=0	--Execute reindex
		BEGIN
			Open @myCursor
			FETCH NEXT FROM @myCursor INTO @Database_Name
			WHILE @@FETCH_STATUS=0
				BEGIN
					--SELECT @Database_ID= CAST(DB_ID(@Database_Name) as nvarchar(10))
					SELECT @Database_ID=CAST(database_id as nvarchar(10)), @Database_IsReadOnly=CAST(is_read_only as bit) from sys.databases where name=@Database_Name
					SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
					SET @mySQLScript=@mySQLScript+
					CAST(
					@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
					@myNewLine+ N'DECLARE @myCursor Cursor;'+
					@myNewLine+ N'DECLARE @mySQLStatement NVARCHAR(max);'+
					@myNewLine+ N''+
					@myNewLine+ N'SET @myCursor=CURSOR For'+
					@myNewLine+ N'	SELECT	SQLStatement='+
					@myNewLine+ N'				''PRINT ''''ALTER TABLE ['' + schema_name(myTable.schema_id) + ''].['' + OBJECT_NAME(myTable.object_id) + ''] REBUILD is Starting at '' + CAST(Getdate() as nvarchar(50)) + '''''';'''+
					@myNewLine+ N'				+''ALTER TABLE ['' + schema_name(myTable.schema_id) + ''].['' + OBJECT_NAME(myTable.object_id) + ''] REBUILD;'''+
					@myNewLine+ N'	FROM '+
					@myNewLine+ N'			sys.indexes  as myIndex'+
					@myNewLine+ N'			inner join sys.tables as myTable on myTable.object_id=myIndex.object_id'+
					@myNewLine+ N'	WHERE	myIndex.[type]=0 AND '+
					@myNewLine+ N'			myTable.[type]=''U'''+
					@myNewLine+ N' '+
					@myNewLine+ N'PRINT ''Current database is '+ @Database_Name + N''';' +
					@myNewLine+ N' '+
					@myNewLine+ N'Open @myCursor'+
					@myNewLine+ N'	FETCH NEXT FROM @myCursor INTO @mySQLStatement'+
					@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
					@myNewLine+ N'			BEGIN'+
					@myNewLine+ N'				BEGIN TRY'+
					@myNewLine+ N'					EXEC (@mySQLStatement);'+
					@myNewLine+ N'				END TRY'+
					@myNewLine+ N'				BEGIN CATCH'+
					@myNewLine+ N'					DECLARE @CustomMessage1 nvarchar(255)'+
					@myNewLine+ N'					SET @CustomMessage1=''Reindexing error on '+@Database_Name+N'''' +
					@myNewLine+ N'					EXECUTE ' + CAST(QUOTENAME(DB_NAME()) AS NVARCHAR(MAX)) + N'.[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
					--@myNewLine+ N'					Print '+
					--@myNewLine+ N'					''ErrorNumber: '' + ISNULL(CAST(ERROR_NUMBER() as nvarchar),'''') +'+
					--@myNewLine+ N'					''ErrorSeverity: '' + ISNULL(CAST(ERROR_SEVERITY() as nvarchar),'''') +'+
					--@myNewLine+ N'					''ErrorState: '' + ISNULL(CAST(ERROR_STATE() as nvarchar),'''') +'+
					--@myNewLine+ N'					''ErrorProcedure: '' + ISNULL(CAST(ERROR_PROCEDURE() as nvarchar),'''') +'+
					--@myNewLine+ N'					''ErrorLine: '' + ISNULL(CAST(ERROR_LINE() as nvarchar),'''') +'+
					--@myNewLine+ N'					''ErrorMessage: '' + ISNULL(CAST(ERROR_MESSAGE() as nvarchar),'''')'+
					@myNewLine+ N'				END CATCH'+
					@myNewLine+ N'				FETCH NEXT FROM @myCursor INTO @mySQLStatement'+
					@myNewLine+ N'			END '+
					@myNewLine+ N'CLOSE @myCursor; '+
					@myNewLine+ N'DEALLOCATE @myCursor; '
					AS NVARCHAR(MAX))

					EXEC [dbo].[dbasp_print_text] @mySQLScript;
					PRINT (@myNewLine + '--Excexution Report--');
					IF @Database_IsReadOnly=0
						BEGIN
							--==========Start of executing rebuild
							BEGIN TRY
								EXECUTE (@mySQLScript);
							END TRY
							BEGIN CATCH
								EXECUTE [dbo].[dbasp_get_error_info] 'Rebuild heap tables error',1,0,1,0,NULL
							END CATCH
							--==========End of executing rebuild
						END
						ELSE
						BEGIN
							PRINT (@Database_Name + ' is read-only.');
						END
					FETCH NEXT FROM @myCursor INTO @Database_Name
				END
			CLOSE @myCursor;
			DEALLOCATE @myCursor;
		END
	ELSE			--Only Print reindex commands
		BEGIN
			Open @myCursor
			FETCH NEXT FROM @myCursor INTO @Database_Name
			WHILE @@FETCH_STATUS=0
				BEGIN
					--SELECT @Database_ID= CAST(DB_ID(@Database_Name) as nvarchar(10))
					SELECT @Database_ID=CAST(database_id as nvarchar(10)), @Database_IsReadOnly=CAST(is_read_only as bit) from sys.databases where name=@Database_Name
					SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
					SET @mySQLScript=@mySQLScript+
					CAST(
					@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
					@myNewLine+ N'DECLARE @mySQLStatement NVARCHAR(max);'+
					@myNewLine+ N''+
					@myNewLine+ N'	SELECT	SQLStatement='+
					@myNewLine+ N'				''ALTER TABLE ['' + schema_name(myTable.schema_id) + ''].['' + OBJECT_NAME(myTable.object_id) + ''] REBUILD;'''+
					@myNewLine+ N'	FROM '+
					@myNewLine+ N'			sys.indexes  as myIndex'+
					@myNewLine+ N'			inner join sys.tables as myTable on myTable.object_id=myIndex.object_id'+
					@myNewLine+ N'	WHERE	myIndex.[type]=0 AND '+
					@myNewLine+ N'			myTable.[type]=''U'''
					AS NVARCHAR(MAX))

					EXEC [dbo].[dbasp_print_text] @mySQLScript;

					--==========Start of printing rebuild
					BEGIN TRY
						EXECUTE (@mySQLScript);
					END TRY
					BEGIN CATCH
						DECLARE @CustomMessage nvarchar(255)
						SET @CustomMessage='Rebuild heap tables error on ' + @Database_Name
						EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
					END CATCH
					--==========End of printing rebuild
					FETCH NEXT FROM @myCursor INTO @Database_Name
				END
			CLOSE @myCursor;
			DEALLOCATE @myCursor;
		END
END



GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rebuild_all_heap_tables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rebuild_all_heap_tables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rebuild_all_heap_tables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rebuild_all_heap_tables', NULL, NULL
GO
