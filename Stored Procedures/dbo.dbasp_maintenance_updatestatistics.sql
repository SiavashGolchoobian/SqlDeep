SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Ian Stirk + Golchoobian>
-- Create date: <01/21/2015>
-- Version:		<3.0.0.1>
-- Description:	<Update whole database necessary object(table/indexed views) statistics>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@FilterTables:	'<ALL_TABLES>'or comma seperated FQDN table names like '[myDB1].[mySchema1].[myTable1],[myDB2].[mySchema2].[myTable2]'
--	@IgnoreStatsUpdatedInLastXHours:	Ignore updating stats if last update is for last @IgnoreStatsUpdatedInLastXHours hours
--	@UnusedStatTresholdInDays:			Ignore updating stats if last update of that index is latest than @UnusedStatTresholdInDays days
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_updatestatistics]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@FilterTables NVARCHAR(MAX) = N'<ALL_TABLES>',
	@IgnoreStatsUpdatedInLastXHours INT = 6,
	@UnusedStatTresholdInDays INT=32,
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
	WHILE @@FETCH_STATUS=0
		BEGIN	
			SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
			SET @mySQLScript = @mySQLScript + 
				CAST(
				@myNewLine + N'USE ' + CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';' +
				@myNewLine + N'DECLARE @myIgnoreStatsUpdatedInLastXHours INT'+
				@myNewLine + N'DECLARE @myUnusedStatTresholdInDays INT'+
				@myNewLine + N'DECLARE @myToday DATETIME2(7)'+
				@myNewLine + N'SET @myIgnoreStatsUpdatedInLastXHours = '+ CAST(@IgnoreStatsUpdatedInLastXHours AS NVARCHAR(MAX))+
				@myNewLine + N'SET @myUnusedStatTresholdInDays = '+CAST(@UnusedStatTresholdInDays AS NVARCHAR(MAX))+
				@myNewLine + N'SET @myIgnoreStatsUpdatedInLastXHours = @myIgnoreStatsUpdatedInLastXHours * -1'+
				@myNewLine + N'SET @myUnusedStatTresholdInDays = @myUnusedStatTresholdInDays * -1'+
				@myNewLine + N'SET @myToday=CAST(GETDATE() AS DATETIME2(7))'+
				@myNewLine+	N'CREATE TABLE #StatCommands (ID int IDENTITY, SQLStatement nvarchar(max));'+
				@myNewLine+	N'INSERT INTO #StatCommands (SQLStatement)'+
				@myNewLine + N'SELECT'+
				@myNewLine + N'	N''UPDATE STATISTICS '' + QUOTENAME([myStatData].[SchemaName]) + N''.'' + QUOTENAME([myStatData].[ObjectName]) + N'' '' + QUOTENAME([myStatData].[StatName]) + N'' WITH SAMPLE ''+ [myStatData].[SampleValue] + N'' -- '' + CAST(COALESCE([myStatData].[StatRows],[myStatData].[TableRows],0) + ISNULL([myStatData].[ModifiedRows],0) AS NVARCHAR(MAX))+ N'' rows that has '' + CAST(ISNULL([myStatData].[ModifiedRows],0) AS NVARCHAR(MAX)) + N'' modified rows.'' AS UpdateCommend'+
				@myNewLine + N'FROM'+
				@myNewLine + N'	('+
				@myNewLine + N'	SELECT'+
				@myNewLine + N'		[myStatList].[object_id],'+
				@myNewLine + N'		[mySchema].[name] AS SchemaName,'+
				@myNewLine + N'		[myObjects].[name] AS ObjectName,'+
				@myNewLine + N'		[myStatList].[stats_id],'+
				@myNewLine + N'		[myStatList].[name] AS StatName,'+
				@myNewLine + N'		[myStatProperties].[last_updated],'+
				@myNewLine + N'		[myStatProperties].[unfiltered_rows] AS TableRows,'+
				@myNewLine + N'		[myStatProperties].[rows] AS StatRows,'+
				@myNewLine + N'		[myStatProperties].[modification_counter] AS ModifiedRows,'+
				@myNewLine + N'		CAST(CASE WHEN [myIndex].[object_id] IS NULL THEN 0 ELSE 1 END AS BIT) AS IsIndexRelated,'+
				@myNewLine + N'		ISNULL([myIndex].[is_disabled],0) AS IsIndexDisabled,'+
				@myNewLine + N'		CASE'+
				@myNewLine + N'			WHEN COALESCE([myStatProperties].[rows],[myStatProperties].[unfiltered_rows],0) + ISNULL([myStatProperties].[modification_counter],0) IS NULL THEN ''100 PERCENT'''+
				@myNewLine + N'			WHEN COALESCE([myStatProperties].[rows],[myStatProperties].[unfiltered_rows],0) + ISNULL([myStatProperties].[modification_counter],0) < 500000 THEN ''100 PERCENT'''+
				@myNewLine + N'			WHEN COALESCE([myStatProperties].[rows],[myStatProperties].[unfiltered_rows],0) + ISNULL([myStatProperties].[modification_counter],0) < 1000000 THEN ''50 PERCENT'''+
				@myNewLine + N'			WHEN COALESCE([myStatProperties].[rows],[myStatProperties].[unfiltered_rows],0) + ISNULL([myStatProperties].[modification_counter],0) < 5000000 THEN ''25 PERCENT'''+
				@myNewLine + N'			WHEN COALESCE([myStatProperties].[rows],[myStatProperties].[unfiltered_rows],0) + ISNULL([myStatProperties].[modification_counter],0) < 10000000 THEN ''10 PERCENT'''+
				@myNewLine + N'			WHEN COALESCE([myStatProperties].[rows],[myStatProperties].[unfiltered_rows],0) + ISNULL([myStatProperties].[modification_counter],0) < 50000000 THEN ''2 PERCENT'''+
				@myNewLine + N'			WHEN COALESCE([myStatProperties].[rows],[myStatProperties].[unfiltered_rows],0) + ISNULL([myStatProperties].[modification_counter],0) < 100000000 THEN ''1 PERCENT'''+
				@myNewLine + N'			ELSE ''3000000 ROWS'''+
				@myNewLine + N'		END AS SampleValue'+
				@myNewLine + N'	FROM'+
				@myNewLine + N'		[sys].[stats] AS myStatList'+
				@myNewLine + N'		INNER JOIN [sys].[all_objects] AS myObjects ON [myObjects].[object_id] = [myStatList].[object_id]'+
				@myNewLine + N'		INNER JOIN [sys].[schemas] AS mySchema ON [mySchema].[schema_id] = [myObjects].[schema_id]'+
				@myNewLine + N'		LEFT OUTER JOIN [sys].[indexes] AS myIndex ON [myIndex].[object_id] = [myStatList].[object_id] AND [myIndex].[name] = [myStatList].[name]'+
				@myNewLine + N'		CROSS APPLY [sys].[dm_db_stats_properties]([myStatList].[object_id],[myStatList].[stats_id]) AS myStatProperties'+
				@myNewLine + N'	WHERE'+
				@myNewLine + N'		[myObjects].[is_ms_shipped]=0																				-- Only application indexes'+
				@myNewLine + N'		AND ([myStatProperties].[rows]>100 /*OR [myStatProperties].[rows] IS NULL*/)								-- Only indexes with at least 100 rows'+
				@myNewLine + N'		AND ([myStatProperties].[modification_counter]>0 /*OR [myStatProperties].[modification_counter] IS NULL*/)	-- Only indexes with changed data'+
				CASE WHEN UPPER(@FilterTables) <> '<ALL_TABLES>' THEN
					@myNewLine + N'		AND (QUOTENAME(DB_NAME())+''.''+QUOTENAME([mySchema].[name])+''.''+QUOTENAME([myObjects].[name]) IN ('''+CAST(REPLACE(@FilterTables,',',''',''') AS NVARCHAR(MAX))+'''))	-- Only Specified Tables are selected'
				ELSE CAST(N'' AS NVARCHAR(MAX)) END +
				@myNewLine + N'	) AS myStatData'+
				@myNewLine + N'WHERE'+
				@myNewLine + N'	[myStatData].[IsIndexDisabled]=0																				-- Dont touch to stats related to disabled indexes'+
				@myNewLine + N'	AND ('+
				@myNewLine + N'		[myStatData].[last_updated] IS NULL '+
				@myNewLine + N'		OR '+
				@myNewLine + N'		[myStatData].[last_updated] BETWEEN DATEADD(DAY,@myUnusedStatTresholdInDays,@myToday) AND DATEADD(HOUR,@myIgnoreStatsUpdatedInLastXHours,@myToday)'+
				@myNewLine + N'		)																										-- Update stats that updated recently but not too recently or completed new stats'+
				CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'/*' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Comment execution
				@myNewLine+ N'DECLARE @myCursor Cursor;'+
				@myNewLine+ N'DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N''+
				@myNewLine+ N'SET @myCursor=CURSOR For'+
				@myNewLine+	N'	SELECT SQLStatement FROM #StatCommands;'+
				@myNewLine+ N''+
				@myNewLine+ N'PRINT ''Current database is '+ @Database_Name + N''';' +
				@myNewLine+ N'Open @myCursor'+
				@myNewLine+ N'	FETCH NEXT FROM @myCursor INTO @mySQLStatement'+
				@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
				@myNewLine+ N'		BEGIN'+
				@myNewLine+ N'			BEGIN TRY'+
				@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + @mySQLStatement;'+
				@myNewLine+ N'					EXEC (@mySQLStatement);'+
				@myNewLine+ N'			END TRY'+
				@myNewLine+ N'			BEGIN CATCH'+
				@myNewLine+ N'				DECLARE @CustomMessage1 nvarchar(255)'+
				@myNewLine+ N'				SET @CustomMessage1=''Update statistics error on '+@Database_Name+N'''' +
				@myNewLine+ N'				EXECUTE ' + CAST(QUOTENAME(DB_NAME()) AS NVARCHAR(MAX)) + N'.[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
				@myNewLine+ N'			END CATCH'+
				@myNewLine+ N''+
				@myNewLine+ N'			FETCH NEXT FROM @myCursor INTO @mySQLStatement'+
				@myNewLine+ N'		END '+
				@myNewLine+ N'CLOSE @myCursor; '+
				@myNewLine+ N'DEALLOCATE @myCursor; '+
				@myNewLine+ N''+
				CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'*/' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Comment execution
				CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'SELECT * FROM #StatCommands;' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Return commands list
				@myNewLine+	N'DROP TABLE #StatCommands;'
				AS NVARCHAR(MAX))

			EXEC [dbo].[dbasp_print_text] @mySQLScript;
			--==========Start to Update
			BEGIN TRY
				EXECUTE (@mySQLScript);
			END TRY
			BEGIN CATCH
				DECLARE @CustomMessage nvarchar(255)
				SET @CustomMessage='Update Statistics Error on ' + @Database_Name
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
			END CATCH
			--==========End of Update
			Print (@Database_Name + ' statistics updated on ' + cast(getdate() as nvarchar(50)));
			Print (Replicate('=',75));
			FETCH NEXT FROM @myCursor INTO @Database_Name
		END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_updatestatistics', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_updatestatistics', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2023-04-23', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_updatestatistics', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.1.1', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_updatestatistics', NULL, NULL
GO
