SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <11/04/2018>
-- Version:		<3.0.0.0>
-- Description:	<Set Unifrom Extent Allocation for user databases>
-- Input Parameters:
--	@DatabaseNames:		'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@Enabled:			0,1 and 1 is allowed and 0 is disallowed
--	@PrintOnly:			0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_uniform_extent]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>'
	,@Enabled BIT=1
	,@PrintOnly BIT=0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @SqlCmd nvarchar(MAX);
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myOnOff NVARCHAR(10);
	DECLARE @versionString NVARCHAR(20);
	DECLARE @serverVersion DECIMAL(10,5);
	DECLARE @sqlServer2016Version DECIMAL(10,5);
	DECLARE @myCursor Cursor;
	
	SET @versionString = CAST(SERVERPROPERTY('productversion') AS NVARCHAR(20))
	SET @serverVersion = CAST(LEFT(@versionString,CHARINDEX('.', @versionString)) AS DECIMAL(10,5))
	SET @sqlServer2016Version = 13.0 -- SQL Server 2016
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myOnOff=CASE @Enabled WHEN 1 THEN N'OFF' ELSE N'ON' END
	IF(@serverVersion >= @sqlServer2016Version)
	BEGIN
		SET @myCursor=CURSOR FOR
			SELECT [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
	
		OPEN @myCursor
		FETCH NEXT FROM @myCursor INTO @Database_Name
				WHILE @@FETCH_STATUS=0
				BEGIN
						--============Start of Removing any existence snapshot
						BEGIN TRY
							SET @SqlCmd=CAST(N'' AS NVARCHAR(MAX))
							SET @SqlCmd=@SqlCmd+CAST(
									@myNewLine+ N'IF EXISTS(SELECT 1 FROM sys.databases WHERE [name]=''' + @Database_Name + N''' AND [is_mixed_page_allocation_on]=' + CAST(@Enabled AS NVARCHAR(MAX)) + N')'+
									@myNewLine+ N'ALTER DATABASE ' + QUOTENAME(@Database_Name) + N' SET MIXED_PAGE_ALLOCATION ' + @myOnOff + N';' 
									AS NVARCHAR(MAX))
						
							EXEC [dbo].[dbasp_print_text] @SqlCmd
							IF @PrintOnly=0
								EXECUTE sp_executesql @SqlCmd;

						END TRY
						BEGIN CATCH
							DECLARE @CustomMessage1 NVARCHAR(255)
							SET @CustomMessage1='Set Uniform Extent Allocation failed for ' + @Database_Name
							EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
						END CATCH
					FETCH NEXT FROM @myCursor INTO @Database_Name
				END
		CLOSE @myCursor;
		DEALLOCATE @myCursor;
	END
	ELSE
	BEGIN
		PRINT 'This procedure can not do anything because current SQL Instance Version is below than SQL 2016'
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_uniform_extent', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2018-04-11', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_uniform_extent', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-04-11', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_uniform_extent', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_uniform_extent', NULL, NULL
GO
