SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Siavash Golchoobian>
-- Create date: <6/10/2017>
-- Version:		<3.0.0.0>
-- Description:	<Truncate single table data also if referenced by other table, truncate that tables too>
-- Input Parameters:
--	@DatabaseName:	database name
--	@SchemaName:	table schema name
--	@TableName:		table name
--	@PrintOnly:		0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_truncate_single_table]
	@DatabaseName sysname,
	@SchemaName sysname,
	@TableName sysname,
	@PrintOnly BIT=0

AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);
	
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @Database_Name=@DatabaseName
	SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
	SET @mySQLScript=@mySQLScript+
		CAST(
		@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
		@myNewLine+	N'CREATE TABLE #DropConstarint (ID int IDENTITY, SQLStatement nvarchar(max));'+
		@myNewLine+	N'INSERT INTO #DropConstarint (SQLStatement)'+
		@myNewLine+	N'	SELECT'+
		@myNewLine+	N'		''ALTER TABLE '' + QUOTENAME(myChildSchemas.name) + ''.'' + QUOTENAME(myChildTables.name) + '' DROP CONSTRAINT '' + QUOTENAME(myFkeys.name) '+
		@myNewLine+	N'	FROM'+
		@myNewLine+	N'		sys.foreign_keys AS myFkeys '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myChildTables ON myFkeys.parent_object_id=myChildTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myChildSchemas ON myChildTables.schema_id=myChildSchemas.schema_id '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myParentTables ON myFkeys.referenced_object_id=myParentTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myParentSchemas ON myParentTables.schema_id=myParentSchemas.schema_id '+
		@myNewLine+	N'	WHERE '+
		@myNewLine+	N'		[myParentTables].[is_ms_shipped]=0'+
		@myNewLine+	N'		AND [myFkeys].[referenced_object_id] != [myFkeys].[parent_object_id]'+
		@myNewLine+	N'		AND [myParentSchemas].[Name]=''' + @SchemaName + ''''+
		@myNewLine+	N'		AND [myParentTables].[Name]=''' + @TableName + ''''
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
		@myNewLine+	N'		[myTables].is_ms_shipped=0'+
		@myNewLine+	N'		AND [mySchemas].[name]='''+@SchemaName+''''+
		@myNewLine+	N'		AND [myTables].[name]='''+@TableName+''''+
		@myNewLine+	N'	UNION'+
		@myNewLine+	N'	SELECT DISTINCT'+
		@myNewLine+	N'		''TRUNCATE TABLE '' + QUOTENAME(myBaseSchemas.name) + ''.'' + QUOTENAME(myBaseTables.name) '+
		@myNewLine+	N'	FROM'+
		@myNewLine+	N'		sys.foreign_keys AS myFkeys '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myBaseTables ON myFkeys.parent_object_id=myBaseTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myBaseSchemas ON myBaseTables.schema_id=myBaseSchemas.schema_id '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myRefTables ON myFkeys.referenced_object_id=myRefTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myRefSchemas ON myRefTables.schema_id=myRefSchemas.schema_id '+
		@myNewLine+	N'	WHERE '+
		@myNewLine+	N'		[myRefTables].[is_ms_shipped]=0'+
		@myNewLine+	N'		AND [myFkeys].[referenced_object_id] != [myFkeys].[parent_object_id]'+
		@myNewLine+	N'		AND [myRefSchemas].[Name]=''' + @SchemaName + ''''+
		@myNewLine+	N'		AND [myRefTables].[Name]=''' + @TableName + ''''
		AS NVARCHAR(MAX))
			
	SET @mySQLScript=@mySQLScript+
		CAST(
		@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
		@myNewLine+	N'CREATE TABLE #CreateConstarint (ID int IDENTITY, SQLStatement nvarchar(max));'+
		@myNewLine+	N'INSERT INTO #CreateConstarint (SQLStatement)'+
		@myNewLine+	N'	SELECT'+
		@myNewLine+	N'		''ALTER TABLE '' + QUOTENAME(myBaseSchemas.name) + ''.'' + QUOTENAME(myBaseTables.name) + '+
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
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myBaseTables ON myFk.parent_object_id=myBaseTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myBaseSchemas ON myBaseTables.schema_id=myBaseSchemas.schema_id '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myRefTables ON myFk.referenced_object_id=myRefTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myRefSchemas ON myRefTables.schema_id=myRefSchemas.schema_id '+
		@myNewLine+	N'	WHERE '+
		@myNewLine+	N'		myRefTables.is_ms_shipped=0'+
		@myNewLine+	N'		AND [myRefSchemas].[Name]=''' + @SchemaName + ''''+
		@myNewLine+	N'		AND [myRefTables].[Name]=''' + @TableName + ''''
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
		@myNewLine+ N'				EXECUTE [SqlDeep].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
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
		@myNewLine+ N'				EXECUTE [SqlDeep].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
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
		@myNewLine+ N'				EXECUTE [SqlDeep].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
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
									@myNewLine+N'SELECT NULL AS [Id],''------------- Drop Constraints'' AS [Command] UNION ALL ' +
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

	EXEC [SqlDeep].[dbo].[dbasp_print_text] @mySQLScript		

	IF @PrintOnly=0
		PRINT (@myNewLine + '--Excexution Report--');

	--=======Start of executing commands
	BEGIN TRY
		EXECUTE (@mySQLScript);
	END TRY
	BEGIN CATCH
		DECLARE @CustomMessage1 NVARCHAR(255)
		SET @CustomMessage1='TruncateDb error on ' + @Database_Name
		EXECUTE [SqlDeep].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
	END CATCH
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_single_table', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-06-10', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_single_table', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-02-28', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_single_table', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.1', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_single_table', NULL, NULL
GO
