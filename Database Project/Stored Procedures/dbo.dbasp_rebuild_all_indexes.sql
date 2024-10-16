SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/21/2015>
-- Version:		<3.0.0.0>
-- Description:	<Rebuild all database index with specified options>
-- Input Parameters:
--	@DatabaseNames:		'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@FilterForSchema:	'...'		//Any value for using in where clause
--	@RebuildOptions:	'...(...)'	//Any additional options in Rebuild syntax
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_rebuild_all_indexes] (
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@FilterForSchema NVARCHAR(255) = N'%',
	@RebuildOptions NVARCHAR(255) = N''
	)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @DBTablesCmd NVARCHAR(MAX);
	DECLARE @mySQLScript NVARCHAR(MAX);
	DECLARE @FullTableName NVARCHAR(255);
	
	SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
		
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
	WHILE @@FETCH_STATUS=0
		BEGIN
			SET @DBTablesCmd=CAST(N'' AS NVARCHAR(MAX))
			SET @DBTablesCmd = @DBTablesCmd + 
			CAST(
			N'DECLARE TableCursor CURSOR FOR SELECT ''['' + table_catalog + ''].['' + table_schema + ''].['' +
			  table_name + '']'' as FullTableName FROM [' + CAST(@Database_Name AS NVARCHAR(MAX)) + N'].INFORMATION_SCHEMA.TABLES
			  WHERE table_type = ''BASE TABLE'' AND table_schema LIKE ''' + @FilterForSchema + N'''' AS NVARCHAR(MAX))

			--=========Start of Create table cursor  
			BEGIN TRY
				EXEC (@DBTablesCmd)
			END TRY
			BEGIN CATCH
				DECLARE @CustomMessage1 nvarchar(255)
				SET @CustomMessage1='Rebuild index error, it is about cursor creation on ' + @Database_Name
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
			END CATCH
			--=========End of Create table cursor  
			OPEN TableCursor  
			FETCH NEXT FROM TableCursor INTO @FullTableName
			WHILE @@FETCH_STATUS = 0  
			BEGIN  
				IF (@@MICROSOFTVERSION / POWER(2, 24) >= 9)
				BEGIN
					-- SQL 2005 or higher command
					SET @mySQLScript = CAST(N'' AS NVARCHAR(MAX))
					SET @mySQLScript = @mySQLScript + CAST(N'ALTER INDEX ALL ON ' + @FullTableName + N' REBUILD ' + @RebuildOptions AS NVARCHAR(MAX))
					--==============Start of Executing ALTER
					BEGIN TRY
						EXEC (@mySQLScript)
					END TRY
					BEGIN CATCH
						DECLARE @CustomMessage2 nvarchar(255)
						SET @CustomMessage2='ALTER Index error on ' + @Database_Name
						EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage2,1,0,1,0,NULL
					END CATCH
					--==============End of Executing ALTER
				END
				ELSE
				BEGIN
					-- SQL 2000 command
					DBCC DBREINDEX(@FullTableName)
				END
				FETCH NEXT FROM TableCursor INTO @FullTableName  
			END

			CLOSE TableCursor  
			DEALLOCATE TableCursor
			
			FETCH NEXT FROM @myCursor INTO @Database_Name
		END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END



GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rebuild_all_indexes', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rebuild_all_indexes', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rebuild_all_indexes', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rebuild_all_indexes', NULL, NULL
GO
