SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <11/04/2018>
-- Version:		<3.0.0.1>
-- Description:	<Set same Auto growth for user databases when no user is loggedin database>
-- Input Parameters:
--	@DatabaseNames:		'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@AllowSameGrowth:	0,1 and 1 is allowed and 0 is disallowed
--	@AllowKillUsers:	0,1
--	@PrintOnly:			0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_same_growth]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>'
	,@AllowSameGrowth BIT=1
	,@AllowKillUsers BIT=0
	,@PrintOnly BIT=0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @SqlCmd nvarchar(MAX);
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myOnOff NVARCHAR(50);
	DECLARE @versionString NVARCHAR(20);
	DECLARE @serverVersion DECIMAL(10,5);
	DECLARE @sqlServer2016Version DECIMAL(10,5);
	DECLARE @myCursor Cursor;
	
	SET @versionString = CAST(SERVERPROPERTY('productversion') AS NVARCHAR(20))
	SET @serverVersion = CAST(LEFT(@versionString,CHARINDEX('.', @versionString)) AS DECIMAL(10,5))
	SET @sqlServer2016Version = 13.0 -- SQL Server 2016
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myOnOff=CASE @AllowSameGrowth WHEN 0 THEN N'AUTOGROW_SINGLE_FILE' ELSE N'AUTOGROW_ALL_FILES' END
	IF(@serverVersion >= @sqlServer2016Version)
	BEGIN
		SET @myCursor=CURSOR For
			Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
	
		Open @myCursor
		FETCH NEXT FROM @myCursor INTO @Database_Name
				WHILE @@FETCH_STATUS=0
				BEGIN
						--============Start of Removing any existence snapshot
						BEGIN TRY
							SET @SqlCmd=CAST(N'' AS NVARCHAR(MAX))
							SELECT @SqlCmd=@SqlCmd+CAST(
									@myNewLine+ N'USE ' + CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX))+
									@myNewLine+ N'DECLARE @myNewLine nvarchar(10);'+
									@myNewLine+ N'DECLARE @myCmd NVARCHAR(MAX)'+
									@myNewLine+ N'SET @myNewLine=CHAR(13)+CHAR(10)'+
									@myNewLine+ N'SET @myCmd=CAST(N'''' AS NVARCHAR(MAX))'+
									@myNewLine+ N'SELECT '+
									@myNewLine+ N'	@myCmd=@myCmd + CAST(N''ALTER DATABASE ' + QUOTENAME(@Database_Name) + ' MODIFY FILEGROUP '' + QUOTENAME([name]) + N'' ' + @myOnOff + N';'' + @myNewLine AS NVARCHAR(MAX)) '+
									@myNewLine+ N'FROM '+
									@myNewLine+ N'	sys.[filegroups]'+
									@myNewLine+ N'WHERE'+
									@myNewLine+ N'	[is_read_only]=0'+
									@myNewLine+ N'	AND [is_autogrow_all_files]!=' + CAST(@AllowSameGrowth AS NVARCHAR(MAX)) +
									@myNewLine+ N'	AND [type]=''FG'''+
									@myNewLine+ N'	AND [data_space_id] IN (SELECT [data_space_id] from sys.[database_files])'+
									@myNewLine+ N' '+
									CASE @AllowKillUsers
										WHEN 1 THEN @myNewLine+ N'EXECUTE [DBA].[dbo].[dbasp_kill_db_users] ''' + @Database_Name + ''',DEFAULT,DEFAULT,DEFAULT,0'
										ELSE N''
									END+
									@myNewLine+ N'EXEC (@myCmd);'+
									@myNewLine+ N'----------------------------------'
									AS NVARCHAR(MAX))
						
							EXEC [dbo].[dbasp_print_text] @SqlCmd
							IF @PrintOnly=0
								EXECUTE sp_executesql @SqlCmd;

						END TRY
						BEGIN CATCH
							DECLARE @CustomMessage1 NVARCHAR(255)
							SET @CustomMessage1='Set Autogrowth failed for ' + @Database_Name
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
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_same_growth', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2018-04-11', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_same_growth', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-07-17', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_same_growth', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.1', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_same_growth', NULL, NULL
GO
