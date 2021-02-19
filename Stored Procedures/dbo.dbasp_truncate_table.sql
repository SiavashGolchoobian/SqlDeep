SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Siavash Golchoobian>
-- Create date: <6/10/2017>
-- Version:		<3.0.0.0>
-- Description:	<Truncate single table data also if having foreign key constraints>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@SchemaName:	table schema name
--	@TableName:		table name
--	@PrintOnly:		0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_truncate_table]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@SchemaName sysname,
	@TableName sysname,
	@PrintOnly BIT=0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);
	
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
		
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
	WHILE @@Fetch_Status=0
	BEGIN
		SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'DECLARE @mySchemaName sysname'+
			@myNewLine+ N'DECLARE @myTableName sysname'+
			@myNewLine+ N''+
			@myNewLine+ N'CREATE TABLE #DropConstarint (ID int IDENTITY, SQLStatement nvarchar(max), FkObjectId INT, ParentObjectId INT, ChildObjectId INT, ParentObjectName NVARCHAR(255), ChildObjectName NVARCHAR(255));'+
			@myNewLine+ N'CREATE TABLE #TruncateTable (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+ N'CREATE TABLE #CreateConstarint (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+ N''+
			@myNewLine+ N'SET @mySchemaName='''+@SchemaName+''''+
			@myNewLine+ N'SET @myTableName='''+@TableName+''''+
			@myNewLine+ N''+
			@myNewLine+ N'--===============STEP 1'+
			@myNewLine+ N';WITH myRelatedTables AS ('+
			@myNewLine+ N'	SELECT'+
			@myNewLine+ N'		''ALTER TABLE '' + QUOTENAME('''+@Database_Name+''') + ''.'' + QUOTENAME([myChildSchema].[name]) + ''.'' + QUOTENAME([myChildTable].[name]) + '' DROP CONSTRAINT '' + QUOTENAME([myFK].[name]) AS DropConstraintStatement,'+
			@myNewLine+ N'		[myFK].[object_id] AS FkObjectId,'+
			@myNewLine+ N'		[myParentTable].[object_id] AS ParentObjectId,'+
			@myNewLine+ N'		[myChildTable].[object_id] AS ChildObjectId,'+
			@myNewLine+ N'		QUOTENAME([myParentSchema].[name]) + ''.'' + QUOTENAME([myParentTable].[name]) AS ParentObjectName,'+
			@myNewLine+ N'		QUOTENAME([myChildSchema].[name]) + ''.'' + QUOTENAME([myChildTable].[name]) AS ChildObjectName'+
			@myNewLine+ N'	FROM'+
			@myNewLine+ N'		['+@Database_Name+'].[sys].[tables] AS myParentTable'+
			@myNewLine+ N'		INNER JOIN ['+@Database_Name+'].[sys].[schemas] AS myParentSchema ON [myParentTable].[schema_id]=[myParentSchema].[schema_id]'+
			@myNewLine+ N'		INNER JOIN ['+@Database_Name+'].[sys].[foreign_keys] AS myFK ON [myFK].[referenced_object_id]=[myParentTable].[object_id]'+
			@myNewLine+ N'		INNER JOIN ['+@Database_Name+'].[sys].[tables] AS myChildTable ON [myFK].[parent_object_id]=[myChildTable].[object_id]'+
			@myNewLine+ N'		INNER JOIN ['+@Database_Name+'].[sys].[schemas] AS myChildSchema ON [myChildTable].[schema_id]=[myChildSchema].[schema_id]'+
			@myNewLine+ N'	WHERE'+
			@myNewLine+ N'		[myParentSchema].[name]=@mySchemaName'+
			@myNewLine+ N'		AND [myParentTable].[name]=@myTableName'+
			@myNewLine+ N'		AND [myParentTable].[is_ms_shipped]=0'+
			@myNewLine+ N'		AND [myFK].[referenced_object_id] <> [myFK].[parent_object_id]'+
			@myNewLine+ N'	UNION ALL'+
			@myNewLine+ N'	SELECT'+
			@myNewLine+ N'		''ALTER TABLE '' + QUOTENAME('''+@Database_Name+''') + ''.'' + QUOTENAME([myChildSchema].[name]) + ''.'' + QUOTENAME([myChildTable].[name]) + '' DROP CONSTRAINT '' + QUOTENAME([myFK].[name]) AS DropConstraintStatement,'+
			@myNewLine+ N'		[myFK].[object_id] AS FkObjectId,'+
			@myNewLine+ N'		[myParentTable].[object_id] AS ParentObjectId,'+
			@myNewLine+ N'		[myChildTable].[object_id] AS ChildObjectId,'+
			@myNewLine+ N'		QUOTENAME([myParentSchema].[name]) + ''.'' + QUOTENAME([myParentTable].[name]) AS ParentObjectName,'+
			@myNewLine+ N'		QUOTENAME([myChildSchema].[name]) + ''.'' + QUOTENAME([myChildTable].[name]) AS ChildObjectName'+
			@myNewLine+ N'	FROM'+
			@myNewLine+ N'		[myRelatedTables]'+
			@myNewLine+ N'		INNER JOIN ['+@Database_Name+'].[sys].[tables] AS myParentTable ON [myRelatedTables].[ChildObjectId]=[myParentTable].[object_id]'+
			@myNewLine+ N'		INNER JOIN ['+@Database_Name+'].[sys].[schemas] AS myParentSchema ON [myParentTable].[schema_id]=[myParentSchema].[schema_id]'+
			@myNewLine+ N'		INNER JOIN ['+@Database_Name+'].[sys].[foreign_keys] AS myFK ON [myFK].[referenced_object_id]=[myParentTable].[object_id]'+
			@myNewLine+ N'		INNER JOIN ['+@Database_Name+'].[sys].[tables] AS myChildTable ON [myFK].[parent_object_id]=[myChildTable].[object_id]'+
			@myNewLine+ N'		INNER JOIN ['+@Database_Name+'].[sys].[schemas] AS myChildSchema ON [myChildTable].[schema_id]=[myChildSchema].[schema_id]'+
			@myNewLine+ N'	WHERE'+
			@myNewLine+ N'		[myParentTable].[is_ms_shipped]=0'+
			@myNewLine+ N'		AND [myFK].[referenced_object_id] <> [myFK].[parent_object_id]'+
			@myNewLine+ N')'+
			@myNewLine+ N''+
			@myNewLine+ N'INSERT INTO #DropConstarint ([SQLStatement],[FkObjectId],[ParentObjectId],[ChildObjectId],[ParentObjectName],[ChildObjectName])'+
			@myNewLine+ N'SELECT [myRelatedTables].[DropConstraintStatement],[myRelatedTables].[FkObjectId],[myRelatedTables].[ParentObjectId],[myRelatedTables].[ChildObjectId],[myRelatedTables].[ParentObjectName],[myRelatedTables].[ChildObjectName] FROM [myRelatedTables]'+
			@myNewLine+ N''+
			@myNewLine+ N''
			AS NVARCHAR(MAX))

		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--===============STEP 2'+
			@myNewLine+ N'INSERT INTO [#TruncateTable] ([SQLStatement])'+
			@myNewLine+ N'SELECT'+
			@myNewLine+ N'	''TRUNCATE TABLE '' + QUOTENAME('''+@Database_Name+''') + ''.'' + [ChildObjectName]'+
			@myNewLine+ N'FROM'+
			@myNewLine+ N'	#DropConstarint'+
			@myNewLine+ N'UNION'+
			@myNewLine+ N'SELECT'+
			@myNewLine+ N'	''TRUNCATE TABLE '' + QUOTENAME('''+@Database_Name+''') + ''.'' + [ParentObjectName]'+
			@myNewLine+ N'FROM'+
			@myNewLine+ N'	#DropConstarint'+
			@myNewLine+ N''
			AS NVARCHAR(MAX))

		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--===============STEP 3'+
			@myNewLine+ N'INSERT INTO #CreateConstarint (SQLStatement)'+
			@myNewLine+ N'SELECT'+
			@myNewLine+ N'	''ALTER TABLE '' + QUOTENAME('''+@Database_Name+''') + ''.'' + [myDroppedFK].[ChildObjectName] + '+
			@myNewLine+ N'	''	WITH '' + CASE [myFk].[is_not_trusted] WHEN 1 THEN N''NOCHECK'' ELSE N''CHECK'' END + '+
			@myNewLine+ N'	''	ADD CONSTRAINT '' + QUOTENAME([myFk].[name]) + '+
			@myNewLine+ N'	''	FOREIGN KEY ('' + '+
			@myNewLine+ N'			Stuff( '+
			@myNewLine+ N' 					(SELECT '', '' + QUOTENAME([myCols].[name]) '+
			@myNewLine+ N' 						FROM ['+@Database_Name+'].[sys].[foreign_key_columns] AS myFKC INNER JOIN	['+@Database_Name+'].[sys].[columns] AS myCols ON [myCols].[object_id]=[myFKC].[parent_object_id] AND [myCols].[column_id]=[myFKC].[parent_column_id]'+
			@myNewLine+ N' 						WHERE [myFKC].[constraint_object_id] = [myFk].[object_id]'+
			@myNewLine+ N' 						ORDER BY [myFKC].[constraint_column_id] '+
			@myNewLine+ N' 						FOR XML Path('''') '+
			@myNewLine+ N' 					) '+
			@myNewLine+ N' 					, 1,2,'''') + '+
			@myNewLine+ N' 					'')'' + '+
			@myNewLine+ N'		''	REFERENCES '' + [myDroppedFK].[ParentObjectName] + '' ('' + '+
			@myNewLine+ N' 			STUFF( '+
			@myNewLine+ N' 				(SELECT '', '' + QUOTENAME([myCols].[name]) '+
			@myNewLine+ N' 					FROM ['+@Database_Name+'].[sys].[foreign_key_columns] AS myFKC INNER JOIN ['+@Database_Name+'].[sys].[columns] AS myCols ON [myCols].[object_id]=[myFKC].[referenced_object_id] AND [myCols].[column_id]=[myFKC].[referenced_column_id]'+
			@myNewLine+ N' 					WHERE [myFKC].[constraint_object_id] = [myFk].[object_id] '+
			@myNewLine+ N' 					ORDER BY [myFKC].[constraint_column_id] '+
			@myNewLine+ N' 					FOR XML Path('''')), '+
			@myNewLine+ N' 					1,2,'''') + '+
			@myNewLine+ N' 					'')'' + '+
			@myNewLine+ N'		''	ON DELETE '' + REPLACE([myFk].[delete_referential_action_desc], ''_'', '' '')  + '+
			@myNewLine+ N'		''	ON UPDATE '' + REPLACE([myFk].[update_referential_action_desc] , ''_'', '' '') COLLATE database_default '+
			@myNewLine+ N'FROM'+
			@myNewLine+ N'	['+@Database_Name+'].[sys].[foreign_keys] AS myFk '+
			@myNewLine+ N'	INNER JOIN [#DropConstarint] AS myDroppedFK ON [myFk].[object_id]=[myDroppedFK].[FkObjectId]'+
			@myNewLine+ N''
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
			@myNewLine+ N'				EXECUTE [DBA].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
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
			@myNewLine+ N'				EXECUTE [DBA].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
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
			@myNewLine+ N'				EXECUTE [DBA].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
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

		EXEC [DBA].[dbo].[dbasp_print_text] @mySQLScript		

		IF @PrintOnly=0
			PRINT (@myNewLine + '--Excexution Report--');

		--=======Start of executing commands
		BEGIN TRY
			EXECUTE (@mySQLScript);
		END TRY
		BEGIN CATCH
			DECLARE @CustomMessage1 NVARCHAR(255)
			SET @CustomMessage1='TruncateDb error on ' + @Database_Name
			EXECUTE [DBA].[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
		END CATCH
		FETCH NEXT FROM @myCursor INTO @Database_Name
	END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_table', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2021-01-16', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_table', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-01-16', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_table', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_table', NULL, NULL
GO
