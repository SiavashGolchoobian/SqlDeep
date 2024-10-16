SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <4/6/2019>
-- Version:		<3.0.0.1>
-- Description:	<Add or Rename Binary(8) and a Record Owner columns with specified name to all tables>
-- Input Parameters:
--	@DatabaseNames:						'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@Binary8FieldName:					Field name of Binary(8) data type you want
--	@RenameExistedBinary8Columns:		1 to rename existed Binary(8) columns of tables to @Binary8FieldName or 0 to unmodify existed Binary(8) columns
--	@PrintOnly:							0 or 1
-- =============================================

CREATE PROCEDURE [dbo].[dbasp_rowversion_add_binary8_columns]
(
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@Binary8FieldName sysname='StoredRowVersionValue',
	@RecordOwnerFieldName sysname='StoredRowVersionOwner',
	@RenameExistedBinary8Columns BIT=0,
	@PrintOnly BIT=1
) 
AS 
BEGIN
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @Database_ID INT;
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);

	SET @Binary8FieldName=REPLACE(REPLACE(@Binary8FieldName,'[',''),']','')
	SET @RecordOwnerFieldName=REPLACE(REPLACE(@RecordOwnerFieldName,'[',''),']','')
	SET @myNewLine=CHAR(13)+CHAR(10)
    SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
		
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
	WHILE @@FETCH_STATUS=0
	BEGIN
		SELECT @Database_ID=database_id from sys.databases where name=@Database_Name
		SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
			@myNewLine+ N'CREATE TABLE #myTableWithoutBinary8 ([object_id] INT PRIMARY KEY, [Object_full_name] NVARCHAR(256),[TableHasBinary8] BIT,[TableHasSameBinary8FieldName] BIT,[TableHasSameRecordOwnerFieldName] BIT,[ExistedBinary8FieldName] NVARCHAR(256),[ModifyCommand_Binary8] NVARCHAR(max),[ModifyCommand_RecordOwner] NVARCHAR(max))'+
			@myNewLine+ N'INSERT INTO [#myTableWithoutBinary8] ([object_id], [Object_full_name], [TableHasBinary8], [TableHasSameBinary8FieldName], [TableHasSameRecordOwnerFieldName], [ExistedBinary8FieldName], [ModifyCommand_Binary8], [ModifyCommand_RecordOwner])'+
			@myNewLine+ N'SELECT'+
			@myNewLine+ N'	[myCore0].[object_id],'+
			@myNewLine+ N'	[myCore0].[Full_Object_Name],'+
			@myNewLine+ N'	[myCore0].[TableHasBinary8],'+
			@myNewLine+ N'	[myCore0].[TableHasSameBinary8FieldName],'+
			@myNewLine+ N'	[myCore0].[TableHasSameRecordOwnerFieldName],'+
			@myNewLine+ N'	[myCore0].[ExistedBinary8FieldName],'+
			@myNewLine+ N'	CASE [myCore0].[TableHasBinary8]'+
			@myNewLine+ N'		WHEN 0 THEN N''ALTER TABLE '' + [myCore0].[Full_Object_Name] + N'' ADD ' + CAST(QUOTENAME(@Binary8FieldName) AS NVARCHAR(MAX)) + ' BINARY(8)'' '+
			@myNewLine+ N'		WHEN 1 THEN N''EXEC sp_rename '''''' + [myCore0].[Full_Object_Name] + N''.'' + [myCore0].[ExistedBinary8FieldName] + N'''''', ''''' + CAST(@Binary8FieldName AS NVARCHAR(MAX)) +N''''', ''''COLUMN''''''  '+
			@myNewLine+ N'	END	AS [ModifyCommand_Binary8],'+
			@myNewLine+ N'	CASE [myCore0].[TableHasSameRecordOwnerFieldName]'+
			@myNewLine+ N'		WHEN 0 THEN N''ALTER TABLE '' + [myCore0].[Full_Object_Name] + N'' ADD ' + CAST(QUOTENAME(@RecordOwnerFieldName) AS NVARCHAR(MAX)) + ' NVARCHAR(261)'' '+
			@myNewLine+ N'	END	AS [ModifyCommand_RecordOwner]'+
			@myNewLine+ N'FROM'+
			@myNewLine+ N'	('+
			@myNewLine+ N'		SELECT '+
			@myNewLine+ N'			[myColumns].[object_id],'+
			@myNewLine+ N'			MAX(QUOTENAME([mySchema].[name])+N''.''+QUOTENAME([myTables].[name])) AS Full_Object_Name,'+
			@myNewLine+ N'			MAX(CASE WHEN [myTypes].[name]=''binary'' AND [myColumns].[max_length]=8 THEN QUOTENAME([myColumns].[name]) ELSE NULL END) AS ExistedBinary8FieldName,'+
			@myNewLine+ N'			MAX(CASE WHEN [myTypes].[name]=''binary'' AND [myColumns].[max_length]=8 THEN 1 ELSE 0 END) AS TableHasBinary8,'+
			@myNewLine+ N'			MAX(CASE WHEN [myColumns].[name]=''' + CAST(@Binary8FieldName AS NVARCHAR(MAX)) + ''' THEN 1 ELSE 0 END) AS TableHasSameBinary8FieldName,'+
			@myNewLine+ N'			MAX(CASE WHEN [myColumns].[name]=''' + CAST(@RecordOwnerFieldName AS NVARCHAR(MAX)) + ''' THEN 1 ELSE 0 END) AS TableHasSameRecordOwnerFieldName'+
			@myNewLine+ N'		FROM '+
			@myNewLine+ N'			sys.[all_objects] AS myTables'+
			@myNewLine+ N'			INNER JOIN sys.[schemas] AS mySchema ON [mySchema].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+ N'			INNER JOIN sys.[all_columns] AS myColumns ON [myColumns].[object_id] = [myTables].[object_id]'+
			@myNewLine+ N'			INNER JOIN sys.[types] AS myTypes ON [myColumns].[system_type_id]=[myTypes].[user_type_id]'+
			@myNewLine+ N'		WHERE'+
			@myNewLine+ N'			[myTables].[type]=''U'''+
			@myNewLine+ N'			AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+ N'		GROUP BY'+
			@myNewLine+ N'			[myColumns].[object_id]'+
			@myNewLine+ N'	) AS myCore0'+
			@myNewLine+	N''+
			@myNewLine+	N'	IF EXISTS(SELECT 1 FROM [#myTableWithoutBinary8] WHERE ([TableHasBinary8]=0 AND [TableHasSameBinary8FieldName]=1) OR [TableHasSameRecordOwnerFieldName]=1)'+
			@myNewLine+	N'		BEGIN'+
			@myNewLine+	N'			PRINT ''Same field name existed in table(s) without binary(8) data type or with same field name of @RecordOwnerFieldName.'''+
			@myNewLine+	N'			RETURN'+
			@myNewLine+	N'		END'+
			@myNewLine+	N''+
			CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'/*' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Comment execution
			@myNewLine+ N'DECLARE @myCursor Cursor;'+
			@myNewLine+ N'DECLARE @mySQLStatement NVARCHAR(max);'+
			@myNewLine+ N''+
			@myNewLine+ N'SET @myCursor=CURSOR For'+
			@myNewLine+	N'	SELECT [ModifyCommand_Binary8] AS ModifyCommand FROM [#myTableWithoutBinary8] WHERE [ModifyCommand_Binary8] IS NOT NULL AND ([TableHasBinary8]=0 OR (' + CAST(@RenameExistedBinary8Columns AS NVARCHAR(MAX)) + N'=1 AND [TableHasBinary8]=1))'+
			@myNewLine+ N'	UNION ALL'+
			@myNewLine+	N'	SELECT [ModifyCommand_RecordOwner] FROM [#myTableWithoutBinary8] WHERE [ModifyCommand_RecordOwner] IS NOT NULL;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''Current database is '+ @Database_Name + N''';' +
			@myNewLine+ N'Open @myCursor'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor INTO @mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing on '' + CAST(getdate() as nvarchar(50)) + ''):	'' + @mySQLStatement;'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				DECLARE @CustomMessage1 nvarchar(255)'+
			@myNewLine+ N'				SET @CustomMessage1=''Altering table error on '+@Database_Name+N'''' +
			@myNewLine+ N'				EXECUTE ' + CAST(QUOTENAME(DB_NAME()) AS NVARCHAR(MAX)) + N'.[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor INTO @mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor; '+
			@myNewLine+ N'DEALLOCATE @myCursor; '+
			@myNewLine+ N''+
			CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'*/' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Comment execution
			CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'SELECT [object_id],[Object_full_name],[TableHasBinary8],[TableHasSameBinary8FieldName] AS [TableHasSameFieldName],[ExistedBinary8FieldName],[ModifyCommand_Binary8] as ModifyCommand FROM [#myTableWithoutBinary8] WHERE [ModifyCommand_Binary8] IS NOT NULL AND ([TableHasBinary8]=0 OR (' + CAST(@RenameExistedBinary8Columns AS NVARCHAR(MAX)) + N'=1 AND [TableHasBinary8]=1)) UNION ALL 	SELECT [object_id],[Object_full_name],NULL AS [TableHasBinary8],[TableHasSameRecordOwnerFieldName] AS [TableHasSameFieldName],NULL AS [ExistedBinary8FieldName],[ModifyCommand_RecordOwner] FROM [#myTableWithoutBinary8] WHERE [ModifyCommand_RecordOwner] IS NOT NULL;' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Return commands list
			@myNewLine+	N'DROP TABLE #myTableWithoutBinary8;'
			AS NVARCHAR(MAX))

		EXEC [dbo].[dbasp_print_text] @mySQLScript
		IF @PrintOnly=0
			PRINT (@myNewLine + '--Excexution Report--');

		--=======Start of executing commands
		BEGIN TRY
			EXECUTE (@mySQLScript);
		END TRY
		BEGIN CATCH
			DECLARE @CustomMessage1 NVARCHAR(255)
			SET @CustomMessage1='Altering table error on ' + @Database_Name
			EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
		END CATCH
		--=======End of executing commands
		FETCH NEXT FROM @myCursor INTO @Database_Name
	END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_binary8_columns', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-04-06', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_binary8_columns', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-04-06', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_binary8_columns', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_binary8_columns', NULL, NULL
GO
