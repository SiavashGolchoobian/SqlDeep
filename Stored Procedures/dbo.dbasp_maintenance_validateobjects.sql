SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/21/2015>
-- Version:		<3.0.0.0>
-- Description:	<Updates and Validates the metadata for the database non-schema-bound stored procedure, user-defined function, view, DML trigger, database-level DDL trigger, or server-level DDL trigger>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@ShowInfo:		'ALL' or 'VALIDATED' or 'NOTVALIDATED'
--	@PrintOnly:		0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_validateobjects]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@ShowInfo nvarchar(20)=N'ALL',
	@PrintOnly bit=0
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

	IF @PrintOnly=0	--Execute reindex
		BEGIN
			Open @myCursor
			FETCH NEXT FROM @myCursor INTO @Database_Name
			WHILE @@FETCH_STATUS=0
				BEGIN
					SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
					SET @mySQLScript=@mySQLScript+
					CAST(
					@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) +N';' +
					@myNewLine+ N'Declare @myCursor Cursor;' +
					@myNewLine+ N'Declare @myObjectType nvarchar(255);'+
					@myNewLine+ N'Declare @myCommand nvarchar(max);'+
					@myNewLine+ N''+
					@myNewLine+ N'SET @myCursor=Cursor for'+
					@myNewLine+ N'SELECT '+
					@myNewLine+ N'	type_desc AS Object_Type,'+
					@myNewLine+ N'	''sp_refreshsqlmodule '''''' + QUOTENAME(OBJECT_SCHEMA_NAME(object_id)) + ''.'' + QUOTENAME(name) + '''''''' as SQLStatement'+
					@myNewLine+ N'from '+
					@myNewLine+ N'	sys.all_objects'+
					@myNewLine+ N'where'+
					@myNewLine+ N'	type in (''FN'',''IF'',''P'',''TF'',''X'',''V'',''AF'',''TR'')'+
					@myNewLine+ N'	and is_ms_shipped=0'+
					@myNewLine+ N' '+
					@myNewLine+ N'Open @myCursor'+
					@myNewLine+ N'Fetch Next From @myCursor INTO @myObjectType,@myCommand'+
					@myNewLine+ N'WHILE @@FETCH_STATUS=0'+
					@myNewLine+ N'	BEGIN'+
					@myNewLine+ N'		BEGIN TRANSACTION myValidator'+
					@myNewLine+ N'			BEGIN TRY'+
					@myNewLine+ N'				EXECUTE (@myCommand)'+
					@myNewLine+ N'				IF UPPER(''' + @ShowInfo + N''')=''ALL'' OR UPPER(''' + @ShowInfo + N''')=''VALIDATED'''+
					@myNewLine+ N'					print (''Object validated ('' + @myObjectType + ''): '' + @myCommand)'+
					@myNewLine+ N'				COMMIT TRANSACTION myValidator'+
					@myNewLine+ N'			END TRY'+
					@myNewLine+ N'			BEGIN CATCH'+
					@myNewLine+ N'				IF UPPER(''' + @ShowInfo + N''')=''ALL'' OR UPPER(''' + @ShowInfo + N''')=''NOTVALIDATED'''+
					@myNewLine+ N'					print (''! Object validation error ('' + @myObjectType + ''): '' + @myCommand)'+
					@myNewLine+ N'				IF @@TRANCOUNT > 0 '+
					@myNewLine+ N'					ROLLBACK TRANSACTION myValidator;'+
					@myNewLine+ N'			END CATCH'+
					@myNewLine+ N'		Fetch Next From @myCursor INTO @myObjectType,@myCommand'+
					@myNewLine+ N'	END'+
					@myNewLine+ N'CLOSE @myCursor;'+
					@myNewLine+ N'DEALLOCATE @myCursor;'
					AS NVARCHAR(MAX))

					EXEC [dbo].[dbasp_print_text] @mySQLScript;
					PRINT @myNewLine+'--Current database is '+ @Database_Name;
					--=============Start of validating objects
					BEGIN TRY
						EXECUTE (@mySQLScript);
					END TRY
					BEGIN CATCH
						EXECUTE [dbo].[dbasp_get_error_info] 'Validating objects error',1,0,1,0,NULL
					END CATCH
					--=============End of validating objects
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
					SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
					SET @mySQLScript=@mySQLScript+
					CAST(
					@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) +N';' +
					@myNewLine+ N'Declare @myObjectType nvarchar(255);'+
					@myNewLine+ N'Declare @myCommand nvarchar(max);'+
					@myNewLine+ N''+
					@myNewLine+ N'SELECT '+
					@myNewLine+ N'	type_desc AS Object_Type ,'+
					@myNewLine+ N'	''sp_refreshsqlmodule '''''' + QUOTENAME(OBJECT_SCHEMA_NAME(object_id)) + ''.'' + QUOTENAME(name) + '''''''' as SQLStatement'+
					@myNewLine+ N'from '+
					@myNewLine+ N'	sys.all_objects'+
					@myNewLine+ N'where'+
					@myNewLine+ N'	type in (''FN'',''IF'',''P'',''TF'',''X'',''V'',''AF'',''TR'')'+
					@myNewLine+ N'	and is_ms_shipped=0'
					AS NVARCHAR(MAX))
					EXEC [dbo].[dbasp_print_text] @mySQLScript;
					--===========Start of Printing Commands
					BEGIN TRY
						EXECUTE (@mySQLScript);
					END TRY
					BEGIN CATCH
						DECLARE @CustomMessage nvarchar(255)
						SET @CustomMessage='Validation objects error on ' + @Database_Name
						EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
					END CATCH
					--===========End of Printing Commands

					FETCH NEXT FROM @myCursor INTO @Database_Name
				END
			CLOSE @myCursor;
			DEALLOCATE @myCursor;
		END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_validateobjects', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_validateobjects', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_validateobjects', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_validateobjects', NULL, NULL
GO
