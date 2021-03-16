SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Siavash Golchoobian>
-- Create date: <6/10/2017>
-- Version:		<3.0.0.1>
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
	SET @Database_Name=DB_NAME()
	SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
	SET @mySQLScript=@mySQLScript+
		CAST(
		@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
		@myNewLine+	N'IF OBJECT_ID('''+@SchemaName+N'.'+@TableName+''') IS NULL'+
		@myNewLine+	N'BEGIN'+
		@myNewLine+	N'	RAISERROR (''Specified table object not exists.'',11,1)'+
		@myNewLine+	N'	RETURN'+
		@myNewLine+	N'END'+
		@myNewLine+	N''+
		@myNewLine+	N'CREATE TABLE #DropConstarint (ID int IDENTITY, SQLStatement nvarchar(max), SchemaName sysname, TableName sysname, FkName sysname, DependencyLevel int);'+
		@myNewLine+	N';With myDropConstraints AS ('+
		@myNewLine+	N'	SELECT'+
		@myNewLine+	N'		''IF EXISTS(SELECT 1 FROM [sys].[foreign_keys] AS myFkeys INNER JOIN [sys].[tables] AS myChildTables ON [myFkeys].[parent_object_id]=[myChildTables].[object_id] INNER JOIN [sys].[schemas] AS myChildSchemas ON [myChildTables].[schema_id]=[myChildSchemas].[schema_id] WHERE [myChildSchemas].[Name]=''''''+ myChildSchemas.name +'''''' AND [myChildTables].[Name]= ''''''+myChildTables.name+'''''' AND [myFkeys].[name]=''''''+myFkeys.name+'''''')''+ '+
		@myNewLine+	N'		''ALTER TABLE '' + QUOTENAME(myChildSchemas.name) + ''.'' + QUOTENAME(myChildTables.name) + '' DROP CONSTRAINT '' + QUOTENAME(myFkeys.name) AS SQLStatement,'+
		@myNewLine+	N'		myChildSchemas.name AS SchemaName,'+
		@myNewLine+	N'		myChildTables.name AS TableName,'+
		@myNewLine+	N'		myFkeys.name AS FkName,'+
		@myNewLine+	N'		1 AS DependencyLevel'+
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
		@myNewLine+	N'		AND [myParentTables].[Name]=''' + @TableName + ''''+
		@myNewLine+	N'	UNION ALL'+
		@myNewLine+	N'	SELECT'+
		@myNewLine+	N'		''IF EXISTS(SELECT 1 FROM [sys].[foreign_keys] AS myFkeys INNER JOIN [sys].[tables] AS myChildTables ON [myFkeys].[parent_object_id]=[myChildTables].[object_id] INNER JOIN [sys].[schemas] AS myChildSchemas ON [myChildTables].[schema_id]=[myChildSchemas].[schema_id] WHERE [myChildSchemas].[Name]=''''''+ myChildSchemas.name +'''''' AND [myChildTables].[Name]= ''''''+myChildTables.name+'''''' AND [myFkeys].[name]=''''''+myFkeys.name+'''''')''+ '+
		@myNewLine+	N'		''ALTER TABLE '' + QUOTENAME(myChildSchemas.name) + ''.'' + QUOTENAME(myChildTables.name) + '' DROP CONSTRAINT '' + QUOTENAME(myFkeys.name) AS SQLStatement,'+
		@myNewLine+	N'		myChildSchemas.name AS SchemaName,'+
		@myNewLine+	N'		myChildTables.name AS TableName,'+
		@myNewLine+	N'		myFkeys.name AS FkName,'+
		@myNewLine+	N'		myDropConstraints.DependencyLevel+1 AS DependencyLevel'+
		@myNewLine+	N'	FROM'+
		@myNewLine+	N'		sys.foreign_keys AS myFkeys '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myChildTables ON myFkeys.parent_object_id=myChildTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myChildSchemas ON myChildTables.schema_id=myChildSchemas.schema_id '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myParentTables ON myFkeys.referenced_object_id=myParentTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myParentSchemas ON myParentTables.schema_id=myParentSchemas.schema_id '+
		@myNewLine+	N'		INNER JOIN myDropConstraints ON myDropConstraints.SchemaName=[myParentSchemas].[Name] AND myDropConstraints.TableName=[myParentTables].[Name]'+
		@myNewLine+	N'	WHERE '+
		@myNewLine+	N'		[myParentTables].[is_ms_shipped]=0'+
		@myNewLine+	N'		AND [myFkeys].[referenced_object_id] != [myFkeys].[parent_object_id]'+
		@myNewLine+	N')'+
		@myNewLine+	N'INSERT INTO #DropConstarint (SQLStatement,SchemaName,TableName,FkName,DependencyLevel)'+
		@myNewLine+	N'SELECT SQLStatement,SchemaName,TableName,FkName,DependencyLevel FROM myDropConstraints'
		AS NVARCHAR(MAX))

	SET @mySQLScript=@mySQLScript+
		CAST(
		@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
		@myNewLine+	N'CREATE TABLE #TruncateTable (ID int IDENTITY, SQLStatement nvarchar(max), SchemaName sysname, TableName sysname, DependencyLevel int);'+
		@myNewLine+	N';With myTruncateTable AS ('+
		@myNewLine+	N'	SELECT'+
		@myNewLine+	N'		''IF EXISTS (SELECT 1 FROM '' + QUOTENAME(mySchemas.name) + ''.'' + QUOTENAME(myTables.name) + '') ''+ '+
		@myNewLine+	N'		''TRUNCATE TABLE '' + QUOTENAME(mySchemas.name) + ''.'' + QUOTENAME(myTables.name) AS SQLStatement, '+
		@myNewLine+	N'		mySchemas.name AS SchemaName,'+
		@myNewLine+	N'		myTables.name AS TableName,'+
		@myNewLine+	N'		1 AS DependencyLevel'+
		@myNewLine+	N'	FROM'+
		@myNewLine+	N'		sys.TABLES AS myTables '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS mySchemas ON myTables.schema_id=mySchemas.schema_id '+
		@myNewLine+	N'	WHERE '+
		@myNewLine+	N'		[myTables].is_ms_shipped=0'+
		@myNewLine+	N'		AND [mySchemas].[name]='''+@SchemaName+''''+
		@myNewLine+	N'		AND [myTables].[name]='''+@TableName+''''+
		@myNewLine+	N'	UNION ALL'+
		@myNewLine+	N'	SELECT /*DISTINCT*/'+
		@myNewLine+	N'		''IF EXISTS (SELECT 1 FROM '' + QUOTENAME(myBaseSchemas.name) + ''.'' + QUOTENAME(myBaseTables.name) + '') ''+ '+
		@myNewLine+	N'		''TRUNCATE TABLE '' + QUOTENAME(myBaseSchemas.name) + ''.'' + QUOTENAME(myBaseTables.name) AS SQLStatement, '+
		@myNewLine+	N'		myBaseSchemas.name AS SchemaName,'+
		@myNewLine+	N'		myBaseTables.name AS TableName,'+
		@myNewLine+	N'		myTruncateTable.DependencyLevel+1 AS DependencyLevel'+
		@myNewLine+	N'	FROM'+
		@myNewLine+	N'		sys.foreign_keys AS myFkeys '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myBaseTables ON myFkeys.parent_object_id=myBaseTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myBaseSchemas ON myBaseTables.schema_id=myBaseSchemas.schema_id '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myRefTables ON myFkeys.referenced_object_id=myRefTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myRefSchemas ON myRefTables.schema_id=myRefSchemas.schema_id '+
		@myNewLine+	N'		INNER JOIN myTruncateTable ON myTruncateTable.SchemaName=[myRefSchemas].[Name] AND myTruncateTable.TableName=[myRefTables].[Name] '+
		@myNewLine+	N'	WHERE '+
		@myNewLine+	N'		[myRefTables].[is_ms_shipped]=0'+
		@myNewLine+	N'		AND [myFkeys].[referenced_object_id] != [myFkeys].[parent_object_id]'+
		@myNewLine+	N')'+
		@myNewLine+	N'INSERT INTO #TruncateTable (SQLStatement,SchemaName,TableName,DependencyLevel)'+
		@myNewLine+	N'SELECT SQLStatement,SchemaName,TableName,DependencyLevel FROM myTruncateTable'
		AS NVARCHAR(MAX))
			
	SET @mySQLScript=@mySQLScript+
		CAST(
		@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
		@myNewLine+	N'CREATE TABLE #CreateConstarint (ID int IDENTITY, SQLStatement nvarchar(max), SchemaName sysname, TableName sysname, FkName sysname, DependencyLevel int);'+
		@myNewLine+	N';With myCreateConstarint AS ('+
		@myNewLine+	N'	SELECT'+
		@myNewLine+	N'		''IF NOT EXISTS(SELECT 1 FROM [sys].[foreign_keys] AS myFkeys INNER JOIN [sys].[tables] AS myChildTables ON [myFkeys].[parent_object_id]=[myChildTables].[object_id] INNER JOIN [sys].[schemas] AS myChildSchemas ON [myChildTables].[schema_id]=[myChildSchemas].[schema_id] WHERE [myChildSchemas].[Name]=''''''+ myBaseSchemas.name +'''''' AND [myChildTables].[Name]= ''''''+myBaseTables.name+'''''' AND [myFkeys].[name]=''''''+myFk.name+'''''')''+ '+
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
		@myNewLine+	N'		 ''	ON UPDATE '' + REPLACE(myFk.update_referential_action_desc , ''_'', '' '') COLLATE database_default AS SQLStatement,'+
		@myNewLine+	N'		myBaseSchemas.name AS SchemaName,'+
		@myNewLine+	N'		myBaseTables.name AS TableName,'+
		@myNewLine+	N'		myFk.name AS FkName,'+
		@myNewLine+	N'		1 AS DependencyLevel'+
		@myNewLine+	N'	FROM'+
		@myNewLine+	N'		sys.foreign_keys AS myFk '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myBaseTables ON myFk.parent_object_id=myBaseTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myBaseSchemas ON myBaseTables.schema_id=myBaseSchemas.schema_id '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myRefTables ON myFk.referenced_object_id=myRefTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myRefSchemas ON myRefTables.schema_id=myRefSchemas.schema_id '+
		@myNewLine+	N'	WHERE '+
		@myNewLine+	N'		myRefTables.is_ms_shipped=0'+
		@myNewLine+	N'		AND [myRefSchemas].[Name]=''' + @SchemaName + ''''+
		@myNewLine+	N'		AND [myRefTables].[Name]=''' + @TableName + ''''+
		@myNewLine+	N'	UNION ALL'+
		@myNewLine+	N'	SELECT'+
		@myNewLine+	N'		''IF NOT EXISTS(SELECT 1 FROM [sys].[foreign_keys] AS myFkeys INNER JOIN [sys].[tables] AS myChildTables ON [myFkeys].[parent_object_id]=[myChildTables].[object_id] INNER JOIN [sys].[schemas] AS myChildSchemas ON [myChildTables].[schema_id]=[myChildSchemas].[schema_id] WHERE [myChildSchemas].[Name]=''''''+ myBaseSchemas.name +'''''' AND [myChildTables].[Name]= ''''''+myBaseTables.name+'''''' AND [myFkeys].[name]=''''''+myFk.name+'''''')''+ '+
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
		@myNewLine+	N'		 ''	ON UPDATE '' + REPLACE(myFk.update_referential_action_desc , ''_'', '' '') COLLATE database_default AS SQLStatement,'+
		@myNewLine+	N'		myBaseSchemas.name AS SchemaName,'+
		@myNewLine+	N'		myBaseTables.name AS TableName,'+
		@myNewLine+	N'		myFk.name AS FkName,'+
		@myNewLine+	N'		myCreateConstarint.DependencyLevel+1 AS DependencyLevel'+
		@myNewLine+	N'	FROM'+
		@myNewLine+	N'		sys.foreign_keys AS myFk '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myBaseTables ON myFk.parent_object_id=myBaseTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myBaseSchemas ON myBaseTables.schema_id=myBaseSchemas.schema_id '+
		@myNewLine+	N'		INNER JOIN sys.TABLES AS myRefTables ON myFk.referenced_object_id=myRefTables.object_id '+
		@myNewLine+	N'		INNER JOIN sys.schemas AS myRefSchemas ON myRefTables.schema_id=myRefSchemas.schema_id '+
		@myNewLine+	N'		INNER JOIN myCreateConstarint ON myCreateConstarint.SchemaName=[myRefSchemas].[Name] AND myCreateConstarint.TableName=[myRefTables].[Name] '+
		@myNewLine+	N'	WHERE '+
		@myNewLine+	N'		myRefTables.is_ms_shipped=0'+
		@myNewLine+	N')'+
		@myNewLine+	N'INSERT INTO #CreateConstarint (SQLStatement,SchemaName,TableName,FkName,DependencyLevel)'+
		@myNewLine+	N'SELECT SQLStatement,SchemaName,TableName,FkName,DependencyLevel FROM myCreateConstarint'
		AS NVARCHAR(MAX))

	SET @mySQLScript=@mySQLScript+
		CAST(
		CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'/*' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Comment execution
		@myNewLine+ N'DECLARE @mySQLStatement NVARCHAR(max);'+
		@myNewLine+ N'DECLARE @myCursor_DC Cursor;'+
		@myNewLine+ N'DECLARE @myCursor_TT Cursor;'+
		@myNewLine+ N'DECLARE @myCursor_CC Cursor;'+
		@myNewLine+ N'DECLARE @myDeadlockretries INT;'+
		@myNewLine+ N'DECLARE @myDeadlockWait nvarchar(8);'+
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
		@myNewLine+ N'			SET @myDeadlockretries = 5'+
		@myNewLine+ N'			WHILE (@myDeadlockretries > 0) '+
		@myNewLine+ N'			BEGIN'+
		@myNewLine+ N'				BEGIN TRY'+
		@myNewLine+ N'					PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + @mySQLStatement;'+
		@myNewLine+ N'					EXEC (@mySQLStatement);'+
		@myNewLine+ N'					SET @myDeadlockretries = 0'+
		@myNewLine+ N'				END TRY'+
		@myNewLine+ N'				BEGIN CATCH'+
		@myNewLine+ N'					IF (ERROR_NUMBER() = 1205) -- its a deadlock exception - 1205'+
		@myNewLine+ N'					BEGIN'+
		@myNewLine+ N'						Print ''Deadlock occured - retrying ...'''+
		@myNewLine+ N'						SET @myDeadlockretries = @myDeadlockretries - 1 '+
		@myNewLine+ N'						SET @myDeadlockWait = ''00:00:''+CAST(FLOOR(RAND()*(20-2+1))+2 AS NVARCHAR(8));'+
		@myNewLine+ N'						WAITFOR DELAY @myDeadlockWait	-- Wait for 1 ms'+
		@myNewLine+ N'					END'+
		@myNewLine+ N'					ELSE'+
		@myNewLine+ N'					BEGIN'+
		@myNewLine+ N'						SET @CustomMessage1=''Drop Constraint error on '+@Database_Name+N'''' +
		@myNewLine+ N'						EXECUTE [SqlDeep].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
		@myNewLine+ N'						SET @myDeadlockretries = 0'+
		@myNewLine+ N'					END'+
		@myNewLine+ N'				END CATCH'+
		@myNewLine+ N'			END'+
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
		@myNewLine+	N'	SELECT SQLStatement FROM #TruncateTable ORDER BY DependencyLevel DESC, ID;'+
		@myNewLine+ N''+
		@myNewLine+ N'PRINT ''------------- Truncate Tables'';' +
		@myNewLine+ N'Open @myCursor_TT'+
		@myNewLine+ N'	FETCH NEXT FROM @myCursor_TT INTO @mySQLStatement'+
		@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
		@myNewLine+ N'		BEGIN'+
		@myNewLine+ N'			SET @myDeadlockretries = 5'+
		@myNewLine+ N'			WHILE (@myDeadlockretries > 0) '+
		@myNewLine+ N'			BEGIN'+
		@myNewLine+ N'				BEGIN TRY'+
		@myNewLine+ N'					PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + @mySQLStatement;'+
		@myNewLine+ N'					EXEC (@mySQLStatement);'+
		@myNewLine+ N'					SET @myDeadlockretries = 0'+
		@myNewLine+ N'				END TRY'+
		@myNewLine+ N'				BEGIN CATCH'+
		@myNewLine+ N'					IF (ERROR_NUMBER() = 1205) -- its a deadlock exception - 1205'+
		@myNewLine+ N'					BEGIN'+
		@myNewLine+ N'						Print ''Deadlock occured - retrying ...'''+
		@myNewLine+ N'						SET @myDeadlockretries = @myDeadlockretries - 1 '+
		@myNewLine+ N'						SET @myDeadlockWait = ''00:00:''+CAST(FLOOR(RAND()*(20-2+1))+2 AS NVARCHAR(8));'+
		@myNewLine+ N'						WAITFOR DELAY @myDeadlockWait	-- Wait for 1 ms'+
		@myNewLine+ N'					END'+
		@myNewLine+ N'					ELSE'+
		@myNewLine+ N'					BEGIN'+
		@myNewLine+ N'						SET @CustomMessage1=''Truncate Table error on '+@Database_Name+N'''' +
		@myNewLine+ N'						EXECUTE [SqlDeep].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
		@myNewLine+ N'						SET @myDeadlockretries = 0'+
		@myNewLine+ N'					END'+
		@myNewLine+ N'				END CATCH'+
		@myNewLine+ N'			END'+
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
		@myNewLine+ N'			SET @myDeadlockretries = 5'+
		@myNewLine+ N'			WHILE (@myDeadlockretries > 0) '+
		@myNewLine+ N'			BEGIN'+
		@myNewLine+ N'				BEGIN TRY'+
		@myNewLine+ N'					PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + @mySQLStatement;'+
		@myNewLine+ N'					EXEC (@mySQLStatement);'+
		@myNewLine+ N'					SET @myDeadlockretries = 0'+
		@myNewLine+ N'				END TRY'+
		@myNewLine+ N'				BEGIN CATCH'+
		@myNewLine+ N'					IF (ERROR_NUMBER() = 1205) -- its a deadlock exception - 1205'+
		@myNewLine+ N'					BEGIN'+
		@myNewLine+ N'						Print ''Deadlock occured - retrying ...'''+
		@myNewLine+ N'						SET @myDeadlockretries = @myDeadlockretries - 1 '+
		@myNewLine+ N'						SET @myDeadlockWait = ''00:00:''+CAST(FLOOR(RAND()*(20-2+1))+2 AS NVARCHAR(8));'+
		@myNewLine+ N'						WAITFOR DELAY @myDeadlockWait	-- Wait for 1 ms'+
		@myNewLine+ N'					END'+
		@myNewLine+ N'					ELSE'+
		@myNewLine+ N'					BEGIN'+
		@myNewLine+ N'						SET @CustomMessage1=''Create Constraint error on '+@Database_Name+N'''' +
		@myNewLine+ N'						EXECUTE [SqlDeep].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
		@myNewLine+ N'						SET @myDeadlockretries = 0'+
		@myNewLine+ N'					END'+
		@myNewLine+ N'				END CATCH'+
		@myNewLine+ N'			END'+
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
									@myNewLine+N'SELECT NULL AS [Id],''------------- Drop Constraints'' AS [Command], NULL AS [SchemaName], NULL AS [TableName], NULL  AS [FkName], NULL AS [DependencyLevel] UNION ALL ' +
									@myNewLine+N'SELECT ID,SQLStatement,SchemaName,TableName,FkName,DependencyLevel FROM #DropConstarint UNION ALL ' +
									@myNewLine+N'SELECT NULL,''------------- Truncate Tables'',NULL,NULL,NULL,NULL UNION ALL ' +
									@myNewLine+N'SELECT ID,SQLStatement,SchemaName,TableName,NULL,DependencyLevel FROM #TruncateTable UNION ALL ' +
									@myNewLine+N'SELECT NULL,''------------- ReCreate Constraints'',NULL,NULL,NULL,NULL UNION ALL ' +
									@myNewLine+N'SELECT ID,SQLStatement,SchemaName,TableName,FkName,DependencyLevel FROM #CreateConstarint;'
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
