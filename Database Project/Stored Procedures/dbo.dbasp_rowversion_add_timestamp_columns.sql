SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <4/6/2019>
-- Version:		<3.0.0.1>
-- Description:	<Add or Rename timestamp column with specified name to all tables>
-- Input Parameters:
--	@DatabaseNames:						'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@TimestampFieldName:				Field name of timestamp data type you want
--	@RenameExistedRowversionColumns:	1 to rename existed timestamp columns of tables to @TimestampFieldName or 0 to unmodify existed timestamp columns
--	@PrintOnly:							0 or 1
-- =============================================

CREATE PROCEDURE [dbo].[dbasp_rowversion_add_timestamp_columns]
(
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@TimestampFieldName sysname='RowVersionValue',
	@RenameExistedRowversionColumns BIT=0,
	@PrintOnly BIT=1
) 
AS 
BEGIN
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @Database_ID INT;
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);

	SET @TimestampFieldName=REPLACE(REPLACE(@TimestampFieldName,'[',''),']','')
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
			@myNewLine+ N'CREATE TABLE #myTableWithoutRowVersion ([object_id] INT PRIMARY KEY, [Object_full_name] NVARCHAR(256),TableHasRowVersion BIT,TableHasSameFieldName BIT,[ExistedTimestampFieldName] NVARCHAR(256),AddCommand NVARCHAR(max))'+
			@myNewLine+ N'INSERT INTO [#myTableWithoutRowVersion] ([object_id], [Object_full_name], [TableHasRowVersion], [TableHasSameFieldName], [ExistedTimestampFieldName], [AddCommand])'+
			@myNewLine+ N'SELECT'+
			@myNewLine+ N'	[myCore0].[object_id],'+
			@myNewLine+ N'	[myCore0].[Full_Object_Name],'+
			@myNewLine+ N'	[myCore0].[TableHasRowVersion],'+
			@myNewLine+ N'	[myCore0].[TableHasSameFieldName],'+
			@myNewLine+ N'	[myCore0].[ExistedTimestampFieldName],'+
			@myNewLine+ N'	CASE [myCore0].[TableHasRowVersion]'+
			@myNewLine+ N'		WHEN 0 THEN N''ALTER TABLE '' + [myCore0].[Full_Object_Name] + N'' ADD ' + CAST(QUOTENAME(@TimestampFieldName) AS NVARCHAR(MAX)) + ' TIMESTAMP'' '+
			@myNewLine+ N'		WHEN 1 THEN N''EXEC sp_rename '''''' + [myCore0].[Full_Object_Name] + N''.'' + [myCore0].[ExistedTimestampFieldName] + N'''''', ''''' + CAST(@TimestampFieldName AS NVARCHAR(MAX)) +N''''', ''''COLUMN''''''  '+
			@myNewLine+ N'	END	AS AddCommand'+
			@myNewLine+ N'FROM'+
			@myNewLine+ N'	('+
			@myNewLine+ N'		SELECT '+
			@myNewLine+ N'			[myColumns].[object_id],'+
			@myNewLine+ N'			MAX(QUOTENAME([mySchema].[name])+N''.''+QUOTENAME([myTables].[name])) AS Full_Object_Name,'+
			@myNewLine+ N'			MAX(CASE WHEN [myTypes].[name]=''timestamp'' THEN QUOTENAME([myColumns].[name]) ELSE NULL END) AS ExistedTimestampFieldName,'+
			@myNewLine+ N'			MAX(CASE WHEN [myTypes].[name]=''timestamp'' THEN 1 ELSE 0 END) AS TableHasRowVersion,'+
			@myNewLine+ N'			MAX(CASE WHEN [myColumns].[name]=''' + CAST(@TimestampFieldName AS NVARCHAR(MAX)) + ''' THEN 1 ELSE 0 END) AS TableHasSameFieldName'+
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
			@myNewLine+	N'	IF EXISTS(SELECT 1 FROM [#myTableWithoutRowVersion] WHERE [TableHasRowVersion]=0 AND [TableHasSameFieldName]=1)'+
			@myNewLine+	N'		BEGIN'+
			@myNewLine+	N'			PRINT ''Same field name existed in table(s) without rowversion field.'''+
			@myNewLine+	N'			RETURN'+
			@myNewLine+	N'		END'+
			@myNewLine+	N''+
			CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'/*' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Comment execution
			@myNewLine+ N'DECLARE @myCursor Cursor;'+
			@myNewLine+ N'DECLARE @mySQLStatement NVARCHAR(max);'+
			@myNewLine+ N''+
			@myNewLine+ N'SET @myCursor=CURSOR For'+
			@myNewLine+	N'	SELECT AddCommand FROM [#myTableWithoutRowVersion] WHERE [TableHasRowVersion]=0 OR (' + CAST(@RenameExistedRowversionColumns AS NVARCHAR(MAX)) + N'=1 AND [TableHasRowVersion]=1);'+
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
			CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'SELECT * FROM [#myTableWithoutRowVersion] WHERE [TableHasRowVersion]=0 OR (' + CAST(@RenameExistedRowversionColumns AS NVARCHAR(MAX)) + N'=1 AND [TableHasRowVersion]=1);' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Return commands list
			@myNewLine+	N'DROP TABLE #myTableWithoutRowVersion;'
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
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_timestamp_columns', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_timestamp_columns', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_timestamp_columns', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_timestamp_columns', NULL, NULL
GO
