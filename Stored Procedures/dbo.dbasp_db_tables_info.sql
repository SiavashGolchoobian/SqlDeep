SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <4/7/2019>
-- Version:		<3.0.0.0>
-- Description:	<Get information about databases tables>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_db_tables_info] 
(
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@PrintOnly BIT=1
)
AS
	SET NOCOUNT ON;
	--=====Internal Parameters
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @Database_ID INT;
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myTables TABLE (ObjectId INT NOT NULL PRIMARY KEY, DatabaseName NVARCHAR(128) NOT NULL, SchemaName NVARCHAR(128) NOT NULL, TableName NVARCHAR(128) NOT NULL,
							TableColumns NVARCHAR(MAX) NOT NULL, HasPrimaryKey BIT, HasUniqueConstraint BIT, HasUniueIndex BIT, HasIdentity BIT, 
							HasRowGuidCol BIT, HasFilestream BIT, HasSparesColumn BIT, HasLOB BIT, PrimaryKeyColumnName NVARCHAR(MAX),
							UniqueConstraintColumnName NVARCHAR(MAX), UniqueIndexColumnName NVARCHAR(MAX), IdentityColumName NVARCHAR(128),
							RowGuidColumnName NVARCHAR(128), FilestramColumnName NVARCHAR(128), SparesColumnName NVARCHAR(128), 
							TableOrder INT NOT NULL DEFAULT(9999), FullTableName NVARCHAR(261))

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
			@myNewLine+ N'CREATE TABLE #myTablesOrder (ObjectId INT NOT NULL PRIMARY KEY, TableOrder INT NOT NULL)'+
			@myNewLine+ N'CREATE TABLE #myTables (ObjectId INT NOT NULL PRIMARY KEY, DatabaseName NVARCHAR(128) NOT NULL, SchemaName NVARCHAR(128) NOT NULL, TableName NVARCHAR(128) NOT NULL,'+
			@myNewLine+ N'						TableColumns NVARCHAR(MAX) NOT NULL, HasPrimaryKey BIT, HasUniqueConstraint BIT, HasUniueIndex BIT, HasIdentity BIT, '+
			@myNewLine+ N'						HasRowGuidCol BIT, HasFilestream BIT, HasSparesColumn BIT, HasLOB BIT, PrimaryKeyColumnName NVARCHAR(MAX),'+
			@myNewLine+ N'						UniqueConstraintColumnName NVARCHAR(MAX), UniqueIndexColumnName NVARCHAR(MAX), IdentityColumName NVARCHAR(128),'+
			@myNewLine+ N'						RowGuidColumnName NVARCHAR(128), FilestramColumnName NVARCHAR(128), SparesColumnName NVARCHAR(128), '+
			@myNewLine+ N'						TableOrder INT NOT NULL DEFAULT(9999), FullTableName AS (CAST(QUOTENAME(SchemaName)+N''.''+QUOTENAME(TableName) AS NVARCHAR(261))))'+
			@myNewLine+ N''+
			@myNewLine+ N'--=====================Extract Tables Dependency by FKs'+
			@myNewLine+ N';WITH myTableRelations AS ('+
			@myNewLine+ N'	SELECT'+
			@myNewLine+ N'		[myFk].[referenced_object_id] AS MasterObject,'+
			@myNewLine+ N'		[myFk].[parent_object_id] AS SlaveObject'+
			@myNewLine+ N'	FROM'+
			@myNewLine+ N'		sys.[foreign_keys] AS myFk'+
			@myNewLine+ N'	WHERE'+
			@myNewLine+ N'		[myFk].[referenced_object_id] != [myFk].[parent_object_id]'+
			@myNewLine+ N') ,'+
			@myNewLine+ N'myTableDependencies AS ('+
			@myNewLine+ N'	SELECT'+
			@myNewLine+ N'		[myTables].[object_id],'+
			@myNewLine+ N'		0 AS DependencyLevel'+
			@myNewLine+ N'	FROM'+
			@myNewLine+ N'		sys.[all_objects] AS myTables'+
			@myNewLine+ N'		LEFT OUTER JOIN [myTableRelations] ON [myTables].[object_id]=[myTableRelations].[SlaveObject]'+
			@myNewLine+ N'	WHERE'+
			@myNewLine+ N'		[myTables].[type]=''U'''+
			@myNewLine+ N'		AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+ N'		AND [myTableRelations].[SlaveObject] IS NULL'+
			@myNewLine+ N'	UNION ALL'+
			@myNewLine+ N'	SELECT'+
			@myNewLine+ N'		[myTableRelations].[SlaveObject],'+
			@myNewLine+ N'		[myTableDependencies].[DependencyLevel] + 1 AS [DependencyLevel]'+
			@myNewLine+ N'	FROM'+
			@myNewLine+ N'		[myTableRelations]'+
			@myNewLine+ N'		INNER JOIN [myTableDependencies] ON [myTableDependencies].[object_id]=[myTableRelations].[MasterObject]'+
			@myNewLine+ N')'+
			@myNewLine+ N'INSERT INTO [#myTablesOrder] ([ObjectId], [TableOrder])'+
			@myNewLine+ N'SELECT'+
			@myNewLine+ N'	[myTableDependencies].[object_id],'+
			@myNewLine+ N'	MAX([myTableDependencies].[DependencyLevel]) AS [DependencyLevel]'+
			@myNewLine+ N'FROM'+
			@myNewLine+ N'	[myTableDependencies]'+
			@myNewLine+ N'GROUP BY'+
			@myNewLine+ N'	[myTableDependencies].[object_id]'+
			@myNewLine+ N'ORDER BY'+
			@myNewLine+ N'	MAX([myTableDependencies].[DependencyLevel])'+
			@myNewLine+ N'--=====================Extract Tables Information'+
			@myNewLine+ N'INSERT INTO #myTables (ObjectId, DatabaseName, SchemaName, TableName, TableColumns,HasPrimaryKey,HasUniqueConstraint,HasUniueIndex,HasIdentity,HasRowGuidCol,HasFilestream,HasSparesColumn,HasLOB,PrimaryKeyColumnName,UniqueConstraintColumnName,UniqueIndexColumnName,IdentityColumName,RowGuidColumnName,FilestramColumnName,SparesColumnName,[TableOrder])'+
			@myNewLine+ N'SELECT'+
			@myNewLine+ N'	myTable.object_id,'+
			@myNewLine+ N'	DB_NAME() AS DatabaseName,'+
			@myNewLine+ N'	mySchema.name AS SchemaName,'+
			@myNewLine+ N'	myTable.name AS TableName,'+
			@myNewLine+ N'	STUFF((SELECT '','' + myColumns.name FROM sys.all_columns AS myColumns WHERE myColumns.object_id = myTable.object_id ORDER BY myColumns.column_id FOR XML PATH ('''')), 1, 1, '''') AS TableColumns,'+
			@myNewLine+ N'	CAST(myPKUNQUQIX.HasPrimaryKey AS BIT) AS HasPrimaryKey,'+
			@myNewLine+ N'	CAST(myPKUNQUQIX.HasUniqueConstraint AS BIT) AS HasUniqueConstraint,'+
			@myNewLine+ N'	CAST(myPKUNQUQIX.HasUniqueIndex AS BIT) AS HasUniqueIndex,'+
			@myNewLine+ N'	CAST(myColumnInfo01.HasIdentity AS BIT) AS HasIdentity,'+
			@myNewLine+ N'	CAST(myColumnInfo01.HasRowGuidCol AS BIT) AS HasRowGuidCol,'+
			@myNewLine+ N'	CAST(myColumnInfo01.HasFilestream AS BIT)AS HasFilestream,'+
			@myNewLine+ N'	CAST(myColumnInfo01.HasSparesColumn AS BIT) AS HasSparesColumn,'+
			@myNewLine+ N'	CASE myLobColumns.object_id WHEN 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS HasLOB,'+
			@myNewLine+ N'	myPKColumns.PKColumns AS PrimaryKeyColumnName,'+
			@myNewLine+ N'	myUQColumns.UQColumns AS UniqueConstraintColumnName,'+
			@myNewLine+ N'	myUQIXColumns.UQIXColumns AS UniqueIndexColumnName,'+
			@myNewLine+ N'	myColumnInfo01.IdentityColumName,'+
			@myNewLine+ N'	myColumnInfo01.RowGuidColumnName,'+
			@myNewLine+ N'	myColumnInfo01.FilestramColumnName,'+
			@myNewLine+ N'	myColumnInfo01.SparesColumnName,'+
			@myNewLine+ N'	[myTableOrder].[TableOrder]'+
			@myNewLine+ N'FROM'+
			@myNewLine+ N'	sys.all_objects AS myTable'+
			@myNewLine+ N'	INNER JOIN sys.schemas AS mySchema ON mySchema.schema_id = myTable.schema_id'+
			@myNewLine+ N'	INNER JOIN [#myTablesOrder] AS myTableOrder ON [myTable].[object_id]=[myTableOrder].[ObjectId]'+
			@myNewLine+ N'	LEFT OUTER JOIN '+
			@myNewLine+ N'			('+
			@myNewLine+ N'			SELECT '+
			@myNewLine+ N'				myColumns.object_id,'+
			@myNewLine+ N'				MAX(CAST(myColumns.is_rowguidcol AS TINYINT)) AS HasRowGuidCol,'+
			@myNewLine+ N'				MAX(CASE WHEN myColumns.is_rowguidcol=1 THEN myColumns.name END) AS RowGuidColumnName,'+
			@myNewLine+ N'				MAX(CAST(myColumns.is_identity AS TINYINT)) AS HasIdentity,'+
			@myNewLine+ N'				MAX(CASE WHEN myColumns.is_identity=1 THEN myColumns.name END) AS IdentityColumName,'+
			@myNewLine+ N'				MAX(CAST(myColumns.is_filestream AS TINYINT)) AS HasFilestream,'+
			@myNewLine+ N'				MAX(CASE WHEN myColumns.is_filestream=1 THEN myColumns.name END) AS FilestramColumnName,'+
			@myNewLine+ N'				MAX(CAST(myColumns.is_sparse AS TINYINT)) AS HasSparesColumn,'+
			@myNewLine+ N'				MAX(CASE WHEN myColumns.is_sparse=1 THEN myColumns.name END) AS SparesColumnName'+
			@myNewLine+ N'			FROM '+
			@myNewLine+ N'				sys.all_columns AS myColumns'+
			@myNewLine+ N'				INNER JOIN sys.[types] AS myDataType ON [myColumns].[system_type_id]=[myDataType].[user_type_id]'+
			@myNewLine+ N'			GROUP BY'+
			@myNewLine+ N'				myColumns.object_id'+
			@myNewLine+ N'			) AS myColumnInfo01 ON myColumnInfo01.object_id = myTable.object_id'+
			@myNewLine+ N'	LEFT OUTER JOIN'+
			@myNewLine+ N'			('+
			@myNewLine+ N'			SELECT'+
			@myNewLine+ N'				[myObjects].[object_id]'+
			@myNewLine+ N'			FROM'+
			@myNewLine+ N'				sys.allocation_units as myAllocationUnits'+
			@myNewLine+ N'				inner join sys.partitions as myPartition on myPartition.partition_id=myAllocationUnits.container_id'+
			@myNewLine+ N'				inner join sys.indexes as myIndex on myPartition.object_id=myIndex.object_id and myPartition.index_id=myIndex.index_id'+
			@myNewLine+ N'				inner join sys.all_objects as myObjects on myIndex.object_id=myObjects.object_id'+
			@myNewLine+ N'			WHERE'+
			@myNewLine+ N'				myAllocationUnits.type = 2	--LOB data'+
			@myNewLine+ N'			GROUP BY'+
			@myNewLine+ N'				myObjects.object_id'+
			@myNewLine+ N'			) AS myLobColumns ON myLobColumns.object_id = myTable.object_id'+
			@myNewLine+ N'	LEFT OUTER JOIN'+
			@myNewLine+ N'			('+
			@myNewLine+ N'			SELECT'+
			@myNewLine+ N'				myIndex.object_id,'+
			@myNewLine+ N'				MAX(CAST(myIndex.is_primary_key AS TINYINT)) AS HasPrimaryKey,'+
			@myNewLine+ N'				MAX(CAST(myIndex.is_unique_constraint AS TINYINT)) AS HasUniqueConstraint,'+
			@myNewLine+ N'				MAX(CASE WHEN myIndex.filter_definition IS NULL AND myIndex.is_primary_key=0 AND myIndex.is_unique_constraint=0 AND myIndex.is_unique=1 THEN CAST(myIndex.is_unique AS TINYINT) ELSE CAST(0 AS BIT) END) AS HasUniqueIndex'+
			@myNewLine+ N'			FROM'+
			@myNewLine+ N'				sys.indexes AS myIndex'+
			@myNewLine+ N'			WHERE'+
			@myNewLine+ N'				myIndex.is_disabled=0'+
			@myNewLine+ N'			GROUP BY'+
			@myNewLine+ N'				myIndex.object_id'+
			@myNewLine+ N'			) AS myPKUNQUQIX ON myPKUNQUQIX.object_id = myTable.object_id'+
			@myNewLine+ N'	LEFT OUTER JOIN '+
			@myNewLine+ N'			('+
			@myNewLine+ N'			SELECT '+
			@myNewLine+ N'				myConstraints.parent_object_id AS [object_id],'+
			@myNewLine+ N'				STUFF((SELECT '','' + myColumns.name FROM sys.index_columns AS myIndexColumns INNER JOIN sys.columns AS myColumns ON myColumns.object_id = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id WHERE myIndexColumns.object_id = myConstraints.parent_object_id AND myIndexColumns.index_id=myConstraints.unique_index_id ORDER BY myIndexColumns.index_column_id FOR XML PATH ('''')), 1, 1, '''') AS PKColumns'+
			@myNewLine+ N'			FROM '+
			@myNewLine+ N'				sys.key_constraints AS myConstraints '+
			@myNewLine+ N'			WHERE '+
			@myNewLine+ N'				myConstraints.[type] = ''PK'''+
			@myNewLine+ N'				AND myConstraints.is_enforced=1'+
			@myNewLine+ N'			) AS myPKColumns ON myPKColumns.object_id = myTable.object_id'+
			@myNewLine+ N'	LEFT OUTER JOIN '+
			@myNewLine+ N'			('+
			@myNewLine+ N'			SELECT'+
			@myNewLine+ N'				myUQSeries.object_id,'+
			@myNewLine+ N'				MIN(myUQSeries.UQColumns) AS UQColumns'+
			@myNewLine+ N'			FROM'+
			@myNewLine+ N'				('+
			@myNewLine+ N'				SELECT '+
			@myNewLine+ N'					myConstraints.parent_object_id AS [object_id],'+
			@myNewLine+ N'					STUFF((SELECT '','' + myColumns.name FROM sys.index_columns AS myIndexColumns INNER JOIN sys.columns AS myColumns ON myColumns.object_id = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id WHERE myIndexColumns.object_id = myConstraints.parent_object_id AND myIndexColumns.index_id=myConstraints.unique_index_id ORDER BY myIndexColumns.index_column_id FOR XML PATH ('''')), 1, 1, '''') AS UQColumns'+
			@myNewLine+ N'				FROM '+
			@myNewLine+ N'					sys.key_constraints AS myConstraints '+
			@myNewLine+ N'				WHERE '+
			@myNewLine+ N'					myConstraints.[type] = ''UQ'''+
			@myNewLine+ N'					AND myConstraints.is_enforced=1'+
			@myNewLine+ N'				) AS myUQSeries'+
			@myNewLine+ N'			GROUP BY'+
			@myNewLine+ N'				myUQSeries.object_id'+
			@myNewLine+ N'			) AS myUQColumns ON myUQColumns.object_id = myTable.object_id'+
			@myNewLine+ N'	LEFT OUTER JOIN'+
			@myNewLine+ N'			('+
			@myNewLine+ N'			SELECT'+
			@myNewLine+ N'				myUQIXSeries.object_id,'+
			@myNewLine+ N'				MIN(myUQIXSeries.UQIXColumns) AS UQIXColumns'+
			@myNewLine+ N'			FROM'+
			@myNewLine+ N'				('+
			@myNewLine+ N'				SELECT'+
			@myNewLine+ N'					myIndex.object_id,'+
			@myNewLine+ N'					STUFF((SELECT '','' + myColumns.name FROM sys.index_columns AS myIndexColumns INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id WHERE myIndexColumns.[object_id]=myIndex.object_id AND myIndexColumns.index_id=myIndex.index_id ORDER BY myIndexColumns.index_column_id FOR XML PATH ('''')), 1, 1, '''') AS UQIXColumns'+
			@myNewLine+ N'				FROM'+
			@myNewLine+ N'					sys.indexes AS myIndex'+
			@myNewLine+ N'				WHERE'+
			@myNewLine+ N'					myIndex.is_disabled=0'+
			@myNewLine+ N'					AND myIndex.is_primary_key=0'+
			@myNewLine+ N'					AND myIndex.is_unique_constraint=0'+
			@myNewLine+ N'					AND myIndex.is_unique=1'+
			@myNewLine+ N'					AND myIndex.filter_definition IS NULL'+
			@myNewLine+ N'				) AS myUQIXSeries'+
			@myNewLine+ N'			GROUP BY'+
			@myNewLine+ N'				myUQIXSeries.object_id'+
			@myNewLine+ N'			) AS myUQIXColumns ON myUQIXColumns.object_id = myTable.object_id'+
			@myNewLine+ N'WHERE'+
			@myNewLine+ N'	myTable.type=''U'''+
			@myNewLine+ N'	AND myTable.is_ms_shipped=0'+
			@myNewLine+ N''+
			@myNewLine+ N'SELECT '+
			@myNewLine+ N'	* '+
			@myNewLine+ N'FROM '+
			@myNewLine+ N'	#myTables'+
			@myNewLine+ N'ORDER BY'+
			@myNewLine+ N'	[TableOrder]'+
			@myNewLine+ N''+
			@myNewLine+ N'DROP TABLE [#myTablesOrder]'+
			@myNewLine+ N'DROP TABLE [#myTables]'+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
		EXEC [dbo].[dbasp_print_text] @mySQLScript
		IF @PrintOnly=0
			PRINT (@myNewLine + '--Excexution Report--');

		--=======Start of executing commands
		BEGIN TRY
			INSERT INTO @myTables EXECUTE(@mySQLScript)
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
	SELECT * FROM @myTables ORDER BY [DatabaseName],[TableOrder]
	RETURN
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_db_tables_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-04-07', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_db_tables_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-04-07', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_db_tables_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_db_tables_info', NULL, NULL
GO
