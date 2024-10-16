SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <4/6/2019>
-- Version:		<3.0.0.1>
-- Description:	<Add rowversion_update_last_status SP to any specified databases, this sp help you to store max value of each table with rowversion column as offline in a single table, named [dbo].[rowversion_last_status]>
-- Input Parameters:
--	@DatabaseNames:						'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@PrintOnly:							0 or 1
-- =============================================

CREATE PROCEDURE [dbo].[dbasp_rowversion_add_metadata_objects] (
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@PrintOnly BIT=1
	)
AS 
BEGIN
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @Database_ID INT;
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);

	SET @myNewLine=CHAR(13)+CHAR(10)
    SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
		
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
	WHILE @@FETCH_STATUS=0
	BEGIN
		SELECT @Database_ID=database_id from sys.databases where name=@Database_Name
		
		--===============STEP01:	Create related tables
		SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ CAST(N'' AS NVARCHAR(MAX))+
			@myNewLine+ N'-- ============================================='+
			@myNewLine+ N'-- Author:		<Golchoobian>'+
			@myNewLine+ N'-- Create date: <4/9/2019>'+
			@myNewLine+ N'-- Version:		<3.0.0.1>'+
			@myNewLine+ N'-- Description:	<Add or Rename timestamp column with specified name to all tables>'+
			@myNewLine+ N'-- Input Parameters:'+
			@myNewLine+ N'--	@FullTableName:		''Null or Fully quilified name of a table'+
			@myNewLine+ N'-- ============================================='+
			@myNewLine+ N''+
			@myNewLine+ N'CREATE PROCEDURE [dbo].[rowversion_update_last_status]'+
			@myNewLine+ N'('+
			@myNewLine+ N'	@FullTableName NVARCHAR(261)=NULL'+
			@myNewLine+ N')'+
			@myNewLine+ N'AS'+
			@myNewLine+ N'BEGIN'+
			@myNewLine+ N'	DECLARE @CandidateObjects TABLE('+
			@myNewLine+ N'		[SchemaName] [nvarchar](128) NOT NULL,'+
			@myNewLine+ N'		[TableName] [nvarchar](128) NOT NULL,'+
			@myNewLine+ N'		[RowVersion_ColumnName] [nvarchar](128) NOT NULL,'+
			@myNewLine+ N'		[TableOrder] INT DEFAULT(9999) NOT NULL,'+
			@myNewLine+ N'		[CalcCommand] NVARCHAR(MAX) NOT NULL'+
			@myNewLine+ N'		)'+
			@myNewLine+ N''+
			@myNewLine+ N'	--Check Parameters'+
			@myNewLine+ N'	IF LEN(ISNULL(@FullTableName,N''''))=0'+
			@myNewLine+ N'		SET @FullTableName=NULL'+
			@myNewLine+ N''+
			@myNewLine+ N'	--Check Meta table existance'+
			@myNewLine+ N'	IF OBJECT_ID(''dbo.rowversion_last_status'') IS NULL'+
			@myNewLine+ N'	BEGIN'+
			@myNewLine+ N'		CREATE TABLE [dbo].[rowversion_last_status]('+
			@myNewLine+ N'			RecordId INT IDENTITY PRIMARY KEY,'+
			@myNewLine+ N'			SchemaName NVARCHAR(128) NOT NULL,'+
			@myNewLine+ N'			TableName NVARCHAR(128) NOT NULL,'+
			@myNewLine+ N'			TableOrder INT DEFAULT(9999) NOT NULL,'+
			@myNewLine+ N'			FullTableName AS (CAST((QUOTENAME(SchemaName) + N''.'' + QUOTENAME(TableName)) AS NVARCHAR(261))),'+
			@myNewLine+ N'			LastRowVersionValue BINARY(8),'+
			@myNewLine+ N'			LastUpdate DATETIME DEFAULT(GETDATE()) NOT NULL,'+
			@myNewLine+ N'			CONSTRAINT [UNQ_Record] UNIQUE NONCLUSTERED ([SchemaName] ASC,[TableName] ASC)'+
			@myNewLine+ N'			)'+
			@myNewLine+ N'	END'+
			@myNewLine+ N''+
			@myNewLine+ N'	--=====================Extract Tables Dependency by FKs'+
			@myNewLine+ N'	;WITH myTableRelations AS ('+
			@myNewLine+ N'		SELECT'+
			@myNewLine+ N'			[myFk].[referenced_object_id] AS MasterObject,'+
			@myNewLine+ N'			[myFk].[parent_object_id] AS SlaveObject'+
			@myNewLine+ N'		FROM'+
			@myNewLine+ N'			sys.[foreign_keys] AS myFk'+
			@myNewLine+ N'		WHERE'+
			@myNewLine+ N'			[myFk].[referenced_object_id] != [myFk].[parent_object_id]'+
			@myNewLine+ N'	) ,'+
			@myNewLine+ N'	myTableDependencies AS ('+
			@myNewLine+ N'		SELECT'+
			@myNewLine+ N'			[myTables].[object_id],'+
			@myNewLine+ N'			0 AS DependencyLevel'+
			@myNewLine+ N'		FROM'+
			@myNewLine+ N'			sys.[all_objects] AS myTables'+
			@myNewLine+ N'			LEFT OUTER JOIN [myTableRelations] ON [myTables].[object_id]=[myTableRelations].[SlaveObject]'+
			@myNewLine+ N'		WHERE'+
			@myNewLine+ N'			[myTables].[type]=''U'''+
			@myNewLine+ N'			AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+ N'			AND [myTableRelations].[SlaveObject] IS NULL'+
			@myNewLine+ N'		UNION ALL'+
			@myNewLine+ N'		SELECT'+
			@myNewLine+ N'			[myTableRelations].[SlaveObject],'+
			@myNewLine+ N'			[myTableDependencies].[DependencyLevel] + 1 AS [DependencyLevel]'+
			@myNewLine+ N'		FROM'+
			@myNewLine+ N'			[myTableRelations]'+
			@myNewLine+ N'			INNER JOIN [myTableDependencies] ON [myTableDependencies].[object_id]=[myTableRelations].[MasterObject]'+
			@myNewLine+ N'	)'+
			@myNewLine+ N''+
			@myNewLine+ N'	--Extract Candidate tables and last rowversion calculatuion command'+
			@myNewLine+ N'	INSERT INTO @CandidateObjects ([SchemaName], [TableName], [RowVersion_ColumnName], [CalcCommand], [TableOrder])'+
			@myNewLine+ N'	SELECT'+
			@myNewLine+ N'		[mySchema].[name] AS SchemaName,'+
			@myNewLine+ N'		[myTables].[name] AS TableName,'+
			@myNewLine+ N'		[myColumns].[name] AS RowVersion_ColumnName,'+
			@myNewLine+ N'		N''SELECT @myRowVersionValue=MAX('' + CAST(QUOTENAME([myColumns].[name]) AS NVARCHAR(MAX)) + N'') FROM '' + QUOTENAME([mySchema].[name])+N''.''+QUOTENAME([myTables].[name])+N'' WHERE '' + QUOTENAME([myColumns].[name]) + N'' >= ISNULL((SELECT MAX([LastRowVersionValue]) FROM [dbo].[rowversion_last_status] WHERE FullTableName=N'''''' + QUOTENAME([mySchema].[name])+N''.''+QUOTENAME([myTables].[name]) + ''''''),0)'','+
			@myNewLine+ N'		[myTableOrder].[DependencyLevel]'+
			@myNewLine+ N'	FROM'+
			@myNewLine+ N'		sys.[all_objects] AS myTables'+
			@myNewLine+ N'		INNER JOIN sys.[schemas] AS mySchema ON [mySchema].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+ N'		INNER JOIN sys.[all_columns] AS myColumns ON [myColumns].[object_id] = [myTables].[object_id]'+
			@myNewLine+ N'		INNER JOIN sys.[types] AS myTypes ON [myColumns].[system_type_id]=[myTypes].[user_type_id]'+
			@myNewLine+ N'		INNER JOIN'+
			@myNewLine+ N'			('+
			@myNewLine+ N'			SELECT'+
			@myNewLine+ N'				[myTableDependencies].[object_id],'+
			@myNewLine+ N'				MAX([myTableDependencies].[DependencyLevel]) AS [DependencyLevel]'+
			@myNewLine+ N'			FROM'+
			@myNewLine+ N'				[myTableDependencies]'+
			@myNewLine+ N'			GROUP BY'+
			@myNewLine+ N'				[myTableDependencies].[object_id]'+
			@myNewLine+ N'			) AS myTableOrder ON [myTableOrder].[object_id] = [myTables].[object_id]'+
			@myNewLine+ N'		LEFT OUTER JOIN '+
			@myNewLine+ N'			('+
			@myNewLine+ N'			SELECT'+
			@myNewLine+ N'				[myLastStat].[SchemaName],'+
			@myNewLine+ N'				[myLastStat].[TableName],'+
			@myNewLine+ N'				MAX([myLastStat].[LastRowVersionValue]) AS [LastRowVersionValue]'+
			@myNewLine+ N'			FROM'+
			@myNewLine+ N'				[dbo].[rowversion_last_status] AS myLastStat'+
			@myNewLine+ N'			GROUP BY'+
			@myNewLine+ N'				[myLastStat].[SchemaName],'+
			@myNewLine+ N'				[myLastStat].[TableName]'+
			@myNewLine+ N'			) AS myLastStatus ON [mySchema].[name]=[myLastStatus].[SchemaName] AND [myTables].[name]=[myLastStatus].[TableName]'+
			@myNewLine+ N'	WHERE'+
			@myNewLine+ N'		[myTables].[type]=''U'''+
			@myNewLine+ N'		AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+ N'		AND [myTypes].[name]=''timestamp'''+
			@myNewLine+ N'		AND ('+
			@myNewLine+ N'				(@FullTableName IS NOT NULL AND QUOTENAME([mySchema].[name])+N''.''+QUOTENAME([myTables].[name])=@FullTableName)'+
			@myNewLine+ N'				OR'+
			@myNewLine+ N'				(@FullTableName IS NULL)'+
			@myNewLine+ N'			)'+
			@myNewLine+ N''+
			@myNewLine+ N'	--Itterate through candidate tables'+
			@myNewLine+ N'	DECLARE @mySchemaName NVARCHAR(128)'+
			@myNewLine+ N'	DECLARE @myTableName NVARCHAR(128)'+
			@myNewLine+ N'	DECLARE @myRowVersionValue BINARY(8)'+
			@myNewLine+ N'	DECLARE @myTableOrder INT'+
			@myNewLine+ N'	DECLARE @myCursor Cursor;'+
			@myNewLine+ N'	DECLARE @mySQLScript NVARCHAR(max);'+
			@myNewLine+ N'    SET @myCursor=CURSOR For'+
			@myNewLine+ N'		Select [SchemaName],[TableName],[CalcCommand],[TableOrder] FROM @CandidateObjects ORDER BY [TableOrder] DESC'+
			@myNewLine+ N'		'+
			@myNewLine+ N'	Open @myCursor'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor INTO @mySchemaName,@myTableName,@mySQLScript,@myTableOrder'+
			@myNewLine+ N'	WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'	BEGIN'+
			@myNewLine+ N'		--=====Execute calc command'+
			@myNewLine+ N'		BEGIN TRY'+
			@myNewLine+ N'			PRINT @mySQLScript'+
			@myNewLine+ N'			SET @myRowVersionValue=NULL'+
			@myNewLine+ N'			EXEC sp_executesql @mySQLScript, N''@myRowVersionValue BINARY(8) OUTPUT'', @myRowVersionValue = @myRowVersionValue OUTPUT'+
			@myNewLine+ N''+
			@myNewLine+ N'			--Updating data in dbo.rowversion_last_status table'+
			@myNewLine+ N'			MERGE [dbo].[rowversion_last_status] AS target'+
			@myNewLine+ N'			USING (SELECT @mySchemaName AS SchemaName, @myTableName AS TableName, @myRowVersionValue AS RowVersionValue, @myTableOrder AS TableOrder) AS source '+
			@myNewLine+ N'			ON [target].[SchemaName] = source.[SchemaName] AND [target].[TableName]=[source].[TableName]'+
			@myNewLine+ N'			WHEN MATCHED --AND ISNULL(target.[LastRowVersionValue],0)<>ISNULL(source.[RowVersionValue],0)'+
			@myNewLine+ N'				THEN UPDATE SET '+
			@myNewLine+ N'					[target].[LastRowVersionValue] = source.[RowVersionValue], '+
			@myNewLine+ N'					[target].[TableOrder]=[source].[TableOrder], '+
			@myNewLine+ N'					[target].[LastUpdate]=GETDATE()'+
			@myNewLine+ N'			WHEN NOT MATCHED '+
			@myNewLine+ N'				THEN INSERT ([SchemaName], [TableName], [LastRowVersionValue], [TableOrder], [LastUpdate])'+
			@myNewLine+ N'				VALUES(source.[SchemaName], [source].[TableName], [source].[RowVersionValue], [source].[TableOrder], GETDATE())'+
			@myNewLine+ N'			;'+
			@myNewLine+ N'		END TRY'+
			@myNewLine+ N'		BEGIN CATCH'+
			@myNewLine+ N'			PRINT N''Error on calculating Max of Rowversion on '' + @mySchemaName + N''.'' + @myTableName + N'' :'' + @mySQLScript'+
			@myNewLine+ N'		END CATCH'+
			@myNewLine+ N'		--====='+
			@myNewLine+ N'		FETCH NEXT FROM @myCursor INTO @mySchemaName,@myTableName,@mySQLScript,@myTableOrder'+
			@myNewLine+ N'	END'+
			@myNewLine+ N'	CLOSE @myCursor;'+
			@myNewLine+ N'	DEALLOCATE @myCursor;'+
			@myNewLine+ N'END'+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
			SET @mySQLScript='EXEC ' + QUOTENAME(@Database_Name) +'..sp_executesql N''' + REPLACE(@mySQLScript,'''','''''') + ''''
		--===============STEP02:	Create related procedures

		EXEC [dbo].[dbasp_print_text] @mySQLScript
		--=======Start of executing commands
		IF @PrintOnly=0
		BEGIN
			BEGIN TRY
				EXEC [dbo].[dbasp_print_text] @mySQLScript
				EXECUTE (@mySQLScript);
			END TRY
			BEGIN CATCH
				DECLARE @CustomMessage1 NVARCHAR(255)
				SET @CustomMessage1='error on ' + @Database_Name
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
			END CATCH
		END
		--=======End of executing commands
		FETCH NEXT FROM @myCursor INTO @Database_Name
	END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_metadata_objects', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-04-06', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_metadata_objects', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-04-06', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_metadata_objects', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_rowversion_add_metadata_objects', NULL, NULL
GO
