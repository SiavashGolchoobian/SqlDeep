SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/21/2015>
-- Version:		<3.0.0.0>
-- Description:	<Refresh unschema bounded views metadata>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@ShowInfo:		'ALL' or 'VALIDATED' or 'NOTVALIDATED'
--	@PrintOnly:		0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_refreshview]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@ShowInfo NVARCHAR(20)='ALL',
	@PrintOnly BIT=0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @mySQLScript NVARCHAR(MAX);
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
					@myNewLine+ N'Declare @myCommand nvarchar(max);'+
					@myNewLine+ N''+
					@myNewLine+ N'SET @myCursor=Cursor for'+
					@myNewLine+ N'SELECT DISTINCT'+
					@myNewLine+ N'	''EXEC sp_refreshview '''''' + QUOTENAME(OBJECT_SCHEMA_NAME(myObjects.object_id)) + ''.'' +QUOTENAME(OBJECT_NAME(myObjects.object_id)) + '''''''' '+
					@myNewLine+ N'from '+
					@myNewLine+ N'	sys.objects AS myObjects'+
					@myNewLine+ N'	INNER JOIN sys.sql_expression_dependencies AS myDependents ON myObjects.object_id = myDependents.referencing_id '+
					@myNewLine+ N'where'+
					@myNewLine+ N'	myObjects.type = ''V'' '+
					@myNewLine+ N'	and myDependents.is_schema_bound_reference=0'+
					@myNewLine+ N' '+
					@myNewLine+ N'Open @myCursor'+
					@myNewLine+ N'Fetch Next From @myCursor INTO @myCommand'+
					@myNewLine+ N'WHILE @@FETCH_STATUS=0'+
					@myNewLine+ N'	BEGIN'+
					@myNewLine+ N'		BEGIN TRANSACTION myValidator'+
					@myNewLine+ N'			BEGIN TRY'+
					@myNewLine+ N'				EXECUTE (@myCommand)'+
					@myNewLine+ N'				IF UPPER(''' + @ShowInfo + N''')=''ALL'' OR UPPER(''' + @ShowInfo + N''')=''VALIDATED'''+
					@myNewLine+ N'					print (''Object validated: '' + @myCommand)'+
					@myNewLine+ N'				COMMIT TRANSACTION myValidator'+
					@myNewLine+ N'			END TRY'+
					@myNewLine+ N'			BEGIN CATCH'+
					@myNewLine+ N'				IF UPPER(''' + @ShowInfo + N''')=''ALL'' OR UPPER(''' + @ShowInfo + N''')=''NOTVALIDATED'''+
					@myNewLine+ N'					print (''! Object validation error: '' + @myCommand)'+
					@myNewLine+ N'				IF @@TRANCOUNT > 0 '+
					@myNewLine+ N'					ROLLBACK TRANSACTION myValidator;'+
					@myNewLine+ N'			END CATCH'+
					@myNewLine+ N'		Fetch Next From @myCursor INTO @myCommand'+
					@myNewLine+ N'	END'+
					@myNewLine+ N'CLOSE @myCursor;'+
					@myNewLine+ N'DEALLOCATE @myCursor;'
					AS NVARCHAR(MAX))

					EXEC [dbo].[dbasp_print_text] @mySQLScript;
					PRINT @myNewLine+'--Current database is '+ @Database_Name;
					--==============Start of refreshing views
					BEGIN TRY
						EXECUTE (@mySQLScript);
					END TRY
					BEGIN CATCH
						EXECUTE [dbo].[dbasp_get_error_info] 'Refreshing views error',1,0,1,0,NULL
					END CATCH
					--==============End of refreshing views
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
					@myNewLine+ N'Declare @myCommand nvarchar(max);'+
					@myNewLine+ N''+
					@myNewLine+ N'SELECT DISTINCT'+
					@myNewLine+ N'	''EXEC sp_refreshview '''''' + QUOTENAME(OBJECT_SCHEMA_NAME(myObjects.object_id)) + ''.'' +QUOTENAME(OBJECT_NAME(myObjects.object_id)) + '''''''' '+
					@myNewLine+ N'from '+
					@myNewLine+ N'	sys.objects AS myObjects'+
					@myNewLine+ N'	INNER JOIN sys.sql_expression_dependencies AS myDependents ON myObjects.object_id = myDependents.referencing_id '+
					@myNewLine+ N'where'+
					@myNewLine+ N'	myObjects.type = ''V'' '+
					@myNewLine+ N'	and myDependents.is_schema_bound_reference=0'
					AS NVARCHAR(MAX))

					EXEC [dbo].[dbasp_print_text] @mySQLScript;
					--==============Start of presenting refreshing view commands
					BEGIN TRY
						EXECUTE (@mySQLScript);
					END TRY
					BEGIN CATCH
						DECLARE @CustomMessage nvarchar(255)
						SET @CustomMessage='Refreshing views error on ' + @Database_Name
						EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
					END CATCH
					--==============End of presenting refreshing view commands
					FETCH NEXT FROM @myCursor INTO @Database_Name
				END
			CLOSE @myCursor;
			DEALLOCATE @myCursor;
		END
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_refreshview', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_refreshview', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_refreshview', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_refreshview', NULL, NULL
GO
