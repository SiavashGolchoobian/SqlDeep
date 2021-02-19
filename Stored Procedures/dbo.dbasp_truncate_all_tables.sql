SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<niikola (http://blogs.lessthandot.com/index.php/datamgmt/dbprogramming/mssqlserver/delete-all-data-in-database-when-you-hav/) + Golchoobian>
-- Create date: <6/10/2017>
-- Version:		<3.0.0.0>
-- Description:	<Truncate All table(s) data also if having foreign key constraints>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@PrintOnly:		0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_truncate_all_tables]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@PrintOnly BIT=0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @Database_ID INT;
	DECLARE @Database_IsReadOnly bit;
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);
	
	SET @myNewLine=CHAR(13)+CHAR(10)
    SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
		
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
	WHILE @@FETCH_STATUS=0
	BEGIN
		SELECT @Database_ID=database_id,@Database_IsReadOnly=CAST(is_read_only as bit) from sys.databases where name=@Database_Name
		SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
			@myNewLine+	N'CREATE TABLE #DropConstarint (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #DropConstarint (SQLStatement)'+
			@myNewLine+	N'	SELECT'+
			@myNewLine+	N'		''ALTER TABLE '' + QUOTENAME(mySchemas.name) + ''.'' + QUOTENAME(myTables.name) + '' DROP CONSTRAINT '' + QUOTENAME(myFkeys.name) '+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.foreign_keys AS myFkeys '+
			@myNewLine+	N'		INNER JOIN sys.TABLES AS myTables ON myFkeys.parent_object_id=myTables.object_id '+
			@myNewLine+	N'		INNER JOIN sys.schemas AS mySchemas ON myTables.schema_id=mySchemas.schema_id '+
			@myNewLine+	N'	WHERE '+
			@myNewLine+	N'		myTables.is_ms_shipped=0'
			AS NVARCHAR(MAX))

		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
			@myNewLine+	N'CREATE TABLE #TruncateTable (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #TruncateTable (SQLStatement)'+
			@myNewLine+	N'	SELECT'+
			@myNewLine+	N'		''TRUNCATE TABLE '' + QUOTENAME(mySchemas.name) + ''.'' + QUOTENAME(myTables.name) '+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.TABLES AS myTables '+
			@myNewLine+	N'		INNER JOIN sys.schemas AS mySchemas ON myTables.schema_id=mySchemas.schema_id '+
			@myNewLine+	N'	WHERE '+
			@myNewLine+	N'		[myTables].is_ms_shipped=0'
			AS NVARCHAR(MAX))

		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
			@myNewLine+	N'CREATE TABLE #CreateConstarint (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #CreateConstarint (SQLStatement)'+
			@myNewLine+	N'	SELECT'+
			@myNewLine+	N'		''ALTER TABLE '' + QUOTENAME(mySchemas.name) + ''.'' + QUOTENAME(myTables.name) + '+
			@myNewLine+	N'		''	WITH '' + CASE [myFk].[is_not_trusted] WHEN 1 THEN N''NOCHECK'' ELSE N''CHECK'' END + '+
			@myNewLine+	N'		''	ADD CONSTRAINT '' + QUOTENAME(myFk.name) + '+
			@myNewLine+	N'		''	FOREIGN KEY ('' + '+
			@myNewLine+	N'				Stuff( '+
			@myNewLine+	N'		 				(SELECT '', '' + QUOTENAME(COL_NAME(myFKC.parent_object_id, myFKC.parent_column_id)) '+
			@myNewLine+	N'		 				 FROM sys.foreign_key_columns AS myFKC '+
			@myNewLine+	N'		 				 WHERE myFKC.constraint_object_id = myFk.object_id '+
			@myNewLine+	N'		 				 ORDER BY myFKC.constraint_column_id '+
			@myNewLine+	N'		 				 FOR XML Path('''') '+
			@myNewLine+	N'		 				) '+
			@myNewLine+	N'		 				, 1,2,'''') + '+
			@myNewLine+	N'		 			   '')'' + '+
			@myNewLine+	N'		 ''	REFERENCES '' + QUOTENAME(object_schema_name(myFk.referenced_object_id)) + ''.'' + QUOTENAME(object_name(myFk.referenced_object_id)) + '' ('' + '+
			@myNewLine+	N'		 		STUFF( '+
			@myNewLine+	N'		 			(SELECT '', '' + QUOTENAME(COL_NAME(myFKC.referenced_object_id, myFKC.referenced_column_id)) '+
			@myNewLine+	N'		 			 FROM sys.foreign_key_columns AS myFKC'+
			@myNewLine+	N'		 			 WHERE myFKC.constraint_object_id = myFk.object_id '+
			@myNewLine+	N'		 			 ORDER BY myFKC.constraint_column_id '+
			@myNewLine+	N'		 			 FOR XML Path('''')), '+
			@myNewLine+	N'		 				1,2,'''') + '+
			@myNewLine+	N'		 			   '')'' + '+
			@myNewLine+	N'		 ''	ON DELETE '' + REPLACE(myFk.delete_referential_action_desc, ''_'', '' '')  + '+
			@myNewLine+	N'		 ''	ON UPDATE '' + REPLACE(myFk.update_referential_action_desc , ''_'', '' '') COLLATE database_default '+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.foreign_keys AS myFk '+
			@myNewLine+	N'		INNER JOIN sys.TABLES AS myTables ON myFk.parent_object_id=myTables.object_id '+
			@myNewLine+	N'		INNER JOIN sys.schemas AS mySchemas ON myTables.schema_id=mySchemas.schema_id '+
			@myNewLine+	N'	WHERE '+
			@myNewLine+	N'		myTables.is_ms_shipped=0'
			AS NVARCHAR(MAX))

		SET @mySQLScript=@mySQLScript+
			CAST(
			CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'/*' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Comment execution
			@myNewLine+ N'DECLARE @mySQLStatement NVARCHAR(max);'+
			@myNewLine+ N'DECLARE @myCursor_DC Cursor;'+
			@myNewLine+ N'DECLARE @myCursor_TT Cursor;'+
			@myNewLine+ N'DECLARE @myCursor_CC Cursor;'+
			@myNewLine+ N'DECLARE @CustomMessage1 nvarchar(255)'+
			@myNewLine+ N''+
			@myNewLine+ N'SET @myCursor_DC=CURSOR For'+
			@myNewLine+	N'	SELECT SQLStatement FROM #DropConstarint ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''Current database is '+ @Database_Name + N''';' +
			@myNewLine+ N'PRINT ''------------- Drop Constraints'';' +
			@myNewLine+ N'Open @myCursor_DC'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_DC INTO @mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + @mySQLStatement;'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage1=''Drop Constraint error on '+@Database_Name+N'''' +
			@myNewLine+ N'				EXECUTE ' + CAST(QUOTENAME(DB_NAME()) AS NVARCHAR(MAX)) + N'.[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_DC INTO @mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_DC; '+
			@myNewLine+ N'DEALLOCATE @myCursor_DC; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))

		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'SET @myCursor_TT=CURSOR For'+
			@myNewLine+	N'	SELECT SQLStatement FROM #TruncateTable ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''------------- Truncate Tables'';' +
			@myNewLine+ N'Open @myCursor_TT'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_TT INTO @mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + @mySQLStatement;'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage1=''Truncate Table error on '+@Database_Name+N'''' +
			@myNewLine+ N'				EXECUTE ' + CAST(QUOTENAME(DB_NAME()) AS NVARCHAR(MAX)) + '.[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_TT INTO @mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_TT; '+
			@myNewLine+ N'DEALLOCATE @myCursor_TT; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))

		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'SET @myCursor_CC=CURSOR For'+
			@myNewLine+	N'	SELECT SQLStatement FROM #CreateConstarint ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''------------- ReCreate Constraints'';' +
			@myNewLine+ N'Open @myCursor_CC'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_CC INTO @mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + @mySQLStatement;'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage1=''Create Constraint error on '+@Database_Name+N'''' +
			@myNewLine+ N'				EXECUTE ' + CAST(QUOTENAME(DB_NAME()) AS NVARCHAR(MAX)) + '.[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_CC INTO @mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_CC; '+
			@myNewLine+ N'DEALLOCATE @myCursor_CC; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))

		SET @mySQLScript=@mySQLScript+
			CAST(
			CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'*/' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Comment execution
			CAST(CASE WHEN @PrintOnly=1 THEN 
										@myNewLine+N'SELECT NULL,''------------- Drop Constraints'' UNION ALL ' +
										@myNewLine+N'SELECT ID,SQLStatement FROM #DropConstarint UNION ALL ' +
										@myNewLine+N'SELECT NULL,''------------- Truncate Tables'' UNION ALL ' +
										@myNewLine+N'SELECT ID,SQLStatement FROM #TruncateTable UNION ALL ' +
										@myNewLine+N'SELECT NULL,''------------- ReCreate Constraints'' UNION ALL ' +
										@myNewLine+N'SELECT ID,SQLStatement FROM #CreateConstarint ;'
									ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Return commands list
			@myNewLine+	N'DROP TABLE #DropConstarint; '+
			@myNewLine+	N'DROP TABLE #TruncateTable; '+
			@myNewLine+	N'DROP TABLE #CreateConstarint; '
			AS NVARCHAR(MAX))

		EXEC [dbo].[dbasp_print_text] @mySQLScript		

		IF @PrintOnly=0
			PRINT (@myNewLine + '--Excexution Report--');

		IF @Database_IsReadOnly=0
		BEGIN
			--=======Start of executing commands
			BEGIN TRY
				EXECUTE (@mySQLScript);
			END TRY
			BEGIN CATCH
				DECLARE @CustomMessage1 NVARCHAR(255)
				SET @CustomMessage1='TruncateDb error on ' + @Database_Name
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
			END CATCH
			--=======End of executing commands
		END
		ELSE
		BEGIN
			PRINT (@myNewLine + @Database_Name + ' is read-only.');
		END
		FETCH NEXT FROM @myCursor INTO @Database_Name
	END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_all_tables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-06-10', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_all_tables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_all_tables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_all_tables', NULL, NULL
GO
