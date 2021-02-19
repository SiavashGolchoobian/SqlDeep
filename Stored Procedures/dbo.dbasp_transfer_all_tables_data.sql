SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Siavash Golchoobian>
-- Create date: <6/20/2017>
-- Version:		<3.0.0.9>
-- Description:	<Transfer All table(s) data also if having foreign key constraints>
-- Input Parameters:
--	@SourceDatabaseName:				dbname1, Source Database as refrence for exporting data
--	@DestinationDatabaseName:			dbname1_clone, Destination Database for importing data
--	@DestinationDisableConstraintsMode:	'NONE','FK','PK','UQ','CHK','NCIX' or combination of them like 'FK,PK,UQ,NCIX,CHK' to disable FK's,PK's, Unique, Check and other constraints addition to non-clustered indexes for increasing load speed and also preventing integration errors
--	@DestinationDisableIdentity:		0 or 1, disable Identity columns for accepting source value
--	@DestinationDisableTriggers:		0 or 1, disable all triggers for increasing load speed
--	@DestinationRecoveryModel:			N'SIMPLE' or 'BULK' or NULL, set Destination db to simple,bulk or none recovery model for minimum log
--	@SourceChangeProtectionMethod:		'NONE','READ-ONLY', Set SourceDB to Read-only mode or use CDC in read-write mode for protecting DestinationDB against SourceDB changes
--	@UseSnapshotOfSourceDB:				0 or 1 (SET this parameter to 0 if your @SourceDatabaseName use filestream technology), use snapshot of source db for assuring data integration and consistency on source db for preventing any probability of integration errors on destination db and preventing source table from locking
--	@SnapshotFolder:					valid path for creating snapshot database files
--	@ThreadCount:						any positive integer (Normaly 1 x number of SQL CPU Cores to maximum 2 x number of SQL CPU Cores is best values but try to use less threads under 2x and near to 1x), !!! THIS OPTION ONLY WORKS in @PrintOnly=1 MODE !!! if this value above than 1, determine using sql server jobs in parallel to transfering data else it will use single thread
--	@BatchCount:						any positive integer (10.000 is prefered value but you should test higher values for best performance, dont use values less than 10.000 it will decrese performance deramatically), number of records transfered and commited by each select batch, any value less than or equal to zero resulted in single transaction insert !
--	@PumpDataByKeyOrder:				Bulkimport data by key table orders 1 for sorting source data before sending to dest and 0 for unawaring of source recordset ordering, this option has effect on dest table fragmentation and pagesplit, it's prefer to be 1 for tables that does not give time-out because of pre-ordering process
--	@ExceptedObjectIds:					list of object_id's should be excepted from data transfer, default is N''
--	@LoadMethod:						N'TSQL', 'CMD', 'POWERSHELL', CMD and POWERSHELL relies on dbatools powershell module from https://dbatools.io/
--	@PrintOnly:							0 or 1
--	https://docs.microsoft.com/en-us/previous-versions/sql/sql-server-2008/dd425070(v=sql.100)?redirectedfrom=MSDN
--	https://www.sqlshack.com/use-parallel-insert-sql-server-2016-improve-query-performance/
--	https://www.sqlbi.com/wp-content/uploads/SqlBulkCopy-Performance-1.0.pdf
--	https://dba.stackexchange.com/questions/165966/how-does-one-investigate-the-performance-of-a-bulk-insert-statement
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_transfer_all_tables_data]
	@SourceDatabaseName NVARCHAR(512) = N'SourceDB',
	@DestinationDatabaseName NVARCHAR(512) = N'DestDB',
	@DestinationDisableConstraintsMode NVARCHAR(50) = N'FK,CHK',	--N'FK,CHK,PK,UQ,NCIX',
	@DestinationDisableIdentity BIT = 1,
	@DestinationDisableTriggers BIT = 1,
	@DestinationRecoveryModel NVARCHAR(50) = N'SIMPLE',
	@SourceChangeProtectionMethod NVARCHAR(50) = N'READ-ONLY',
	@UseSnapshotOfSourceDB BIT = 1,
	@SnapshotFolder NVARCHAR(256) = NULL,
	@ThreadCount INT = 1,
	@BatchCount BIGINT = 10000,
	@PumpDataByKeyOrder BIT = 1,
	@ExceptedObjectIds NVARCHAR(MAX)=N'',
	@LoadMethod NVARCHAR(20)=N'TSQL',
	@PrintOnly BIT=1
AS
BEGIN
	SET NOCOUNT ON;
	--=====Internal Parameters
	DECLARE @myIsPrerequisitesPassed BIT;
	DECLARE @myMessage nvarchar(4000);
	DECLARE @Database_ID INT;
	DECLARE @Database_IsReadOnly bit;
	DECLARE @mySourceConsistentDatabase sysname;
	DECLARE @mySnapshotSuffix NVARCHAR(20);
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myDisable_FK BIT;
	DECLARE @myDisable_PK BIT;
	DECLARE @myDisable_UQ BIT;
	DECLARE @myDisable_CHK BIT;
	DECLARE @myDisable_NCIX BIT;
	DECLARE @myProtection_Readonly BIT;
	DECLARE @myLogTableName NVARCHAR(255);
	DECLARE @myPowershellDequeue NVARCHAR(MAX)
	DECLARE @myPartitioningInfoStandard NVARCHAR(512)
	--, IGNORE_CONSTRAINTS, IGNORE_TRIGGERS)
	--=====Parameters Initialization
	SET @myIsPrerequisitesPassed=1
	SET @DestinationDisableConstraintsMode=UPPER(REPLACE(@DestinationDisableConstraintsMode,N' ',N''))
	SET @myMessage=N''
	SET @mySnapshotSuffix=N'_Clone'
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
	SET @BatchCount=ISNULL(@BatchCount,0)
	SET @mySourceConsistentDatabase=CASE @UseSnapshotOfSourceDB WHEN 1 THEN @SourceDatabaseName + @mySnapshotSuffix ELSE @SourceDatabaseName END
	SET @myDisable_FK=CASE ISNULL(CHARINDEX(N'FK',@DestinationDisableConstraintsMode,0),0) WHEN 0 THEN 0 ELSE 1 END
	SET @myDisable_PK=CASE ISNULL(CHARINDEX(N'PK',@DestinationDisableConstraintsMode,0),0) WHEN 0 THEN 0 ELSE 1 END
	SET @myDisable_UQ=CASE ISNULL(CHARINDEX(N'UQ',@DestinationDisableConstraintsMode,0),0) WHEN 0 THEN 0 ELSE 1 END
	SET @myDisable_CHK=CASE ISNULL(CHARINDEX(N'CHK',@DestinationDisableConstraintsMode,0),0) WHEN 0 THEN 0 ELSE 1 END
	SET @myDisable_NCIX=CASE ISNULL(CHARINDEX(N'NCIX',@DestinationDisableConstraintsMode,0),0) WHEN 0 THEN 0 ELSE 1 END
	SET @myProtection_Readonly=CASE WHEN UPPER(@SourceChangeProtectionMethod)=N'READ-ONLY' THEN 1 ELSE 0 END
	SET @myLogTableName = QUOTENAME(@DestinationDatabaseName) + N'.[dbo].[tbl' + CAST(NEWID() AS NVARCHAR(255)) + N']'
	SET @ExceptedObjectIds = ISNULL(@ExceptedObjectIds,N'')
	SET @myPartitioningInfoStandard = @SourceDatabaseName
	--=====Prerequisites Control
	--Check Source db existance
	IF NOT EXISTS(SELECT 1 FROM sys.[databases] AS myDatabases WHERE myDatabases.[name]=@SourceDatabaseName)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myMessage=@myMessage + N'@SourceDatabaseName=' + ISNULL(@SourceDatabaseName,N'') + N' does not exists.' + @myNewLine
	END
	--Check Dest db existance
	IF NOT EXISTS(SELECT 1 FROM sys.[databases] AS myDatabases WHERE myDatabases.[name]=@DestinationDatabaseName)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myMessage=@myMessage + N'@DestinationDatabaseName=' + ISNULL(@DestinationDatabaseName,N'') + N' does not exists.' + @myNewLine
	END
	--Check Filestream existance combined with snapshot usage
	IF @UseSnapshotOfSourceDB=1 AND EXISTS(SELECT 1 FROM sys.[master_files] AS myDBFiles WHERE [myDBFiles].[database_id]=DB_ID(@SourceDatabaseName) AND [myDBFiles].[type]=2)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myMessage=@myMessage + N'You could not use Snapshot feature while using Filestream technology, set @UseSnapshotOfSourceDB to 0' + @myNewLine
	END
	--Check Parallelism and PrintOnly limitation
	IF @ThreadCount>1 AND @PrintOnly=0
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myMessage=@myMessage + N'You could not use Multi-thread feature in @PrintOnly=0 mode, set @printOnly to 1.' + @myNewLine
	END

	IF @myIsPrerequisitesPassed=0
	BEGIN
		Print @myMessage
		Return
	END

	--=====Request Proccessing
	--===========================================================Update Source stats
	SET @mySQLScript=@mySQLScript+
		CASE WHEN @PrintOnly=1 THEN @myNewLine+N'/*' ELSE N''	END +	--for Print only Command, Comment execution
		@myNewLine+	N'USE ' + QUOTENAME(@SourceDatabaseName) + N' ;		--Update statistics for accurating record count estimation'+
		@myNewLine+	N'EXEC sp_updatestats ;		--Update statistics for accurating record count estimation'+
		CASE WHEN @PrintOnly=1 THEN @myNewLine+N'*/' ELSE N''	END +	--for Print only Command, Comment execution
		@myNewLine+	N'DECLARE @myInsertType NVARCHAR(20)'+
		@myNewLine+	N'SET @myInsertType=N'''+ CAST(@LoadMethod AS NVARCHAR(MAX)) + N''';'+
		@myNewLine+	N''
	--===========================================================FK
	IF @myDisable_FK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #DropConstraint_FK (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #DropConstraint_FK (SQLStatement)'+
			@myNewLine+	N'	SELECT	--Drop FK constraints'+
			@myNewLine+	N'		N''ALTER TABLE '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME(mySchemas.name) + N''.'' + QUOTENAME(myTables.name) + N'' DROP CONSTRAINT '' + QUOTENAME(myFkeys.name) + N'';'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.foreign_keys AS myFkeys '+
			@myNewLine+	N'		INNER JOIN sys.TABLES AS myTables ON myFkeys.parent_object_id=myTables.object_id '+
			@myNewLine+	N'		INNER JOIN sys.schemas AS mySchemas ON myTables.schema_id=mySchemas.schema_id '+
			@myNewLine+	N'	WHERE '+
			@myNewLine+	N'		myTables.is_ms_shipped=0'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END

	IF @myDisable_FK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #CreateConstraint_FK (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #CreateConstraint_FK (SQLStatement)'+
			@myNewLine+	N'	SELECT'+
			@myNewLine+	N'		''ALTER TABLE '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME(mySchemas.name) + ''.'' + QUOTENAME(myTables.name) + '+
			@myNewLine+	N'		''	WITH '' + CASE [myFk].[is_not_trusted] WHEN 1 THEN N''NOCHECK'' ELSE N''CHECK'' END + '+
			@myNewLine+	N'		''	ADD CONSTRAINT '' + QUOTENAME(myFk.name) + '+
			@myNewLine+	N'		''	FOREIGN KEY ('' + '+
			@myNewLine+	N'				Stuff( '+
			@myNewLine+	N'		 				(SELECT '', '' + QUOTENAME(COL_NAME(myFKC.parent_object_id, myFKC.parent_column_id)) '+
			@myNewLine+	N'		 				 FROM sys.foreign_key_columns AS myFKC '+
			@myNewLine+	N'		 				 WHERE myFKC.constraint_object_id = myFk.object_id '+
			@myNewLine+	N'		 				 ORDER BY myFKC.constraint_column_id '+
			@myNewLine+	N'		 				 FOR XML Path('''') '+
			@myNewLine+	N'		 				) '+
			@myNewLine+	N'		 				, 1,2,'''') + '+
			@myNewLine+	N'		 			   '')'' + '+
			@myNewLine+	N'		 ''	REFERENCES '' + QUOTENAME(object_schema_name(myFk.referenced_object_id)) + ''.'' + QUOTENAME(object_name(myFk.referenced_object_id)) + '' ('' + '+
			@myNewLine+	N'		 		STUFF( '+
			@myNewLine+	N'		 			(SELECT '', '' + QUOTENAME(COL_NAME(myFKC.referenced_object_id, myFKC.referenced_column_id)) '+
			@myNewLine+	N'		 			 FROM sys.foreign_key_columns AS myFKC'+
			@myNewLine+	N'		 			 WHERE myFKC.constraint_object_id = myFk.object_id '+
			@myNewLine+	N'		 			 ORDER BY myFKC.constraint_column_id '+
			@myNewLine+	N'		 			 FOR XML Path('''')), '+
			@myNewLine+	N'		 				1,2,'''') + '+
			@myNewLine+	N'		 			   '')'' + '+
			@myNewLine+	N'		 ''	ON DELETE '' + REPLACE(myFk.delete_referential_action_desc, ''_'', '' '')  + '+
			@myNewLine+	N'		 ''	ON UPDATE '' + REPLACE(myFk.update_referential_action_desc , ''_'', '' '') + '';'' COLLATE database_default '+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.foreign_keys AS myFk '+
			@myNewLine+	N'		INNER JOIN sys.TABLES AS myTables ON myFk.parent_object_id=myTables.object_id '+
			@myNewLine+	N'		INNER JOIN sys.schemas AS mySchemas ON myTables.schema_id=mySchemas.schema_id '+
			@myNewLine+	N'	WHERE '+
			@myNewLine+	N'		myTables.is_ms_shipped=0'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END
	--===========================================================PK
	IF @myDisable_PK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #DisableConstraint_PK (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #DisableConstraint_PK (SQLStatement)'+
			@myNewLine+	N'	SELECT	--Disable all enabled Non-Clustered Primary Key Constraints'+
			@myNewLine+	N'		N''ALTER INDEX '' + QUOTENAME([myIndexes].[name]) + N'' ON '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchemas].[name])+N''.''+QUOTENAME([myTables].[name]) + N'' DISABLE;'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.[tables] AS myTables'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS mySchemas ON [mySchemas].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'		INNER JOIN sys.[indexes] AS myIndexes ON [myIndexes].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'		LEFT OUTER JOIN (	--Indexes included row_guid column used for filestream enabled tables'+
			@myNewLine+	N'						SELECT DISTINCT'+
			@myNewLine+	N'							[myIndexCol].[object_id],'+
			@myNewLine+	N'							[myIndexCol].[index_id]'+
			@myNewLine+	N'						FROM'+
			@myNewLine+	N'							sys.[tables] AS myFilestreamTables'+
			@myNewLine+	N'							INNER JOIN sys.[index_columns] AS myIndexCol ON [myIndexCol].[object_id] = [myFilestreamTables].[object_id]'+
			@myNewLine+	N'							INNER JOIN sys.[columns] AS myColumns ON [myColumns].[object_id] = [myIndexCol].[object_id] AND [myColumns].[column_id] = [myIndexCol].[column_id]'+
			@myNewLine+	N'						WHERE'+
			@myNewLine+	N'							[myFilestreamTables].[filestream_data_space_id] IS NOT NULL	--Filestream Enabled Table'+
			@myNewLine+	N'							AND [myFilestreamTables].[is_ms_shipped]=0'+
			@myNewLine+	N'							AND [myColumns].[is_rowguidcol]=1'+
			@myNewLine+	N'						) AS myFileStreamUniqueIndex ON [myFileStreamUniqueIndex].[object_id] = [myIndexes].[object_id] AND [myFileStreamUniqueIndex].[index_id] = [myIndexes].[index_id]'+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		[myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'		AND [myTables].[type]=''U'''+
			@myNewLine+	N'		AND [myIndexes].[type]!=1	--Is not Clustered index'+
			@myNewLine+	N'		AND [myIndexes].[is_disabled]=0'+
			@myNewLine+	N'		AND [myIndexes].[name] IS NOT NULL'+
			@myNewLine+	N'		AND [myIndexes].[is_primary_key]=1'+
			@myNewLine+	N'		AND NOT ([myFileStreamUniqueIndex].[object_id] IS NOT NULL AND ([myIndexes].[is_unique]=1 OR [myIndexes].[is_primary_key]=1 OR [myIndexes].[is_unique_constraint]=1))	--All Indexes Except, Indexes included row_guid column used for filestream enabled tables on PK,UQ,UX constraint'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END

	IF @myDisable_PK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #EnableConstraint_PK (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #EnableConstraint_PK (SQLStatement)'+
			@myNewLine+	N'	SELECT	--Re-Enable all enabled Non-Clustered Primary Key Constraints'+
			@myNewLine+	N'		N''ALTER INDEX '' + QUOTENAME([myIndexes].[name]) + N'' ON '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchemas].[name])+N''.''+QUOTENAME([myTables].[name]) + N'' REBUILD PARTITION = ALL WITH (STATISTICS_NORECOMPUTE = OFF,SORT_IN_TEMPDB = ON, ONLINE = OFF);'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.[tables] AS myTables'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS mySchemas ON [mySchemas].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'		INNER JOIN sys.[indexes] AS myIndexes ON [myIndexes].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'		LEFT OUTER JOIN (	--Indexes included row_guid column used for filestream enabled tables'+
			@myNewLine+	N'						SELECT DISTINCT'+
			@myNewLine+	N'							[myIndexCol].[object_id],'+
			@myNewLine+	N'							[myIndexCol].[index_id]'+
			@myNewLine+	N'						FROM'+
			@myNewLine+	N'							sys.[tables] AS myFilestreamTables'+
			@myNewLine+	N'							INNER JOIN sys.[index_columns] AS myIndexCol ON [myIndexCol].[object_id] = [myFilestreamTables].[object_id]'+
			@myNewLine+	N'							INNER JOIN sys.[columns] AS myColumns ON [myColumns].[object_id] = [myIndexCol].[object_id] AND [myColumns].[column_id] = [myIndexCol].[column_id]'+
			@myNewLine+	N'						WHERE'+
			@myNewLine+	N'							[myFilestreamTables].[filestream_data_space_id] IS NOT NULL	--Filestream Enabled Table'+
			@myNewLine+	N'							AND [myFilestreamTables].[is_ms_shipped]=0'+
			@myNewLine+	N'							AND [myColumns].[is_rowguidcol]=1'+
			@myNewLine+	N'						) AS myFileStreamUniqueIndex ON [myFileStreamUniqueIndex].[object_id] = [myIndexes].[object_id] AND [myFileStreamUniqueIndex].[index_id] = [myIndexes].[index_id]'+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		[myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'		AND [myTables].[type]=''U'''+
			@myNewLine+	N'		AND [myIndexes].[type]!=1	--Is not Clustered index'+
			@myNewLine+	N'		AND [myIndexes].[is_disabled]=0'+
			@myNewLine+	N'		AND [myIndexes].[name] IS NOT NULL'+
			@myNewLine+	N'		AND [myIndexes].[is_primary_key]=1'+
			@myNewLine+	N'		AND NOT ([myFileStreamUniqueIndex].[object_id] IS NOT NULL AND ([myIndexes].[is_unique]=1 OR [myIndexes].[is_primary_key]=1 OR [myIndexes].[is_unique_constraint]=1))	--All Indexes Except, Indexes included row_guid column used for filestream enabled tables on PK,UQ,UX constraint'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END
	--===========================================================UQ
	IF @myDisable_UQ=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #DisableConstraint_UQ (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #DisableConstraint_UQ (SQLStatement)'+
			@myNewLine+	N'	SELECT	--Disable all enabled Non-Clustered Unique Constraints'+
			@myNewLine+	N'		N''ALTER INDEX '' + QUOTENAME([myIndexes].[name]) + N'' ON '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchemas].[name])+N''.''+QUOTENAME([myTables].[name]) + N'' DISABLE;'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.[tables] AS myTables'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS mySchemas ON [mySchemas].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'		INNER JOIN sys.[indexes] AS myIndexes ON [myIndexes].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'		LEFT OUTER JOIN (	--Indexes included row_guid column used for filestream enabled tables'+
			@myNewLine+	N'						SELECT DISTINCT'+
			@myNewLine+	N'							[myIndexCol].[object_id],'+
			@myNewLine+	N'							[myIndexCol].[index_id]'+
			@myNewLine+	N'						FROM'+
			@myNewLine+	N'							sys.[tables] AS myFilestreamTables'+
			@myNewLine+	N'							INNER JOIN sys.[index_columns] AS myIndexCol ON [myIndexCol].[object_id] = [myFilestreamTables].[object_id]'+
			@myNewLine+	N'							INNER JOIN sys.[columns] AS myColumns ON [myColumns].[object_id] = [myIndexCol].[object_id] AND [myColumns].[column_id] = [myIndexCol].[column_id]'+
			@myNewLine+	N'						WHERE'+
			@myNewLine+	N'							[myFilestreamTables].[filestream_data_space_id] IS NOT NULL	--Filestream Enabled Table'+
			@myNewLine+	N'							AND [myFilestreamTables].[is_ms_shipped]=0'+
			@myNewLine+	N'							AND [myColumns].[is_rowguidcol]=1'+
			@myNewLine+	N'						) AS myFileStreamUniqueIndex ON [myFileStreamUniqueIndex].[object_id] = [myIndexes].[object_id] AND [myFileStreamUniqueIndex].[index_id] = [myIndexes].[index_id]'+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		[myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'		AND [myTables].[type]=''U'''+
			@myNewLine+	N'		AND [myIndexes].[type]!=1	--Is not Clustered index'+
			@myNewLine+	N'		AND [myIndexes].[is_disabled]=0'+
			@myNewLine+	N'		AND [myIndexes].[name] IS NOT NULL'+
			@myNewLine+	N'		AND [myIndexes].[is_unique_constraint]=1'+
			@myNewLine+	N'		AND NOT ([myFileStreamUniqueIndex].[object_id] IS NOT NULL AND ([myIndexes].[is_unique]=1 OR [myIndexes].[is_primary_key]=1 OR [myIndexes].[is_unique_constraint]=1))	--All Indexes Except, Indexes included row_guid column used for filestream enabled tables on PK,UQ,UX constraint'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END

	IF @myDisable_UQ=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #EnableConstraint_UQ (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #EnableConstraint_UQ (SQLStatement)'+
			@myNewLine+	N'	SELECT	--Re-Enable all enabled Non-Clustered Unique Constraints'+
			@myNewLine+	N'		N''ALTER INDEX '' + QUOTENAME([myIndexes].[name]) + N'' ON '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchemas].[name])+N''.''+QUOTENAME([myTables].[name]) + N'' REBUILD PARTITION = ALL WITH (STATISTICS_NORECOMPUTE = OFF,SORT_IN_TEMPDB = ON, ONLINE = OFF);'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.[tables] AS myTables'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS mySchemas ON [mySchemas].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'		INNER JOIN sys.[indexes] AS myIndexes ON [myIndexes].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'		LEFT OUTER JOIN (	--Indexes included row_guid column used for filestream enabled tables'+
			@myNewLine+	N'						SELECT DISTINCT'+
			@myNewLine+	N'							[myIndexCol].[object_id],'+
			@myNewLine+	N'							[myIndexCol].[index_id]'+
			@myNewLine+	N'						FROM'+
			@myNewLine+	N'							sys.[tables] AS myFilestreamTables'+
			@myNewLine+	N'							INNER JOIN sys.[index_columns] AS myIndexCol ON [myIndexCol].[object_id] = [myFilestreamTables].[object_id]'+
			@myNewLine+	N'							INNER JOIN sys.[columns] AS myColumns ON [myColumns].[object_id] = [myIndexCol].[object_id] AND [myColumns].[column_id] = [myIndexCol].[column_id]'+
			@myNewLine+	N'						WHERE'+
			@myNewLine+	N'							[myFilestreamTables].[filestream_data_space_id] IS NOT NULL	--Filestream Enabled Table'+
			@myNewLine+	N'							AND [myFilestreamTables].[is_ms_shipped]=0'+
			@myNewLine+	N'							AND [myColumns].[is_rowguidcol]=1'+
			@myNewLine+	N'						) AS myFileStreamUniqueIndex ON [myFileStreamUniqueIndex].[object_id] = [myIndexes].[object_id] AND [myFileStreamUniqueIndex].[index_id] = [myIndexes].[index_id]'+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		[myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'		AND [myTables].[type]=''U'''+
			@myNewLine+	N'		AND [myIndexes].[type]!=1	--Is not Clustered index'+
			@myNewLine+	N'		AND [myIndexes].[is_disabled]=0'+
			@myNewLine+	N'		AND [myIndexes].[name] IS NOT NULL'+
			@myNewLine+	N'		AND [myIndexes].[is_unique_constraint]=1'+
			@myNewLine+	N'		AND NOT ([myFileStreamUniqueIndex].[object_id] IS NOT NULL AND ([myIndexes].[is_unique]=1 OR [myIndexes].[is_primary_key]=1 OR [myIndexes].[is_unique_constraint]=1))	--All Indexes Except, Indexes included row_guid column used for filestream enabled tables on PK,UQ,UX constraint'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END
	--===========================================================NCIX
	IF @myDisable_NCIX=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #DisableConstraint_NCIX (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #DisableConstraint_NCIX (SQLStatement)'+
			@myNewLine+	N'	SELECT	--Disable all enabled Non-Clustered Unique Indexes and other type of normal non-clustered Indexes'+
			@myNewLine+	N'		N''ALTER INDEX '' + QUOTENAME([myIndexes].[name]) + N'' ON '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchemas].[name])+N''.''+QUOTENAME([myTables].[name]) + N'' DISABLE;'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.[tables] AS myTables'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS mySchemas ON [mySchemas].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'		INNER JOIN sys.[indexes] AS myIndexes ON [myIndexes].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'		LEFT OUTER JOIN (	--Indexes included row_guid column used for filestream enabled tables'+
			@myNewLine+	N'						SELECT DISTINCT'+
			@myNewLine+	N'							[myIndexCol].[object_id],'+
			@myNewLine+	N'							[myIndexCol].[index_id]'+
			@myNewLine+	N'						FROM'+
			@myNewLine+	N'							sys.[tables] AS myFilestreamTables'+
			@myNewLine+	N'							INNER JOIN sys.[index_columns] AS myIndexCol ON [myIndexCol].[object_id] = [myFilestreamTables].[object_id]'+
			@myNewLine+	N'							INNER JOIN sys.[columns] AS myColumns ON [myColumns].[object_id] = [myIndexCol].[object_id] AND [myColumns].[column_id] = [myIndexCol].[column_id]'+
			@myNewLine+	N'						WHERE'+
			@myNewLine+	N'							[myFilestreamTables].[filestream_data_space_id] IS NOT NULL	--Filestream Enabled Table'+
			@myNewLine+	N'							AND [myFilestreamTables].[is_ms_shipped]=0'+
			@myNewLine+	N'							AND [myColumns].[is_rowguidcol]=1'+
			@myNewLine+	N'						) AS myFileStreamUniqueIndex ON [myFileStreamUniqueIndex].[object_id] = [myIndexes].[object_id] AND [myFileStreamUniqueIndex].[index_id] = [myIndexes].[index_id]'+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		[myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'		AND [myTables].[type]=''U'''+
			@myNewLine+	N'		AND [myIndexes].[type]!=1	--Is not Clustered index'+
			@myNewLine+	N'		AND [myIndexes].[is_disabled]=0'+
			@myNewLine+	N'		AND [myIndexes].[name] IS NOT NULL'+
			@myNewLine+	N'		AND [myIndexes].[is_primary_key]!=1'+
			@myNewLine+	N'		AND [myIndexes].[is_unique_constraint]!=1'+
			@myNewLine+	N'		AND NOT ([myFileStreamUniqueIndex].[object_id] IS NOT NULL AND ([myIndexes].[is_unique]=1 OR [myIndexes].[is_primary_key]=1 OR [myIndexes].[is_unique_constraint]=1))	--All Indexes Except, Indexes included row_guid column used for filestream enabled tables on PK,UQ,UX constraint'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END

	IF @myDisable_NCIX=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #EnableConstraint_NCIX (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #EnableConstraint_NCIX (SQLStatement)'+
			@myNewLine+	N'	SELECT	--Re-Enable all enabled Unique Indexes and other normal type of Indexes'+
			@myNewLine+	N'		N''ALTER INDEX '' + QUOTENAME([myIndexes].[name]) + N'' ON '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchemas].[name])+N''.''+QUOTENAME([myTables].[name]) + N'' REBUILD PARTITION = ALL WITH (STATISTICS_NORECOMPUTE = OFF,SORT_IN_TEMPDB = ON, ONLINE = OFF);'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.[tables] AS myTables'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS mySchemas ON [mySchemas].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'		INNER JOIN sys.[indexes] AS myIndexes ON [myIndexes].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'		LEFT OUTER JOIN (	--Indexes included row_guid column used for filestream enabled tables'+
			@myNewLine+	N'						SELECT DISTINCT'+
			@myNewLine+	N'							[myIndexCol].[object_id],'+
			@myNewLine+	N'							[myIndexCol].[index_id]'+
			@myNewLine+	N'						FROM'+
			@myNewLine+	N'							sys.[tables] AS myFilestreamTables'+
			@myNewLine+	N'							INNER JOIN sys.[index_columns] AS myIndexCol ON [myIndexCol].[object_id] = [myFilestreamTables].[object_id]'+
			@myNewLine+	N'							INNER JOIN sys.[columns] AS myColumns ON [myColumns].[object_id] = [myIndexCol].[object_id] AND [myColumns].[column_id] = [myIndexCol].[column_id]'+
			@myNewLine+	N'						WHERE'+
			@myNewLine+	N'							[myFilestreamTables].[filestream_data_space_id] IS NOT NULL	--Filestream Enabled Table'+
			@myNewLine+	N'							AND [myFilestreamTables].[is_ms_shipped]=0'+
			@myNewLine+	N'							AND [myColumns].[is_rowguidcol]=1'+
			@myNewLine+	N'						) AS myFileStreamUniqueIndex ON [myFileStreamUniqueIndex].[object_id] = [myIndexes].[object_id] AND [myFileStreamUniqueIndex].[index_id] = [myIndexes].[index_id]'+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		[myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'		AND [myTables].[type]=''U'''+
			@myNewLine+	N'		AND [myIndexes].[type]!=1	--Is not Clustered index'+
			@myNewLine+	N'		AND [myIndexes].[is_disabled]=0'+
			@myNewLine+	N'		AND [myIndexes].[name] IS NOT NULL'+
			@myNewLine+	N'		AND [myIndexes].[is_primary_key]!=1'+
			@myNewLine+	N'		AND [myIndexes].[is_unique_constraint]!=1'+
			@myNewLine+	N'		AND NOT ([myFileStreamUniqueIndex].[object_id] IS NOT NULL AND ([myIndexes].[is_unique]=1 OR [myIndexes].[is_primary_key]=1 OR [myIndexes].[is_unique_constraint]=1))	--All Indexes Except, Indexes included row_guid column used for filestream enabled tables on PK,UQ,UX constraint'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END	
	--===========================================================CHK
	IF @myDisable_CHK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #DisableConstraint_CHK (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #DisableConstraint_CHK (SQLStatement)'+
			@myNewLine+	N'	SELECT	--Disable all enabled Check Constraints'+
			@myNewLine+	N'		N''ALTER TABLE '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchemas].[name])+N''.''+QUOTENAME([myTables].[name]) + N'' NOCHECK CONSTRAINT '' + QUOTENAME([myCheckConstraints].[name]) + N'';'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.[all_objects] AS myTables'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS mySchemas ON [mySchemas].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'		INNER JOIN sys.[check_constraints] AS myCheckConstraints ON [myCheckConstraints].[parent_object_id] = [myTables].[object_id]'+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		[myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'		AND [myTables].[type]=''U'''+
			@myNewLine+	N'		AND [myCheckConstraints].[is_disabled]=0'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END

	IF @myDisable_CHK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #EnableConstraint_CHK (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #EnableConstraint_CHK (SQLStatement)'+
			@myNewLine+	N'	SELECT	/*Re-Enable all enabled Check Constraints*/'+
			@myNewLine+	N'		N''ALTER TABLE '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchemas].[name])+N''.''+QUOTENAME([myTables].[name]) + '+
			@myNewLine+	N'		''	WITH '' + CASE [myCheckConstraints].[is_not_trusted] WHEN 1 THEN N''NOCHECK'' ELSE N''CHECK'' END + '+
			@myNewLine+	N'		N'' CHECK CONSTRAINT '' + QUOTENAME([myCheckConstraints].[name]) + N'';'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.[all_objects] AS myTables'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS mySchemas ON [mySchemas].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'		INNER JOIN sys.[check_constraints] AS myCheckConstraints ON [myCheckConstraints].[parent_object_id] = [myTables].[object_id]'+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		[myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'		AND [myTables].[type]=''U'''+
			@myNewLine+	N'		AND [myCheckConstraints].[is_disabled]=0'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END
	--===========================================================Triggers
	IF @DestinationDisableTriggers=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
			@myNewLine+	N'CREATE TABLE #DisableTriggerTable (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #DisableTriggerTable (SQLStatement)'+
			@myNewLine+	N'	SELECT'+
			@myNewLine+	N'		N''DISABLE TRIGGER '' + QUOTENAME([myTriggerSchema].[name]) + N''.'' + QUOTENAME([myTrigger].[name]) + N'' ON '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchema].[name]) + N''.'' + QUOTENAME([myTables].[name]) + '';'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.[all_objects] AS myTables'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS mySchema ON [mySchema].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'		INNER JOIN sys.[triggers] AS myTrigger ON [myTrigger].[parent_id] = [myTables].[object_id]'+
			@myNewLine+	N'		INNER JOIN sys.[all_objects] AS myTriggerObject ON [myTrigger].[object_id]=[myTriggerObject].[object_id]'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS myTriggerSchema ON [myTriggerObject].[schema_id] = [myTriggerSchema].[schema_id]'+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		[myTables].[type]=''U'''+
			@myNewLine+	N'		AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'		AND [myTrigger].[is_disabled]=0'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END

	IF @DestinationDisableTriggers=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'CREATE TABLE #EnableTriggerTable (ID int IDENTITY, SQLStatement nvarchar(max));'+
			@myNewLine+	N'INSERT INTO #EnableTriggerTable (SQLStatement)'+
			@myNewLine+	N'	SELECT'+
			@myNewLine+	N'		N''ENABLE TRIGGER '' + QUOTENAME([myTriggerSchema].[name]) + N''.'' + QUOTENAME([myTrigger].[name]) + N'' ON '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchema].[name]) + N''.'' + QUOTENAME([myTables].[name]) + '';'''+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		sys.[all_objects] AS myTables'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS mySchema ON [mySchema].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'		INNER JOIN sys.[triggers] AS myTrigger ON [myTrigger].[parent_id] = [myTables].[object_id]'+
			@myNewLine+	N'		INNER JOIN sys.[all_objects] AS myTriggerObject ON [myTrigger].[object_id]=[myTriggerObject].[object_id]'+
			@myNewLine+	N'		INNER JOIN sys.[schemas] AS myTriggerSchema ON [myTriggerObject].[schema_id] = [myTriggerSchema].[schema_id]'+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		[myTables].[type]=''U'''+
			@myNewLine+	N'		AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'		AND [myTrigger].[is_disabled]=0'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
	END
	--===========================================================Insert Data
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + ';'+
			@myNewLine+	N'DECLARE @myExceptedObjectIdString NVARCHAR(MAX);'+
			@myNewLine+	N'DECLARE @myExceptedObjectIds TABLE (ObjectId INT NOT NULL);'+
			@myNewLine+	N'DECLARE @myExceptedObjectIdsXML XML;'+
			@myNewLine+	N''+
			@myNewLine+	N'SET @myExceptedObjectIdString=N'''+ @ExceptedObjectIds +''';'+
			@myNewLine+	N'SELECT @myExceptedObjectIdsXML=CAST(N''<ITEM>'' + REPLACE(@myExceptedObjectIdString COLLATE DATABASE_DEFAULT,'','',''</ITEM><ITEM>'')+ ''</ITEM>'' AS XML);'+
			@myNewLine+	N'INSERT INTO @myExceptedObjectIds ([ObjectId]) SELECT DISTINCT i.value(''.'', ''int'') AS ObjectId FROM @myExceptedObjectIdsXML.nodes(''/ITEM'') AS Item(i) WHERE i.value(''.'', ''int'')!=0;'+
			@myNewLine+	N''+
			@myNewLine+	N'--==Finding best combination of fields for minimum fragmentation and protecting Row Offset with ORDER BY command'+
			@myNewLine+	N'CREATE TABLE #ClusteredColumns ([object_id] INT, [column_id] INT,ColumnName NVARCHAR(256),ColumnOrder INT, SortOrder NVARCHAR(10))'+
			@myNewLine+	N'INSERT INTO [#ClusteredColumns] ([object_id], [column_id], [ColumnName], [SortOrder], [ColumnOrder])'+
			@myNewLine+	N'SELECT '+
			@myNewLine+	N'	[myIndex].[object_id],'+
			@myNewLine+	N'	[myColumns].[column_id],'+
			@myNewLine+	N'	QUOTENAME([myColumns].[name]) AS ColumnName,'+
			@myNewLine+	N'	CASE [myIndexColumns].[is_descending_key] WHEN 1 THEN N''DESC'' ELSE N''ASC'' END AS SortOrder,'+
			@myNewLine+	N'	[myIndexColumns].[key_ordinal] AS ColumnOrder'+
			@myNewLine+	N'FROM'+
			@myNewLine+	N'	sys.[all_objects] AS myTables'+
			@myNewLine+	N'	INNER JOIN sys.[indexes] AS myIndex ON [myIndex].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'	INNER JOIN sys.[index_columns] AS myIndexColumns  ON [myIndexColumns].[object_id] = [myIndex].[object_id] AND [myIndexColumns].[index_id] = [myIndex].[index_id]'+
			@myNewLine+	N'	INNER JOIN sys.[all_columns] AS myColumns ON [myIndexColumns].[object_id]=[myColumns].[object_id] AND [myIndexColumns].[column_id]=[myColumns].[column_id]'+
			@myNewLine+	N'WHERE'+
			@myNewLine+	N'	[myTables].[type]=''U'''+
			@myNewLine+	N'	AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'	AND [myIndex].[index_id]=1		--Is Clustered Index'+
			@myNewLine+	N'	AND [myIndexColumns].[is_included_column]=0'+
			@myNewLine+	N'	AND [myIndex].[is_disabled]=0'+
			@myNewLine+	N'	AND [myIndex].[has_filter]=0'+
			@myNewLine+	N'ORDER BY'+
			@myNewLine+	N'	[myIndexColumns].[key_ordinal]'+
			@myNewLine+	N''+
			@myNewLine+	N'CREATE TABLE #UniqueColumnSets ([object_id] INT, [column_id] INT, [ColumnName] NVARCHAR(256),ColumnOrder INT, SortOrder NVARCHAR(10), GroupId NVARCHAR(50), GroupType NVARCHAR(50),[ColumnLength] INT, UsedInCluster TINYINT DEFAULT(0), TotalClusterColumns TINYINT DEFAULT(0))'+
			@myNewLine+	N'-- Objects that their clustered index is unique or has uniue column(s)'+
			@myNewLine+	N'INSERT INTO [#UniqueColumnSets] ([object_id], [column_id], [ColumnName], [ColumnOrder], [SortOrder], [GroupId], [GroupType],[ColumnLength])'+
			@myNewLine+	N'SELECT '+
			@myNewLine+	N'	[myIndex].[object_id],'+
			@myNewLine+	N'	[myColumns].[column_id],'+
			@myNewLine+	N'	QUOTENAME([myColumns].[name]) AS ColumnName,'+
			@myNewLine+	N'	[myIndexColumns].[key_ordinal] AS ColumnOrder,'+
			@myNewLine+	N'	CASE [myIndexColumns].[is_descending_key] WHEN 1 THEN N''DESC'' ELSE N''ASC'' END AS SortOrder,'+
			@myNewLine+	N'	CAST([myIndex].[index_id] AS NVARCHAR(50)),'+
			@myNewLine+	N'	N''UNIQUE_INDEX'','+
			@myNewLine+	N'	[myColumns].[max_length]'+
			@myNewLine+	N'FROM'+
			@myNewLine+	N'	sys.[all_objects] AS myTables'+
			@myNewLine+	N'	INNER JOIN sys.[indexes] AS myIndex ON [myIndex].[object_id] = [myTables].[object_id] '+
			@myNewLine+	N'	INNER JOIN sys.[index_columns] AS myIndexColumns  ON [myIndexColumns].[object_id] = [myIndex].[object_id] AND [myIndexColumns].[index_id] = [myIndex].[index_id]'+
			@myNewLine+	N'	INNER JOIN sys.[all_columns] AS myColumns ON [myIndexColumns].[object_id]=[myColumns].[object_id] AND [myIndexColumns].[column_id]=[myColumns].[column_id]'+
			@myNewLine+	N'WHERE'+
			@myNewLine+	N'	[myTables].[type]=''U'''+
			@myNewLine+	N'	AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'	AND [myIndexColumns].[is_included_column]=0'+
			@myNewLine+	N'	AND [myIndex].[is_disabled]=0'+
			@myNewLine+	N'	AND [myIndex].[has_filter]=0'+
			@myNewLine+	N'	AND ([myIndex].[is_primary_key]=1 OR [myIndex].[is_unique_constraint]=1 OR [myIndex].[is_unique]=1)'+
			@myNewLine+	N'UNION ALL'+
			@myNewLine+	N'SELECT'+
			@myNewLine+	N'	[myTables].[object_id],'+
			@myNewLine+	N'	[myColumns].[column_id],'+
			@myNewLine+	N'	QUOTENAME([myColumns].[name]) AS ColumnName,'+
			@myNewLine+	N'	1,'+
			@myNewLine+	N'	N''ASC'','+
			@myNewLine+	N'	CAST(NEWID() AS NVARCHAR(50)),'+
			@myNewLine+	N'	N''UNIQUE_COLUMN'','+
			@myNewLine+	N'	[myColumns].[max_length]'+
			@myNewLine+	N'FROM'+
			@myNewLine+	N'	sys.[all_objects] AS myTables'+
			@myNewLine+	N'	INNER JOIN sys.[all_columns] AS myColumns ON [myColumns].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'WHERE'+
			@myNewLine+	N'	[myTables].[type]=''U'''+
			@myNewLine+	N'	AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'	AND ([myColumns].[is_identity]=1 OR [myColumns].[is_rowguidcol]=1)'+
			@myNewLine+	N''+
			@myNewLine+	N'UPDATE [myUniqueColumnSets]'+
			@myNewLine+	N'	SET [myUniqueColumnSets].[TotalClusterColumns]=[myTotalClusteredColumns].[TotalClusteredColumns]'+
			@myNewLine+	N'FROM'+
			@myNewLine+	N'	[#UniqueColumnSets] AS myUniqueColumnSets'+
			@myNewLine+	N'	INNER JOIN (SELECT [myClusteredColumns].[object_id],COUNT(1) AS TotalClusteredColumns FROM [#ClusteredColumns] AS myClusteredColumns GROUP BY [myClusteredColumns].[object_id]) AS myTotalClusteredColumns ON [myTotalClusteredColumns].[object_id] = [myUniqueColumnSets].[object_id]'+
			@myNewLine+	N''+
			@myNewLine+	N'UPDATE [myUniqueColumnSets]'+
			@myNewLine+	N'	SET [myUniqueColumnSets].[UsedInCluster]=1'+
			@myNewLine+	N'FROM'+
			@myNewLine+	N'	[#UniqueColumnSets] AS myUniqueColumnSets'+
			@myNewLine+	N'	INNER JOIN [#ClusteredColumns] AS myClusteredColumns ON [myClusteredColumns].[object_id] = [myUniqueColumnSets].[object_id] AND [myClusteredColumns].[column_id] = [myUniqueColumnSets].[column_id]'+
			@myNewLine+	N''+
			@myNewLine+	N'CREATE TABLE #UniqueColumnSetStats ([object_id] INT, GroupId NVARCHAR(50),ClusterAwareRank TINYINT, ClusterTargetRank TINYINT, TotalGroupColumns TINYINT, TotalGroupLength INT)'+
			@myNewLine+	N'INSERT INTO [#UniqueColumnSetStats] ([object_id], [GroupId], [ClusterAwareRank], [ClusterTargetRank], [TotalGroupColumns], [TotalGroupLength])'+
			@myNewLine+	N'SELECT'+
			@myNewLine+	N'	[myUniqueColumnSets].[object_id],'+
			@myNewLine+	N'	[myUniqueColumnSets].[GroupId],'+
			@myNewLine+	N'	SUM([myUniqueColumnSets].[UsedInCluster]) AS ClusterAwareRank,'+
			@myNewLine+	N'	MAX([myUniqueColumnSets].[TotalClusterColumns]) AS ClusterTargetRank,'+
			@myNewLine+	N'	COUNT(1) AS TotalGroupColumns,'+
			@myNewLine+	N'	SUM(ISNULL([myUniqueColumnSets].[ColumnLength],1000000)) AS TotalGroupLength'+
			@myNewLine+	N'FROM '+
			@myNewLine+	N'	[#UniqueColumnSets] AS myUniqueColumnSets'+
			@myNewLine+	N'GROUP BY'+
			@myNewLine+	N'	[myUniqueColumnSets].[object_id],'+
			@myNewLine+	N'	[myUniqueColumnSets].[GroupId]'+
			@myNewLine+	N''+
			@myNewLine+	N'CREATE TABLE #TableSortResult ([object_id] INT, GroupId NVARCHAR(50), BulkInsertOrderBy_List NVARCHAR(MAX), RowOffsetOrderBy_List NVARCHAR(MAX))'+
			@myNewLine+	N'INSERT INTO [#TableSortResult]([object_id], [GroupId])'+
			@myNewLine+	N'SELECT'+
			@myNewLine+	N'	[myResult_Rank] .[object_id], '+
			@myNewLine+	N'	[myResult_Rank].[GroupId]'+
			@myNewLine+	N'FROM'+
			@myNewLine+	N'	('+
			@myNewLine+	N'	SELECT '+
			@myNewLine+	N'		[myUniqueColumnSetStats].[object_id],'+
			@myNewLine+	N'		[myUniqueColumnSetStats].[GroupId],'+
			@myNewLine+	N'		ROW_NUMBER() OVER(PARTITION BY [myUniqueColumnSetStats].[object_id] ORDER BY [myUniqueColumnSetStats].[ClusterAwareRank] DESC, [myUniqueColumnSetStats].[TotalGroupColumns] ASC,[myUniqueColumnSetStats].[TotalGroupLength]) AS GroupPriority'+
			@myNewLine+	N'	FROM '+
			@myNewLine+	N'		#UniqueColumnSetStats AS myUniqueColumnSetStats'+
			@myNewLine+	N'	) AS myResult_Rank'+
			@myNewLine+	N'WHERE'+
			@myNewLine+	N'	[myResult_Rank].[GroupPriority]=1'+
			@myNewLine+	N''+
			@myNewLine+	N''+
			@myNewLine+	N'UPDATE #TableSortResult '+
			@myNewLine+	N'	SET [#TableSortResult].[RowOffsetOrderBy_List] ='+
			@myNewLine+	N'		(SELECT'+
			@myNewLine+	N'			[myUniqueColumnSets].[ColumnName] + N'' '' + [myUniqueColumnSets].[SortOrder] + N'','' AS ''data()'''+
			@myNewLine+	N'		FROM '+
			@myNewLine+	N'			('+
			@myNewLine+	N'			SELECT'+
			@myNewLine+	N'				1 AS [Priority],'+
			@myNewLine+	N'				[myClusteredColumns].[object_id],'+
			@myNewLine+	N'				[myClusteredColumns].[ColumnName],'+
			@myNewLine+	N'				[myClusteredColumns].[SortOrder],'+
			@myNewLine+	N'				[myClusteredColumns].[ColumnOrder]'+
			@myNewLine+	N'			FROM'+
			@myNewLine+	N'				[#ClusteredColumns] AS myClusteredColumns'+
			@myNewLine+	N'			WHERE '+
			@myNewLine+	N'				[myClusteredColumns].[object_id]=[#TableSortResult].[object_id]'+
			@myNewLine+	N'			UNION ALL'+
			@myNewLine+	N'			SELECT'+
			@myNewLine+	N'				2 AS [Priority],'+
			@myNewLine+	N'				[myUniqueColumns].[object_id],'+
			@myNewLine+	N'				[myUniqueColumns].[ColumnName],'+
			@myNewLine+	N'				[myUniqueColumns].[SortOrder],'+
			@myNewLine+	N'				[myUniqueColumns].[ColumnOrder]'+
			@myNewLine+	N'			FROM'+
			@myNewLine+	N'				#UniqueColumnSets AS myUniqueColumns'+
			@myNewLine+	N'			WHERE '+
			@myNewLine+	N'				[myUniqueColumns].[object_id]=[#TableSortResult].[object_id]'+
			@myNewLine+	N'				AND [myUniqueColumns].[GroupId]=[#TableSortResult].[GroupId]'+
			@myNewLine+	N'				AND [myUniqueColumns].[column_id] NOT IN (SELECT [myFilter].[column_id] FROM [#ClusteredColumns] AS myFilter WHERE [myFilter].[object_id]=[myUniqueColumns].[object_id])'+
			@myNewLine+	N'			) AS [myUniqueColumnSets]'+
			@myNewLine+	N'		ORDER BY '+
			@myNewLine+	N'			[myUniqueColumnSets].[Priority],'+
			@myNewLine+	N'			[myUniqueColumnSets].[ColumnOrder]'+
			@myNewLine+	N'		FOR XML PATH('''')'+
			@myNewLine+	N'		)'+
			@myNewLine+	N''+
			@myNewLine+	N'MERGE #TableSortResult AS target'+
			@myNewLine+	N'    USING ('+
			@myNewLine+	N'			SELECT '+
			@myNewLine+	N'				[myClusteredTables].[object_id], '+
			@myNewLine+	N'				(SELECT'+
			@myNewLine+	N'					[myClusteredColumns].[ColumnName] + N'' '' + [myClusteredColumns].[SortOrder] + N'','' AS ''data()'''+
			@myNewLine+	N'				FROM '+
			@myNewLine+	N'					[#ClusteredColumns] AS myClusteredColumns'+
			@myNewLine+	N'				WHERE '+
			@myNewLine+	N'					[myClusteredColumns].[object_id]=[myClusteredTables].[object_id]'+
			@myNewLine+	N'				ORDER BY '+
			@myNewLine+	N'					[myClusteredColumns].[ColumnOrder]'+
			@myNewLine+	N'				FOR XML PATH('''')'+
			@myNewLine+	N'				) AS BulkInsertOrderBy_List'+
			@myNewLine+	N'			FROM '+
			@myNewLine+	N'				[#ClusteredColumns] AS myClusteredTables'+
			@myNewLine+	N'			GROUP BY'+
			@myNewLine+	N'				[myClusteredTables].[object_id]	'+
			@myNewLine+	N'	) AS source ([object_id], BulkInsertOrderBy_List) ON (target.[object_id] = source.[object_id])'+
			@myNewLine+	N'    WHEN MATCHED THEN '+
			@myNewLine+	N'        UPDATE SET [target].[BulkInsertOrderBy_List] = source.[BulkInsertOrderBy_List]'+
			@myNewLine+	N'	WHEN NOT MATCHED THEN'+
			@myNewLine+	N'		INSERT ([object_id],[BulkInsertOrderBy_List])'+
			@myNewLine+	N'		VALUES (source.[object_id], source.[BulkInsertOrderBy_List]);'+
			@myNewLine+	N'--==Finished Finding best combination of fields'+
			@myNewLine+	N''+
			@myNewLine+	N'DECLARE @myPowerShellTemplatePre NVARCHAR(MAX)'+
			@myNewLine+	N'DECLARE @myPowerShellTemplatePost NVARCHAR(MAX)'+
			@myNewLine+	N'DECLARE @myCmdTemplatePre NVARCHAR(MAX)'+
			@myNewLine+	N'DECLARE @myCmdTemplatePost NVARCHAR(MAX)'+
			@myNewLine+	N'SET @myPowerShellTemplatePre=CAST(N'''' AS NVARCHAR(MAX))'+
			@myNewLine+	N'SET @myPowerShellTemplatePost=CAST(N'''' AS NVARCHAR(MAX))'+
			@myNewLine+	N'SET @myCmdTemplatePre=CAST(N'''' AS NVARCHAR(MAX))'+
			@myNewLine+	N'SET @myCmdTemplatePost=CAST(N'''' AS NVARCHAR(MAX))'+
			@myNewLine+	N''+
			@myNewLine+	N'SET @myPowerShellTemplatePre = @myPowerShellTemplatePre + CAST(N'''+
			@myNewLine+	N'$params = @{'+
			@myNewLine+	N'SqlInstance = '''''+ CAST(@@SERVERNAME AS NVARCHAR(MAX)) + ''''''+
			@myNewLine+	N'Destination = '''''+ CAST(@@SERVERNAME AS NVARCHAR(MAX)) + ''''''+
			@myNewLine+	N'Database = '''''+ @SourceDatabaseName +''''''+
			@myNewLine+	N'DestinationDatabase = '''''+@DestinationDatabaseName+''''''+
			@myNewLine+	N'Query = '''''' AS NVARCHAR(MAX))'+
			@myNewLine+	N''+
			@myNewLine+	N'SET @myPowerShellTemplatePost = @myPowerShellTemplatePost + CAST(N'''''''+
			@myNewLine+	N'Table = ''''@SourceTable'''''+
			@myNewLine+	N'DestinationTable = ''''@DestTable'''''+
			@myNewLine+	N'KeepIdentity = $true'+
			@myNewLine+	N'NoTableLock = @NoTableLock'+
			@myNewLine+	N'KeepNulls = $true'+
			@myNewLine+	N'Truncate = @Truncate'+
			@myNewLine+	N'BatchSize = ' + CAST(@BatchCount AS NVARCHAR(MAX))+
			@myNewLine+	N'bulkCopyTimeOut = 0'+
			@myNewLine+	N'EnableException = $true'+
			@myNewLine+	N'}'+
			@myNewLine+	N'Copy-DbaDbTableData @params -ErrorAction Stop'' AS NVARCHAR(MAX))'+
			@myNewLine+	N''+
			@myNewLine+	N'SET @myCmdTemplatePre = @myCmdTemplatePre + CAST(N''powershell.exe -ExecutionPolicy Bypass -Command "Import-Module dbatools;$params = @{SqlInstance = '''''+ CAST(@@SERVERNAME AS NVARCHAR(MAX)) + ''''';Destination = '''''+ CAST(@@SERVERNAME AS NVARCHAR(MAX)) + ''''';Database = '''''+@SourceDatabaseName+''''';DestinationDatabase = '''''+@DestinationDatabaseName+''''';Query = '''''' AS NVARCHAR(MAX))'+ 
			@myNewLine+	N'SET @myCmdTemplatePost = @myCmdTemplatePost + CAST(N'''''';Table = ''''@SourceTable'''';DestinationTable = ''''@DestTable'''';KeepIdentity = $true;KeepNulls = $true;Truncate = $true;BatchSize = '+ CAST(@BatchCount AS NVARCHAR(MAX)) + ';EnableException = $true};Copy-DbaDbTableData @params -ErrorAction Stop"'' AS NVARCHAR(MAX))'+
			@myNewLine+	N''+
			@myNewLine+	N'CREATE TABLE #InsertTable (ID int IDENTITY, SQLStatement nvarchar(max),[RowCount] BIGINT,[PageCount] BIGINT,[TableSizeKb] BIGINT,[ObjectName] nvarchar(128), [MultipleInsertionOrder] INT);'+
			@myNewLine+	N'INSERT INTO #InsertTable (SQLStatement,[RowCount],[PageCount],[TableSizeKb],[ObjectName],[MultipleInsertionOrder])'+
			@myNewLine+	N'	SELECT'+
				CASE @myDisable_FK WHEN 1 THEN
				@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT = N''TSQL'' AND [myTablesAndColumns].[MultipleInsertionOrder] <= 1 THEN N''TRUNCATE TABLE '' + QUOTENAME(DB_NAME()) + N''.'' + myTablesAndColumns.[ObjectName] + N'';'' ELSE N'''' END+'
				ELSE N''
				END+
			@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT = N''TSQL'' THEN ISNULL([myTablesAndColumns].[PagingStart],N'''') ELSE N'''' END+'+
				CASE @DestinationDisableIdentity WHEN 1 THEN
				@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT = N''TSQL'' THEN ISNULL([myTablesAndColumns].[DisableIdentity],N'''') ELSE N'''' END+' 
				ELSE N'' 
				END+
			@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT = N''TSQL'' THEN N''INSERT INTO '' + QUOTENAME(DB_NAME()) + N''.'' + myTablesAndColumns.[ObjectName] + CASE WHEN [myTablesAndColumns].[MultipleInsertionOrder] = 0 THEN N'' WITH (TABLOCK) '' ELSE N'''' END + N'' ('' + LEFT(myTablesAndColumns.[myDestColumnList],LEN(myTablesAndColumns.[myDestColumnList])-1) + N'') '' ELSE N'''' END+'+
			@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT = (N''POWERSHELL'') THEN @myPowerShellTemplatePre ELSE N'''' END +'+
			@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT = (N''CMD'') THEN @myCmdTemplatePre ELSE N'''' END +'+
			@myNewLine+	N'		N'' SELECT '' + LEFT(myTablesAndColumns.[mySourceColumnList],LEN(myTablesAndColumns.[mySourceColumnList])-1) + N'' FROM ' + QUOTENAME(@mySourceConsistentDatabase) +N'.'' + myTablesAndColumns.[ObjectName] + [myTablesAndColumns].[WhereClause] +'+
			--@myNewLine+	N'		N'' SELECT '' + LEFT(myTablesAndColumns.[mySourceColumnList],LEN(myTablesAndColumns.[mySourceColumnList])-1) + N'' FROM ' + QUOTENAME(@mySourceConsistentDatabase) +N'.'' + myTablesAndColumns.[ObjectName] +'+
				CASE @PumpDataByKeyOrder WHEN 1 THEN			
				@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT IN (N''CMD'',N''POWERSHELL'') THEN ISNULL([myTablesAndColumns].[BulkInsertOrderBy],N'''') ELSE N'''' END+'
				ELSE N''
				END+
			@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT = (N''CMD'') THEN REPLACE(REPLACE(REPLACE(REPLACE(@myCmdTemplatePost,N''@SourceTable'',[myTablesAndColumns].[ObjectName]),N''@DestTable'',[myTablesAndColumns].[ObjectName]),N''@NoTableLock'', CASE WHEN [myTablesAndColumns].[MultipleInsertionOrder] = 0 THEN N''$false'' ELSE N''$true'' END), N''@Truncate'',CASE WHEN [myTablesAndColumns].[MultipleInsertionOrder] <= 1 THEN N''$true'' ELSE N''$false'' END) ELSE N'''' END +'+
			@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT = (N''POWERSHELL'') THEN REPLACE(REPLACE(REPLACE(REPLACE(@myPowerShellTemplatePost,N''@SourceTable'',[myTablesAndColumns].[ObjectName]),N''@DestTable'',[myTablesAndColumns].[ObjectName]),N''@NoTableLock'', CASE WHEN [myTablesAndColumns].[MultipleInsertionOrder] = 0 THEN N''$false'' ELSE N''$true'' END), N''@Truncate'',CASE WHEN [myTablesAndColumns].[MultipleInsertionOrder] <= 1 THEN N''$true'' ELSE N''$false'' END) ELSE N'''' END +'+
			@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT = N''TSQL'' THEN ISNULL([myTablesAndColumns].[PagingFinish],N'''') ELSE N'''' END+'+
				CASE @DestinationDisableIdentity WHEN 1 THEN
				@myNewLine+	N'		CASE WHEN @myInsertType COLLATE DATABASE_DEFAULT = N''TSQL'' THEN ISNULL([myTablesAndColumns].[EnableIdentity],N'''') + '';'' ELSE N'''' END COLLATE DATABASE_DEFAULT,'
				ELSE N''';''COLLATE DATABASE_DEFAULT,'
				END+
			@myNewLine+	N'		[myTablesAndColumns].[RowCount],'+
			@myNewLine+	N'		[myTablesAndColumns].[PageCount],'+
			@myNewLine+	N'		[myTablesAndColumns].[TableSizeKb],'+
			@myNewLine+	N'		[myTablesAndColumns].[ObjectName],'+
			@myNewLine+	N'		[myTablesAndColumns].[MultipleInsertionOrder]'+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		('+
			@myNewLine+	N'		SELECT'+
			@myNewLine+	N'			QUOTENAME([mySchema].[name]) + N''.'' + QUOTENAME([myTables].[name]) AS ObjectName,'+
			@myNewLine+	N'			('+
			@myNewLine+	N'				SELECT'+
			@myNewLine+	N'					CASE [myTypes].[name]'+
			@myNewLine+	N'						WHEN ''xml'' THEN ''CONVERT(XML,'' + QUOTENAME([myColumns].[name])+'')'''+
			@myNewLine+	N'						ELSE QUOTENAME([myColumns].[name])'+
			@myNewLine+	N'					END + N'','' AS ''data()'''+
			@myNewLine+	N'				FROM'+
			@myNewLine+	N'					sys.[all_columns] AS myColumns'+
			@myNewLine+	N'					INNER JOIN sys.[types] AS myTypes ON [myColumns].[user_type_id]=[myTypes].[user_type_id]'+
			@myNewLine+	N'				WHERE'+
			@myNewLine+	N'					[myColumns].[is_computed]=0'+
			@myNewLine+	N'					AND myColumns.[is_column_set]=0'+
			@myNewLine+	N'					AND [myColumns].[user_type_id]!=189'+
			@myNewLine+	N'					AND [myColumns].[object_id]=[myTables].[object_id]'+
			@myNewLine+	N'				ORDER BY'+
			@myNewLine+	N'					[myColumns].[column_id]'+
			@myNewLine+	N'				FOR XML PATH('''')'+
			@myNewLine+	N'			) AS mySourceColumnList,'+
			@myNewLine+	N'			('+
			@myNewLine+	N'				SELECT'+
			@myNewLine+	N'					QUOTENAME([myColumns].[name]) + N'','' AS ''data()'''+
			@myNewLine+	N'				FROM'+
			@myNewLine+	N'					sys.[all_columns] AS myColumns'+
			@myNewLine+	N'				WHERE'+
			@myNewLine+	N'					[myColumns].[is_computed]=0'+
			@myNewLine+	N'					AND myColumns.[is_column_set]=0'+
			@myNewLine+	N'					AND [myColumns].[user_type_id]!=189'+
			@myNewLine+	N'					AND [myColumns].[object_id]=[myTables].[object_id]'+
			@myNewLine+	N'				ORDER BY'+
			@myNewLine+	N'					[myColumns].[column_id]'+
			@myNewLine+	N'				FOR XML PATH('''')'+
			@myNewLine+	N'			) AS myDestColumnList,'+
			@myNewLine+	N'			[myIdentity].[DisableIdentity],'+
			@myNewLine+	N'			[myIdentity].[EnableIdentity],'+
			@myNewLine+	N'			[myStats].[RowCount],'+
			@myNewLine+	N'			[myStats].[PageCount],'+
			@myNewLine+	N'			[myStats].[TableSizeKb],'+
			@myNewLine+	N'			CASE WHEN RIGHT([myUniqueColumnList].[RowOffsetOrderBy_List],1)=N'','' THEN LEFT([myUniqueColumnList].[RowOffsetOrderBy_List],LEN([myUniqueColumnList].[RowOffsetOrderBy_List])-1) ELSE [myUniqueColumnList].[RowOffsetOrderBy_List] END AS [UniqueColumnList],'+
			@myNewLine+	N'			CASE WHEN [myPartitionedTables].[object_id] IS NOT NULL THEN N'' WHERE '' + [myPartitionedTables].[PartitionWhereClause] ELSE N'''' END AS WhereClause,'+
			@myNewLine+	N'			CASE WHEN [myPartitionedTables].[object_id] IS NOT NULL THEN [myPartitionedTables].PartitionOrder ELSE 0 END AS MultipleInsertionOrder,'+
			@myNewLine+	N'			CASE WHEN [myUniqueColumnList].[BulkInsertOrderBy_List] IS NOT NULL THEN '+
			@myNewLine+	N'				N'' ORDER BY '' + CASE WHEN RIGHT([myUniqueColumnList].[BulkInsertOrderBy_List],1)=N'','' THEN LEFT([myUniqueColumnList].[BulkInsertOrderBy_List],LEN([myUniqueColumnList].[BulkInsertOrderBy_List])-1) ELSE [myUniqueColumnList].[BulkInsertOrderBy_List] END'+
			@myNewLine+	N'				ELSE N'''' END AS BulkInsertOrderBy,'+
			@myNewLine+	N'			CASE WHEN [myStats].[PageCount]>1 AND [myUniqueColumnList].[RowOffsetOrderBy_List] IS NOT NULL THEN '+
			@myNewLine+	N'				N''DECLARE @PageNumber bigint = 1;'' +'+
			@myNewLine+	N'				N''DECLARE @RecordsPerPage bigint = ' + CAST(@BatchCount AS NVARCHAR(MAX)) + N';'' +'+
			@myNewLine+	N'				N''DECLARE @TotalPage bigint = ' + CAST(@BatchCount AS NVARCHAR(MAX)) + N';'' +'+
			@myNewLine+	N'				N''WHILE @PageNumber <= '' + CAST([myStats].[PageCount] AS NVARCHAR(MAX)) + N'' '' +'+
			@myNewLine+	N'				N''BEGIN '' +'+
			@myNewLine+	N'				N''BEGIN TRANSACTION '''+
			@myNewLine+	N'				ELSE N'''' END AS PagingStart,'+
			@myNewLine+	N'			CASE WHEN [myStats].[PageCount]>1 AND [myUniqueColumnList].[RowOffsetOrderBy_List] IS NOT NULL THEN '+
			@myNewLine+	N'				N'' ORDER BY '' + CASE WHEN RIGHT([myUniqueColumnList].[RowOffsetOrderBy_List],1)=N'','' THEN LEFT([myUniqueColumnList].[RowOffsetOrderBy_List],LEN([myUniqueColumnList].[RowOffsetOrderBy_List])-1) ELSE [myUniqueColumnList].[RowOffsetOrderBy_List] END + N'' OFFSET (@PageNumber-1)*@RecordsPerPage ROWS FETCH NEXT @RecordsPerPage ROWS ONLY''+'+
			@myNewLine+	N'				N'' COMMIT; ''+'+
			@myNewLine+	N'				N'' INSERT INTO ' + CAST(@myLogTableName AS NVARCHAR(MAX)) + N'([object_name],[last_commited_batch]) VALUES(N'''''' + QUOTENAME([mySchema].[name])+ N''.'' + QUOTENAME([myTables].[name]) + N'''''', @PageNumber);''+'+
			@myNewLine+	N'				N'' SET @PageNumber=@PageNumber+1;''+'+
			@myNewLine+	N'				N'' END '''+
			@myNewLine+	N'				ELSE N'''' END AS PagingFinish'+
			@myNewLine+	N'		FROM'+
			@myNewLine+	N'			sys.[all_objects] AS myTables'+
			@myNewLine+	N'			INNER JOIN sys.[schemas] AS mySchema ON [mySchema].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'			LEFT OUTER JOIN '+
			@myNewLine+	N'						('+
			@myNewLine+	N'						SELECT'+
			@myNewLine+	N'							[myRowStat].[object_id],'+
			@myNewLine+	N'							SUM(myRowStat.row_count) AS [RowCount],'+
			@myNewLine+	N'							CASE WHEN '+ CAST(@BatchCount AS NVARCHAR(MAX)) + N' > 0 THEN' +
			@myNewLine+	N'								CASE '+
			@myNewLine+	N'									WHEN SUM(myRowStat.row_count)/CAST(' + CAST(@BatchCount AS NVARCHAR(MAX)) + N' AS DECIMAL(19,1)) > SUM(myRowStat.row_count)/' + CAST(@BatchCount AS NVARCHAR(MAX)) + N' THEN (SUM(myRowStat.row_count)/'+ CAST(@BatchCount AS NVARCHAR(MAX)) + N') + 1'+
			@myNewLine+	N'									ELSE SUM(myRowStat.row_count)/' + CAST(@BatchCount AS NVARCHAR(MAX)) +
			@myNewLine+	N'								END'+
			@myNewLine+	N'							ELSE 1 END AS [PageCount],'+
			@myNewLine+	N'							SUM(myRowStat.used_page_count)*8 AS [TableSizeKb]'+
			@myNewLine+	N'						FROM'+
			@myNewLine+	N'							' + CAST(QUOTENAME(@SourceDatabaseName) AS NVARCHAR(MAX)) + N'.sys.dm_db_partition_stats AS myRowStat'+
			@myNewLine+	N'						WHERE'+
			@myNewLine+	N'							myRowStat.index_id<=1'+
			@myNewLine+	N'						GROUP BY'+
			@myNewLine+	N'							myRowStat.[object_id]'+
			@myNewLine+	N'						) AS myStats ON [myStats].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'			LEFT OUTER JOIN'+
			@myNewLine+	N'						('+
			@myNewLine+	N'						SELECT'+
			@myNewLine+	N'							myTables.[object_id],'+
			@myNewLine+	N'							N''SET IDENTITY_INSERT '' + MAX(QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchema].[name]) + N''.'' + QUOTENAME([myTables].[name])) + N'' ON '' AS DisableIdentity,'+
			@myNewLine+	N'							N''SET IDENTITY_INSERT '' + MAX(QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([mySchema].[name]) + N''.'' + QUOTENAME([myTables].[name])) + N'' OFF '' AS EnableIdentity'+
			@myNewLine+	N'						FROM '+
			@myNewLine+	N'							sys.[all_objects] AS myTables'+
			@myNewLine+	N'							INNER JOIN sys.[schemas] AS mySchema ON [mySchema].[schema_id] = [myTables].[schema_id]'+
			@myNewLine+	N'							INNER JOIN sys.[all_columns] AS myColumns ON [myColumns].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'						WHERE'+
			@myNewLine+	N'							[myTables].[type]=''U'''+
			@myNewLine+	N'							AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'							AND [myColumns].[is_identity]=1'+
			@myNewLine+	N'						GROUP BY'+
			@myNewLine+	N'							[myTables].[object_id]'+
			@myNewLine+	N'						) AS myIdentity ON [myIdentity].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'			LEFT OUTER JOIN #TableSortResult AS [myUniqueColumnList] ON [myUniqueColumnList].[object_id] = [myTables].[object_id]'+
			@myNewLine+	N'			LEFT OUTER JOIN'+	
			@myNewLine+	N'						('+
			@myNewLine+	N'						SELECT '+
			@myNewLine+	N'							[myPartitionInfo].[object_id],'+
			@myNewLine+	N'							[myPartitionInfo].[PartitionWhereClause],'+
			@myNewLine+	N'							ROW_NUMBER() OVER (PARTITION BY [myPartitionInfo].[object_id] ORDER BY [myPartitionInfo].[partition_number]) AS PartitionOrder'+
			@myNewLine+	N'						FROM'+
			@myNewLine+	N'							('+
			@myNewLine+	N'							SELECT DISTINCT '+
			@myNewLine+	N'								[myTable].[object_id],'+
			@myNewLine+	N'							    CASE WHEN [myLeft_prv].[value] IS NOT NULL THEN'+
			@myNewLine+	N'									CASE [myType].[system_type_id]'+
			@myNewLine+	N'										WHEN 61 /*datetime*/ THEN ''DATEADD(MILLISECOND,-1,CAST('''''''''' + CAST([myLeft_prv].[value] AS NVARCHAR(255)) + '''''''''' AS '' + [myType].[name] + '' ))'' '+
			@myNewLine+	N'										ELSE											 ''CAST('''''''''' + CAST([myLeft_prv].[value] AS NVARCHAR(255)) + '''''''''' AS '' + [myType].[name] + '' )'' '+
			@myNewLine+	N'									END +'+
			@myNewLine+	N'									CASE WHEN [myPartitionFunction].[boundary_value_on_right] = 0 THEN '' < '' ELSE '' <= '' END + [myColumn].[name] ELSE N'''''+
			@myNewLine+	N'								END +'+
			@myNewLine+	N'							    CASE WHEN [myLeft_prv].[value] IS NOT NULL AND [myRight_prv].[value] IS NOT NULL THEN '' AND '' ELSE N'''' END +'+
			@myNewLine+	N'								CASE WHEN [myRight_prv].[value] IS NOT NULL THEN'+
			@myNewLine+	N'									[myColumn].[name] + CASE WHEN [myPartitionFunction].[boundary_value_on_right] = 0 THEN '' <= '' ELSE '' < '' END +'+
			@myNewLine+	N'									CASE [myType].[system_type_id]'+
			@myNewLine+	N'										WHEN 61 /*datetime*/ THEN ''DATEADD(MILLISECOND,-2,CAST('''''''''' + CAST([myRight_prv].[value] AS NVARCHAR(255)) + '''''''''' AS '' + [myType].[name] + '' ))'' '+
			@myNewLine+	N'										ELSE											 ''CAST('''''''''' + CAST([myRight_prv].[value] AS NVARCHAR(255)) + '''''''''' AS '' + [myType].[name] + '' )'' '+
			@myNewLine+	N'									END ELSE N'''''+
			@myNewLine+	N'								END'+
			@myNewLine+	N'								AS PartitionWhereClause,'+
			@myNewLine+	N'								[myPartitions].[partition_number]'+
			@myNewLine+	N'							FROM'+
			@myNewLine+	N'								['+ @myPartitioningInfoStandard +'].[sys].[partitions] AS myPartitions'+
			@myNewLine+	N'								INNER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[tables] AS myTable ON [myPartitions].[object_id] = [myTable].[object_id]'+
			@myNewLine+	N'								INNER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[schemas] AS mySchema ON [mySchema].[schema_id] = [myTable].[schema_id]'+
			@myNewLine+	N'								INNER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[indexes] AS myIndex ON [myPartitions].[object_id] = [myIndex].[object_id] AND [myPartitions].[index_id] = [myIndex].[index_id]'+
			@myNewLine+	N'								INNER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[index_columns] AS myIndexCol ON [myIndexCol].[object_id] = [myIndex].[object_id] AND [myIndexCol].[index_id] = [myIndex].[index_id]'+
			@myNewLine+	N'								INNER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[all_columns] AS myColumn ON [myColumn].[object_id] = [myIndexCol].[object_id] AND [myColumn].[column_id] = [myIndexCol].[column_id]'+
			@myNewLine+	N'								INNER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[types] AS myType ON [myColumn].[system_type_id]=[myType].[system_type_id]'+
			@myNewLine+	N'								INNER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[allocation_units] AS myAllocationUnit ON [myPartitions].[hobt_id] = [myAllocationUnit].[container_id]'+
			@myNewLine+	N'								INNER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[filegroups] AS myFilegroup ON [myAllocationUnit].[data_space_id] = [myFilegroup].[data_space_id]'+
			@myNewLine+	N'								INNER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[partition_schemes] AS myPartitionSchema ON [myPartitionSchema].[data_space_id] = [myIndex].[data_space_id]'+
			@myNewLine+	N'								INNER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[partition_functions] AS myPartitionFunction ON [myPartitionFunction].[function_id] = [myPartitionSchema].[function_id] '+
			@myNewLine+	N'								LEFT OUTER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[partition_range_values] AS myLeft_prv ON [myLeft_prv].[function_id] = [myPartitionSchema].[function_id] AND [myLeft_prv].[boundary_id] + 1 = [myPartitions].[partition_number]'+
			@myNewLine+	N'								LEFT OUTER JOIN ['+ @myPartitioningInfoStandard +'].[sys].[partition_range_values] AS myRight_prv ON [myRight_prv].[function_id] = [myPartitionSchema].[function_id] AND [myRight_prv].[boundary_id] = [myPartitions].[partition_number]'+
			@myNewLine+	N'							WHERE'+
			@myNewLine+	N'								[myIndexCol].[partition_ordinal]=1'+
			@myNewLine+	N'								AND [myType].[user_type_id]=[myType].[system_type_id]'+
			@myNewLine+	N'							) AS [myPartitionInfo]'+
			@myNewLine+	N'						) AS [myPartitionedTables] ON [myPartitionedTables].[object_id] = [myTables].[object_id]'+		
			@myNewLine+	N'		WHERE'+
			@myNewLine+	N'			[myTables].[type]=''U'''+
			@myNewLine+	N'			AND [myTables].[is_ms_shipped]=0'+
			@myNewLine+	N'			AND [myTables].[object_id] NOT IN (SELECT [ObjectId] FROM @myExceptedObjectIds)	--Except user requested objects'+
			@myNewLine+	N'		) AS myTablesAndColumns'+
			@myNewLine+	N''
			AS NVARCHAR(MAX))
			
	--================================================================================
	--===========================================================Executing Preparation
	--================================================================================
	SET @mySQLScript=@mySQLScript+
		CAST(
			CASE WHEN @PrintOnly=1 THEN @myNewLine+N'/*' ELSE ''	END +	--for Print only Command, Comment execution
			CASE @UseSnapshotOfSourceDB WHEN 1 THEN
				@myNewLine+ N'USE [DBA];'+
				@myNewLine+ N'EXECUTE [dbo].[dbasp_create_snapshot] N''' + @SourceDatabaseName + N''',N'''+ @mySnapshotSuffix + N''',''' + @SnapshotFolder + N''',0;'
			ELSE N'' END +
			CASE @DestinationRecoveryModel 
				WHEN N'SIMPLE' THEN
					@myNewLine+ N'USE [master];'+
					@myNewLine+	N'ALTER DATABASE ' + QUOTENAME(@DestinationDatabaseName) + N' SET RECOVERY SIMPLE WITH NO_WAIT;'
				WHEN N'BULK' THEN
					@myNewLine+ N'USE [master];'+
					@myNewLine+	N'ALTER DATABASE ' + QUOTENAME(@DestinationDatabaseName) + N' SET RECOVERY BULK_LOGGED WITH NO_WAIT;'
			ELSE N'' END +
			CASE @myProtection_Readonly WHEN 1 THEN
				@myNewLine+ N'USE [master];'+
				@myNewLine+	N'ALTER DATABASE ' + QUOTENAME(@SourceDatabaseName) + N' SET READ_ONLY WITH NO_WAIT;'
			ELSE N'' END +
			@myNewLine+	N'DBCC TRACEON(610, -1);	--Enable Minimally logged operations'+
			@myNewLine+	N'--================================================================================'+
			@myNewLine+	N'--===========================================================Executing Preparation'+
			@myNewLine+	N'--================================================================================'
		AS NVARCHAR(MAX))
	--=======STEP 00: Preparation
	SET @mySQLScript=@mySQLScript+
		CAST(
		@myNewLine+ N'--=======STEP 00: Preparation'+
		@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
		@myNewLine+ N'DECLARE @mySQLStatement NVARCHAR(max);'+
		@myNewLine+ N'DECLARE @mySQLStatementID INT;'+
		@myNewLine+ N'DECLARE @CustomMessage nvarchar(255)'+
		@myNewLine+ N''+
		@myNewLine+ N'SET QUOTED_IDENTIFIER ON'+
		@myNewLine+ N'SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
		@myNewLine+ N''+
		@myNewLine+ N''
		AS NVARCHAR(MAX))

	--=======STEP 01: Drop FK
	IF @myDisable_FK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 01: Drop FK'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_DropConstraint_FK Cursor;'+
			@myNewLine+ N'SET @myCursor_DropConstraint_FK=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #DropConstraint_FK ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''Current database is '+ QUOTENAME(@DestinationDatabaseName) + N''';' +
			@myNewLine+ N'PRINT ''------------- Drop FK Constraints'';' +
			@myNewLine+ N'Open @myCursor_DropConstraint_FK'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_DropConstraint_FK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Drop FK Constraint error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_DropConstraint_FK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_DropConstraint_FK; '+
			@myNewLine+ N'DEALLOCATE @myCursor_DropConstraint_FK; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 02: Disable PK
	IF @myDisable_PK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 02: Disable PK'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_DisableConstraint_PK Cursor;'+
			@myNewLine+ N'SET @myCursor_DisableConstraint_PK=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #DisableConstraint_PK ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''Current database is '+ QUOTENAME(@DestinationDatabaseName) + N''';' +
			@myNewLine+ N'PRINT ''------------- Disable PK Indexes'';' +
			@myNewLine+ N'Open @myCursor_DisableConstraint_PK'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_DisableConstraint_PK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Disable PK Index error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_DisableConstraint_PK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_DisableConstraint_PK; '+
			@myNewLine+ N'DEALLOCATE @myCursor_DisableConstraint_PK; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 03: Disable UQ
	IF @myDisable_UQ=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 03: Disable UQ'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_DisableConstraint_UQ Cursor;'+
			@myNewLine+ N'SET @myCursor_DisableConstraint_UQ=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #DisableConstraint_UQ ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''Current database is '+ QUOTENAME(@DestinationDatabaseName) + N''';' +
			@myNewLine+ N'PRINT ''------------- Disable Unique Constraint Indexes'';' +
			@myNewLine+ N'Open @myCursor_DisableConstraint_UQ'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_DisableConstraint_UQ INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Disable Unique Constraint Index error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_DisableConstraint_UQ INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_DisableConstraint_UQ; '+
			@myNewLine+ N'DEALLOCATE @myCursor_DisableConstraint_UQ; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 04: Disable NCIX
	IF @myDisable_NCIX=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 04: Disable NCIX'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_DisableConstraint_NCIX Cursor;'+
			@myNewLine+ N'SET @myCursor_DisableConstraint_NCIX=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #DisableConstraint_NCIX ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''Current database is '+ QUOTENAME(@DestinationDatabaseName) + N''';' +
			@myNewLine+ N'PRINT ''------------- Disable NCIX Indexes'';' +
			@myNewLine+ N'Open @myCursor_DisableConstraint_NCIX'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_DisableConstraint_NCIX INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Disable NCIX Index error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_DisableConstraint_NCIX INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_DisableConstraint_NCIX; '+
			@myNewLine+ N'DEALLOCATE @myCursor_DisableConstraint_NCIX; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 05: Disable CHK
	IF @myDisable_CHK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 05: Disable CHK'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_DisableConstraint_CHK Cursor;'+
			@myNewLine+ N'SET @myCursor_DisableConstraint_CHK=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #DisableConstraint_CHK ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''Current database is '+ QUOTENAME(@DestinationDatabaseName) + N''';' +
			@myNewLine+ N'PRINT ''------------- Disable Check Constraints'';' +
			@myNewLine+ N'Open @myCursor_DisableConstraint_CHK'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_DisableConstraint_CHK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Disable Check Constraints error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_DisableConstraint_CHK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_DisableConstraint_CHK; '+
			@myNewLine+ N'DEALLOCATE @myCursor_DisableConstraint_CHK; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 06: Disable Triggers
	IF @DestinationDisableTriggers=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 06: Disable Triggers'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_DisableTrigger Cursor;'+
			@myNewLine+ N'SET @myCursor_DisableTrigger=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #DisableTriggerTable ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''------------- Disable Triggers'';' +
			@myNewLine+ N'Open @myCursor_DisableTrigger'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_DisableTrigger INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Disable Trigger error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_DisableTrigger INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_DisableTrigger; '+
			@myNewLine+ N'DEALLOCATE @myCursor_DisableTrigger; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 07: Insert Data
	IF @ThreadCount<=1 OR (@ThreadCount>1 AND @PrintOnly=0)	--Insert Data Sequentially in regular mode
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+	N'--=======STEP 07: Insert Data'+
			CASE WHEN @LoadMethod IN ('POWERSHELL','CMD') THEN	--for Comment non-TSQL Load methods execution script'
				@myNewLine+N'	IF (SELECT OBJECT_ID(''[Tempdb].[dbo].[CommandQueue]'')) IS NOT NULL'+
				@myNewLine+N'		DROP TABLE [Tempdb].[dbo].[CommandQueue]'+
				@myNewLine+N'	CREATE TABLE [Tempdb].[dbo].[CommandQueue] ([RecordId] Int Identity Primary Key, [ID] Int,[Command] nvarchar(max),[RowCount] BIGINT,[PageCount] BIGINT,[TableSizeKb] BIGINT,[ObjectName] nvarchar(128),[Status] NVARCHAR(50), [StartTime] Datetime, [Endtime] Datetime, [ApplicationName] nvarchar(255), [CommandResult] NVARCHAR(MAX), [MultipleInsertionOrder] int, [TryCount] int);'+
				@myNewLine+N'	INSERT INTO [Tempdb].[dbo].[CommandQueue] ([ID],[Command],[RowCount],[TableSizeKb],[ObjectName],[MultipleInsertionOrder]) SELECT [ID],[SQLStatement],[RowCount],[TableSizeKb],[ObjectName],[MultipleInsertionOrder] FROM #InsertTable ORDER BY CASE [MultipleInsertionOrder] WHEN 1 THEN 1 ELSE 2 END ASC, [TableSizeKb] DESC,[RowCount] DESC,[MultipleInsertionOrder],[ID];'+
				@myNewLine+N'	--Use Powershell/CMD script to dequeue [CommandQueue] or Run below command resultset in one or multiple Powershell/CMD consoles.'+
				@myNewLine+N'	--bcp "SELECT [Command] FROM [Tempdb].[dbo].[CommandQueue] ORDER BY CASE [MultipleInsertionOrder] WHEN 1 THEN 1 ELSE 2 END ASC, [TableSizeKb] DESC,[RowCount] DESC,[MultipleInsertionOrder],[ID]" queryout "U:\Databases\Temp\DataPump.txt" -c -T -t, -S "' + CAST(@@SERVERNAME AS NVARCHAR(MAX)) + '"'+
				@myNewLine+N'	--Monitoring data transfer state:'+
				@myNewLine+N'	SELECT * FROM [Tempdb].[dbo].[CommandQueue];'+
				@myNewLine+N'	SELECT COUNT(1) AS ActiveThreadCount FROM sys.dm_exec_sessions as mySession inner join sys.dm_exec_requests as myRequest on mySession.session_id=myRequest.session_id  WHERE [mySession].[program_name]=''dbatools PowerShell module - dbatools.io'' AND [mySession].[database_id]=DB_ID() AND [myRequest].[command]=''BULK INSERT'';'+
				@myNewLine+N'	SELECT [ID],[SQLStatement],[RowCount],[TableSizeKb] FROM #InsertTable ORDER BY CASE [MultipleInsertionOrder] WHEN 1 THEN 1 ELSE 2 END ASC, [TableSizeKb] DESC,[RowCount] DESC,[MultipleInsertionOrder],[ID];'
			ELSE
				@myNewLine+ N'DECLARE @myCursor_InsertData Cursor;'+
				@myNewLine+	N'CREATE TABLE ' + CAST(@myLogTableName AS NVARCHAR(MAX)) + N' ([ID] BIGINT IDENTITY,[object_name] nvarchar(256),last_commited_batch BIGINT, [log_time] DATETIME DEFAULT (GETDATE())) ON [PRIMARY]'+
				@myNewLine+ N'DECLARE @myCursor_InsertData Cursor;'+
				@myNewLine+ N'SET @myCursor_InsertData=CURSOR For'+
				@myNewLine+	N'	SELECT [ID],[SQLStatement] FROM #InsertTable ORDER BY CASE [MultipleInsertionOrder] WHEN 1 THEN 1 ELSE 2 END ASC, [TableSizeKb] DESC,[RowCount] DESC,[MultipleInsertionOrder],[ID];'+
				@myNewLine+ N''+
				@myNewLine+ N'PRINT ''------------- Insert Data'';' +
				@myNewLine+ N'Open @myCursor_InsertData'+
				@myNewLine+ N'	FETCH NEXT FROM @myCursor_InsertData INTO @mySQLStatementID,@mySQLStatement'+
				@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
				@myNewLine+ N'		BEGIN'+
				@myNewLine+ N'			BEGIN TRY'+
				@myNewLine+ N'				IF N'''+ CAST(@LoadMethod AS NVARCHAR(MAX)) +''' IN (N''TSQL'')'+
				@myNewLine+ N'				BEGIN'+
				@myNewLine+ N'					PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
				@myNewLine+ N'					PRINT N''Use below script to follow batch insert operations:'';'+
				@myNewLine+ N'					PRINT N''SELECT [object_name],MAX(last_commited_batch) AS last_commited_batch, MAX(log_time) AS log_time FROM ' + CAST(@myLogTableName AS NVARCHAR(MAX)) + N' WITH (NOLOCK) GROUP BY [object_name]'';'+
				@myNewLine+ N'					EXEC (@mySQLStatement);'+
				@myNewLine+ N'				END'+
				@myNewLine+ N'				IF N'''+ CAST(@LoadMethod AS NVARCHAR(MAX)) +''' IN (N''CMD'',N''POWERSHELL'')'+
				@myNewLine+ N'					EXEC DBA.dbo.dbasp_print_text @mySQLStatement'+
				@myNewLine+ N'			END TRY'+
				@myNewLine+ N'			BEGIN CATCH'+
				@myNewLine+ N'				SET @CustomMessage=''Insert Data error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
				@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
				@myNewLine+ N'			END CATCH'+
				@myNewLine+ N''+
				@myNewLine+ N'			FETCH NEXT FROM @myCursor_InsertData INTO @mySQLStatementID,@mySQLStatement'+
				@myNewLine+ N'		END '+
				@myNewLine+ N'CLOSE @myCursor_InsertData; '+
				@myNewLine+ N'DEALLOCATE @myCursor_InsertData; '+
				@myNewLine+	N'DROP TABLE ' + CAST(@myLogTableName AS NVARCHAR(MAX)) + N'; '
			END+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END
	ELSE	--Insert Data in parallel mode via jobs
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+	N'--=======STEP 07: Insert Data'+
			CASE WHEN @LoadMethod IN (N'POWERSHELL',N'CMD') THEN	--for Comment non-TSQL Load methods execution script'
				@myNewLine+N'	IF (SELECT OBJECT_ID(''[Tempdb].[dbo].[CommandQueue]'')) IS NOT NULL'+
				@myNewLine+N'		DROP TABLE [Tempdb].[dbo].[CommandQueue]'+
				@myNewLine+N'	CREATE TABLE [Tempdb].[dbo].[CommandQueue] ([RecordId] Int Identity Primary Key, [ID] Int,[Command] nvarchar(max),[RowCount] BIGINT,[PageCount] BIGINT,[TableSizeKb] BIGINT,[ObjectName] nvarchar(128),[Status] NVARCHAR(50), [StartTime] Datetime, [Endtime] Datetime, [ApplicationName] nvarchar(255), [CommandResult] NVARCHAR(MAX), [MultipleInsertionOrder] int, [TryCount] int);'+
				@myNewLine+N'	INSERT INTO [Tempdb].[dbo].[CommandQueue] ([ID],[Command],[RowCount],[TableSizeKb],[ObjectName],[MultipleInsertionOrder]) SELECT [ID],[SQLStatement],[RowCount],[TableSizeKb],[ObjectName],[MultipleInsertionOrder] FROM #InsertTable ORDER BY CASE [MultipleInsertionOrder] WHEN 1 THEN 1 ELSE 2 END ASC, [TableSizeKb] DESC,[RowCount] DESC,[MultipleInsertionOrder],[ID];'+
				@myNewLine+N'	--Use Powershell/CMD script to dequeue [CommandQueue] or Run below command resultset in one or multiple Powershell/CMD consoles.'+
				@myNewLine+N'	--bcp "SELECT [Command] FROM [Tempdb].[dbo].[CommandQueue] ORDER BY CASE [MultipleInsertionOrder] WHEN 1 THEN 1 ELSE 2 END ASC, [TableSizeKb] DESC,[RowCount] DESC,[MultipleInsertionOrder],[ID]" queryout "U:\Databases\Temp\DataPump.txt" -c -T -t, -S "' + CAST(@@SERVERNAME AS NVARCHAR(MAX)) + '"'+
				@myNewLine+N'	--Monitoring data transfer state:'+
				@myNewLine+N'	SELECT * FROM [Tempdb].[dbo].[CommandQueue];'+
				@myNewLine+N'	SELECT COUNT(1) AS ActiveThreadCount FROM sys.dm_exec_sessions as mySession inner join sys.dm_exec_requests as myRequest on mySession.session_id=myRequest.session_id  WHERE [mySession].[program_name]=''dbatools PowerShell module - dbatools.io'' AND [mySession].[database_id]=DB_ID() AND [myRequest].[command]=''BULK INSERT'';'+
				@myNewLine+N'	SELECT [ID],[SQLStatement],[RowCount],[TableSizeKb] FROM #InsertTable ORDER BY CASE [MultipleInsertionOrder] WHEN 1 THEN 1 ELSE 2 END ASC, [TableSizeKb] DESC,[RowCount] DESC,[MultipleInsertionOrder],[ID];'
			ELSE
				@myNewLine+	N'CREATE TABLE ' + CAST(@myLogTableName AS NVARCHAR(MAX)) + N' ([ID] BIGINT IDENTITY,[object_name] nvarchar(256),last_commited_batch BIGINT, [log_time] DATETIME DEFAULT (GETDATE())) ON [PRIMARY]'+
				@myNewLine+ N'USE [DBA]'+
				@myNewLine+ N'DECLARE @BatchId INT'+
				@myNewLine+ N'DECLARE @SQLCommandsTable [dbo].[SQLCommandsTableType]'+
				@myNewLine+ N'DECLARE @DegreeOfPrallelism INT'+
				@myNewLine+ N'DECLARE @RetryAttemptsOnFailure INT'+
				@myNewLine+ N'DECLARE @JobPrefixName sysname'+
				@myNewLine+ N'DECLARE @PrintOnly BIT'+
				@myNewLine+ N''+
				@myNewLine+ N'SET @BatchId=99'+
				@myNewLine+ N'SET @DegreeOfPrallelism='+ CAST(@ThreadCount AS NVARCHAR(10))+
				@myNewLine+ N'SET @RetryAttemptsOnFailure=2'+
				@myNewLine+ N'SET @PrintOnly='+ CAST(@PrintOnly AS NVARCHAR(1))+
				@myNewLine+ N'INSERT INTO @SQLCommandsTable([Id],[SQLStatement])'+
				@myNewLine+ N'SELECT ROW_NUMBER() OVER (ORDER BY CASE [MultipleInsertionOrder] WHEN 1 THEN 1 ELSE 2 END ASC, [TableSizeKb] DESC,[RowCount] DESC,[MultipleInsertionOrder],[ID]),[SQLStatement] FROM #InsertTable'+
				@myNewLine+ N'PRINT ''------------- Insert Data via Job'';' +
				@myNewLine+ N'EXECUTE [DBA].[dbo].[dbasp_execute_multiple_sql] @BatchId,@SQLCommandsTable,@DegreeOfPrallelism,@RetryAttemptsOnFailure,DEFAULT,@PrintOnly'+
				@myNewLine+ N'SELECT [ID],[SQLStatement],[RowCount],[PageCount],[TableSizeKb] FROM #InsertTable ORDER BY CASE [MultipleInsertionOrder] WHEN 1 THEN 1 ELSE 2 END ASC, [TableSizeKb] DESC,[RowCount] DESC,[ID]	--Executopn orders and batch status'+
				@myNewLine+ N'SELECT [object_name],MAX(last_commited_batch) AS last_commited_batch, MAX(log_time) AS log_time FROM ' + CAST(@myLogTableName AS NVARCHAR(MAX)) + N' WITH (NOLOCK) GROUP BY [object_name] ORDER BY 3 DESC	--Followe batch insert operations'+
				@myNewLine+ N'PRINT ''------------- !!! Copy printed output script and execute it (or replace @PrintOnly with 0 value) to execute it automatically''' +
				@myNewLine+ N'PRINT ''------------- !!! Wait until Insert Jobs finished, then follow below scripts''' +
				@myNewLine+ N''+
				@myNewLine+ N'USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+	N'DROP TABLE ' + CAST(@myLogTableName AS NVARCHAR(MAX)) + N'; '
			END+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 08: Enable Triggers
	IF @DestinationDisableTriggers=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 08: Enable Triggers'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_EnableTrigger Cursor;'+
			@myNewLine+ N'SET @myCursor_EnableTrigger=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #EnableTriggerTable ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''------------- Enable Triggers'';' +
			@myNewLine+ N'Open @myCursor_EnableTrigger'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_EnableTrigger INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Enable Trigger error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_EnableTrigger INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_EnableTrigger; '+
			@myNewLine+ N'DEALLOCATE @myCursor_EnableTrigger; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 09: Enable CHK
	IF @myDisable_CHK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 09: Enable CHK'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_EnableConstraint_CHK Cursor;'+
			@myNewLine+ N'SET @myCursor_EnableConstraint_CHK=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #EnableConstraint_CHK ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''------------- Enable Check Constraints'';' +
			@myNewLine+ N'Open @myCursor_EnableConstraint_CHK'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_EnableConstraint_CHK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Enable Check Constraint error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_EnableConstraint_CHK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_EnableConstraint_CHK; '+
			@myNewLine+ N'DEALLOCATE @myCursor_EnableConstraint_CHK; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 10: Enable NCIX
	IF @myDisable_NCIX=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 10: Enable NCIX'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_EnableConstraint_NCIX Cursor;'+
			@myNewLine+ N'SET @myCursor_EnableConstraint_NCIX=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #EnableConstraint_NCIX ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''------------- Enable NCIX indexes'';' +
			@myNewLine+ N'Open @myCursor_EnableConstraint_NCIX'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_EnableConstraint_NCIX INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Enable NCIX indexes error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_EnableConstraint_NCIX INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_EnableConstraint_NCIX; '+
			@myNewLine+ N'DEALLOCATE @myCursor_EnableConstraint_NCIX; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 11: Enable UQ
	IF @myDisable_UQ=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 11: Enable UQ'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_EnableConstraint_UQ Cursor;'+
			@myNewLine+ N'SET @myCursor_EnableConstraint_UQ=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #EnableConstraint_UQ ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''------------- Enable Unique Constraint indexes'';' +
			@myNewLine+ N'Open @myCursor_EnableConstraint_UQ'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_EnableConstraint_UQ INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Enable Unique Constraint indexes error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_EnableConstraint_UQ INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_EnableConstraint_UQ; '+
			@myNewLine+ N'DEALLOCATE @myCursor_EnableConstraint_UQ; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 12: Enable PK
	IF @myDisable_PK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 12: Enable PK'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_EnableConstraint_PK Cursor;'+
			@myNewLine+ N'SET @myCursor_EnableConstraint_PK=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #EnableConstraint_PK ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''------------- Enable PK Constraint indexes'';' +
			@myNewLine+ N'Open @myCursor_EnableConstraint_PK'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_EnableConstraint_PK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Enable PK Constraint indexes error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_EnableConstraint_PK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_EnableConstraint_PK; '+
			@myNewLine+ N'DEALLOCATE @myCursor_EnableConstraint_PK; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 13: Create FK
	IF @myDisable_FK=1
	BEGIN
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'--=======STEP 13: Create FK'+
			CASE WHEN @ThreadCount>1 AND @PrintOnly=1 THEN	--Insert Data in parallel mode
				@myNewLine+ N'--USE '+ QUOTENAME(@DestinationDatabaseName) + N';'+
				@myNewLine+ N'--DECLARE @mySQLStatement NVARCHAR(max);'+
				@myNewLine+ N'--DECLARE @mySQLStatementID INT;'+
				@myNewLine+ N'--DECLARE @CustomMessage nvarchar(255)'+
				@myNewLine+ N'--'+
				@myNewLine+ N'--SET QUOTED_IDENTIFIER ON'+
				@myNewLine+ N'--SET @mySQLStatement = CAST(N'''' as NVARCHAR(MAX))'+
				@myNewLine+ N'--'
			ELSE N'' END+
			@myNewLine+ N'DECLARE @myCursor_CreateConstraint_FK Cursor;'+
			@myNewLine+ N'SET @myCursor_CreateConstraint_FK=CURSOR For'+
			@myNewLine+	N'	SELECT ID,SQLStatement FROM #CreateConstraint_FK ORDER BY ID;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''------------- Create FK Constraints'';' +
			@myNewLine+ N'Open @myCursor_CreateConstraint_FK'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor_CreateConstraint_FK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + CAST(getdate() as nvarchar(50)) + ''):	'' + CAST(@mySQLStatementID as nvarchar(20)) + N''-'' + SUBSTRING(@mySQLStatement,1,2500);'+
			@myNewLine+ N'				EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				SET @CustomMessage=''Create FK Constraint error on '+QUOTENAME(@DestinationDatabaseName)+N'''' +
			@myNewLine+ N'				EXECUTE ' + QUOTENAME(DB_NAME()) + N'.[dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor_CreateConstraint_FK INTO @mySQLStatementID,@mySQLStatement'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor_CreateConstraint_FK; '+
			@myNewLine+ N'DEALLOCATE @myCursor_CreateConstraint_FK; '+
			@myNewLine+ N''
			AS NVARCHAR(MAX))
	END

	--=======STEP 14: Reset Source Recovery model and remove any created optional snapshot
	SET @mySQLScript=@mySQLScript+
		CAST(
			@myNewLine+ N'--=======STEP 14: Reset Source Recovery model and remove any created optional snapshot'+
			@myNewLine+	N'DBCC TRACEOFF(610, -1);	--Disable Minimally logged operations'+
			CASE WHEN @DestinationRecoveryModel  IN (N'SIMPLE','BULK') THEN
					@myNewLine+ N'USE [master];'+
					@myNewLine+	N'ALTER DATABASE ' + QUOTENAME(@DestinationDatabaseName) + N' SET RECOVERY ' + (SELECT [recovery_model_desc] FROM sys.databases WHERE [name]=@DestinationDatabaseName) + N' WITH NO_WAIT'
			ELSE N'' END +
			CASE WHEN @UseSnapshotOfSourceDB=1 AND @SourceDatabaseName != @mySourceConsistentDatabase THEN
					@myNewLine+ N'USE [master];'+
					@myNewLine+ N'Drop Database ' + QUOTENAME(@mySourceConsistentDatabase)
			ELSE N'' END
		AS NVARCHAR(MAX))

	--=======STEP 15: Show generated commands to user
	SET @mySQLScript=@mySQLScript+
		CAST(
			@myNewLine+ N'--=======STEP 15: Show generated commands to user' +
			CASE WHEN @PrintOnly=1 THEN @myNewLine+N'*/' ELSE N''	END +	--for Print only Command, Comment execution
			CASE WHEN @PrintOnly=1 THEN 
						CASE @myDisable_FK WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Drop FK Constraints'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #DropConstraint_FK UNION ALL '
						ELSE N'' END +
						CASE @myDisable_PK WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Disable PK Constraints'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #DisableConstraint_PK UNION ALL '
						ELSE N'' END +
						CASE @myDisable_UQ WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Disable UQ Constraints'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #DisableConstraint_UQ UNION ALL '
						ELSE N'' END +
						CASE @myDisable_NCIX WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Disable NCIX Indexes'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #DisableConstraint_NCIX UNION ALL '
						ELSE N'' END +
						CASE @myDisable_CHK WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Disable Check Constraints'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #DisableConstraint_CHK UNION ALL '
						ELSE N'' END +
						CASE @DestinationDisableTriggers WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Disable Triggers'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #DisableTriggerTable UNION ALL ' 
						ELSE N'' END +
										@myNewLine+ N'SELECT NULL,''------------- Insert Records'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #InsertTable UNION ALL ' +
						CASE @DestinationDisableTriggers WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Enable Triggers'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #EnableTriggerTable UNION ALL '
						ELSE N'' END +
						CASE @myDisable_CHK WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Re-Enable Check Constraints'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #EnableConstraint_CHK UNION ALL'
						ELSE N'' END +
						CASE @myDisable_NCIX WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Re-Enable NCIX Indexes'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #EnableConstraint_NCIX UNION ALL'
						ELSE N'' END +
						CASE @myDisable_UQ WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Re-Enable UQ Constraints'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #EnableConstraint_UQ UNION ALL'
						ELSE N'' END +
						CASE @myDisable_PK WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- Re-Enable PK Constraints'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #EnableConstraint_PK UNION ALL'
						ELSE N'' END +
						CASE @myDisable_FK WHEN 1 THEN
										@myNewLine+ N'SELECT NULL,''------------- ReCreate FK Constraints'' UNION ALL ' +
										@myNewLine+ N'SELECT ID,SQLStatement FROM #CreateConstraint_FK UNION ALL'
						ELSE N'' END
					ELSE N'' END 	--for Print only Command, Return commands list
		AS NVARCHAR(MAX))

	SET @mySQLScript = CAST(LEFT(@mySQLScript,LEN(@mySQLScript)-LEN(N' UNION ALL')) AS NVARCHAR(MAX))

	--=======STEP 16: Drop Temporary tables
	SET @mySQLScript=@mySQLScript+
		CAST(
			@myNewLine+	N'--=======STEP 16: Drop Temporary tables'+
			CASE @myDisable_FK WHEN 1 THEN			@myNewLine+	N'DROP TABLE #DropConstraint_FK; ' ELSE N'' END +
			CASE @myDisable_PK WHEN 1 THEN			@myNewLine+	N'DROP TABLE #DisableConstraint_PK; ' ELSE N'' END +
			CASE @myDisable_UQ WHEN 1 THEN			@myNewLine+	N'DROP TABLE #DisableConstraint_UQ; ' ELSE N'' END +
			CASE @myDisable_NCIX WHEN 1 THEN		@myNewLine+	N'DROP TABLE #DisableConstraint_NCIX; ' ELSE N'' END +
			CASE @myDisable_CHK WHEN 1 THEN			@myNewLine+	N'DROP TABLE #DisableConstraint_CHK; ' ELSE N'' END +
			CASE @DestinationDisableTriggers WHEN 1 THEN		@myNewLine+	N'DROP TABLE #DisableTriggerTable; ' ELSE N'' END +
													@myNewLine+	N'DROP TABLE #ClusteredColumns; '+
													@myNewLine+	N'DROP TABLE #UniqueColumnSets; '+
													@myNewLine+	N'DROP TABLE #UniqueColumnSetStats; '+
													@myNewLine+	N'DROP TABLE #TableSortResult; '+
													@myNewLine+	N'DROP TABLE #InsertTable; '+
			CASE @DestinationDisableTriggers WHEN 1 THEN		@myNewLine+	N'DROP TABLE #EnableTriggerTable; ' ELSE N'' END +
			CASE @myDisable_CHK WHEN 1 THEN			@myNewLine+	N'DROP TABLE #EnableConstraint_CHK; '  ELSE N'' END +
			CASE @myDisable_NCIX WHEN 1 THEN			@myNewLine+	N'DROP TABLE #EnableConstraint_NCIX; '  ELSE N'' END +
			CASE @myDisable_UQ WHEN 1 THEN			@myNewLine+	N'DROP TABLE #EnableConstraint_UQ; '  ELSE N'' END +
			CASE @myDisable_PK WHEN 1 THEN			@myNewLine+	N'DROP TABLE #EnableConstraint_PK; '  ELSE N'' END +
			CASE @myDisable_FK WHEN 1 THEN			@myNewLine+	N'DROP TABLE #CreateConstraint_FK; '  ELSE N'' END +
			@myNewLine+	N''
		AS NVARCHAR(MAX))

	--===========================================================Powershell Dequeue module (save this text as a ps1 file)
	SET @myPowershellDequeue=N'
	/*
		#--===================================================================================================================
		#--===========================================================Powershell Dequeue module (save this text as a .ps1 file)
		#--===================================================================================================================
		# sqldeep.com
		# Author: golchoobian@sqldeep.com
		#For avoiding connection timeout exception run below query only once on you client machine that running dbatools, you can set 0 as -Value parameter or 65535
		#	Get-DbatoolsConfig -FullName sql.connection.timeout
		#	Set-DbatoolsConfig -FullName sql.connection.timeout -Value 30		#65535=18Hour or 2,147,483,647
		#	Get-DbatoolsConfig | Register-DbatoolsConfig
		#--------------------------------------------------------------Parameters.
		Param(
			[switch]$UI, #Use interactive mode
			[string]$ApplicationName, #This parameter used to trace thread on SQL Server sesions
			[string]$SqlInstance, #the sql server instance that host queue table
			[PSCredential]$SqlServerInstanceCred, #Credential for connecting to specified SQL Server Instance
			[string]$Database, #the database name contained queue table
			[string]$DequeueStartQuery, #Dequeuing start statement
			[string]$DequeueFinishedQuery, #Dequeuing finish statement
			[int]$FailureTryCount, #Number of execution try count after failure
			[int]$PauseCount #Number of command execution before reverting control to user console, used for managing thread execution count
			)

		#--------------------------------------------------------------Functions start here.
		#Raise Warning message and if required exit from app
		Function RaiseMessage
		{
			Param
				(
				[Parameter(Mandatory=$true)][string]$Message,
				[switch]$Info,
				[switch]$Warning,
				[switch]$Error,
				[switch]$Exit
				)

			If($Warning) 
				{Write-Host $Message -ForegroundColor Yellow}
			ElseIf($Error) 
				{Write-Host $Message -ForegroundColor Red}
			Else
				{Write-Host $Message -ForegroundColor Green}

			If ($Exit){Exit}
		}

		#--------------------------------------------------------------Collecting required parameters via console
		$myQueueConnectionParameters=@{} #Create a hash table for defining parameters dynamically
		$myDefaultApplicationName="Therad $env:COMPUTERNAME-" + (Get-Random -Maximum 1000).ToString()
		$myDefaultDatabase = "tempdb"
		$myDefaultPauseCount = -1
		$myDefaultFailureTryCount = 3
		$myDefaultDequeueStartQuery="
			DECLARE @myResult TABLE (RecordId INT,Command NVARCHAR(MAX));
			WITH myResult AS (SELECT TOP 1 [RecordId],[Command],[Status],[StartTime],[ApplicationName],[TryCount] FROM [Tempdb].[dbo].[CommandQueue] WHERE [Status] IS NULL OR ([Status]=''Failed'' AND [TryCount]<`$(FailureTryCount) ) ORDER BY [RecordId])
			UPDATE [myResult] SET [myResult].[Status]=N''Started'',[myResult].[StartTime]=getdate(),[myResult].[ApplicationName]=APP_NAME(),[myResult].[TryCount]=ISNULL([myResult].[TryCount],0)+1 OUTPUT [Inserted].[RecordId],[Inserted].[Command] INTO @myResult;
			SELECT [RecordId],[Command] FROM @myResult"
		$myDefaultDequeueFinishedQuery = "
			UPDATE [Tempdb].[dbo].[CommandQueue] SET [Status] = `$(Status), [Endtime]=getdate(), CommandResult=`$(CommandResult)+ISNULL(CommandResult,'''') WHERE RecordId=`$(RecordId);"

		If ($UI)
		{
			$ApplicationName = Read-Host -Prompt "Enter a unique Application name for this sql connection (default is $myDefaultApplicationName)"
			$SqlInstance = Read-Host -Prompt "SQL Server Instance (default is $env:COMPUTERNAME)"
			$SqlServerInstanceCred = Get-Credential -Message "Enter credential for loging to SQL Server"
			$Database = Read-Host -Prompt "Queue database name (default is $myDefaultDatabase)"
			$FailureTryCount = Read-Host -Prompt "Number of retry if command execution is failed (default is $myDefaultFailureTryCount)"
			$PauseCount = Read-Host -Prompt "Number of execution before going to pause state (default is $myDefaultPauseCount for countinues running without any pause)"
			$DequeueStartQuery = Read-Host -Prompt "T-SQL statement for dequeue (default is $myDefaultDequeueStartQuery)"
			$DequeueFinishedQuery = Read-Host -Prompt "T-SQL statement when finishing dequeue request process (default is $myDefaultDequeueFinishedQuery)"
		}

		If(-not($ApplicationName)) {$ApplicationName=$myDefaultApplicationName}
		If(-not($SqlInstance)) {$SqlInstance="$env:COMPUTERNAME"}
		If(-not($Database)) {$Database="$myDefaultDatabase"}
		If(-not($DequeueStartQuery)) {$DequeueStartQuery="$myDefaultDequeueStartQuery"}
		If(-not($DequeueFinishedQuery)) {$DequeueFinishedQuery="$myDefaultDequeueFinishedQuery"}
		If(-not($FailureTryCount)) {$FailureTryCount=$myDefaultFailureTryCount}
		If(-not($PauseCount)) {$PauseCount=$myDefaultPauseCount}
		If (!($SqlServerInstanceCred) -and ($SqlServerInstanceCred.UserName).Length>0)
		{
			$myUser=$SqlServerInstanceCred.UserName
			$SqlServerInstanceCred=Get-Credential -UserName $myUser -Message "Enter credential for loging to SQL Server"
		}

		$myApplicationName=$ApplicationName
		$mySqlInstance=$SqlInstance
		$myDatabase=$Database
		$myDequeueStartQuery=$DequeueStartQuery
		$myDequeueFinishedQuery=$DequeueFinishedQuery
		$myFailureTryCount=$FailureTryCount
		$myPauseCount=$PauseCount
		$mySqlServerInstanceCred=$SqlServerInstanceCred

		#Declare Queue database connection parameters (This method called "Splatting – build parameters dynamically")
		$myQueueConnectionParameters.Database=$myDatabase
		$myQueueConnectionParameters.ServerInstance=$mySqlInstance
		$myQueueConnectionParameters.HostName=$myApplicationName
		If ($mySqlServerInstanceCred) {$myQueueConnectionParameters.Credential=$mySqlServerInstanceCred}

		#--------------------------------------------------------------Main Body
		RaiseMessage -Message "==========Thread Informtion==========" -Info
		RaiseMessage -Message "ApplicationName: $myApplicationName" -Info
		RaiseMessage -Message "SqlInstance: $mySqlInstance" -Info
		RaiseMessage -Message "SqlServerInstanceCred: $($mySqlServerInstanceCred.UserName)" -Info
		RaiseMessage -Message "Database: $myDatabase" -Info
		RaiseMessage -Message "FailureTryCount: $myFailureTryCount" -Info
		RaiseMessage -Message "PauseCount: $myPauseCount" -Info
		#RaiseMessage -Message "DequeueStartQuery: $myDequeueStartQuery" -Info
		#RaiseMessage -Message "DequeueFinishedQuery: $myDequeueFinishedQuery" -Info
		RaiseMessage -Message "=====================================" -Info

		#Change Title
		$host.UI.RawUI.WindowTitle = $myApplicationName

		#Pick new record(s) from queue while it does not have any record
		$myPauseCounter=0
		while(1 -eq 1)
		{
			#Initializing Dequeue process, Pick record(s) from queue and immediately update record(s) status
			$myQueueConnectionParameters.Remove("Variable")
			$myQueryParameters = "FailureTryCount=$($myFailureTryCount)"
			$myQueueConnectionParameters.Query=$myDequeueStartQuery
			$myQueueConnectionParameters.Variable=$myQueryParameters

			$myDatarows = Invoke-Sqlcmd @myQueueConnectionParameters -AS DataRow
    
			#Exit loop if there is no any records in the queue
			If($myDatarows -eq $null) {break}
    
			#Execute each record PS command content and update record status immediately
			foreach ($myRow in $myDatarows)
			{
				try
				{
					RaiseMessage -Message "=====Executing Command with RecordId: $($myRow.Item("RecordId"))" -Info
					Invoke-Expression -Command $myRow.Item("Command") | Out-String -OutVariable myCommandResult
					$myStatus="Succeed"
				}
				catch
				{
					$myCommandResult="$_.Exception"
					$myStatus="Failed"
				}

				#Finalizing Dequeue process
				$myQueueConnectionParameters.Remove("Variable")
				$myQueryParameters = "Status=N''$($myStatus)''", "CommandResult=N''$($myCommandResult)''", "RecordId=$($myRow.Item("RecordId"))"
				$myQueueConnectionParameters.Query=$myDequeueFinishedQuery
				$myQueueConnectionParameters.Variable=$myQueryParameters
				Invoke-Sqlcmd @myQueueConnectionParameters
        
				#Pause execution if required
				$myPauseCounter += 1
				$host.UI.RawUI.WindowTitle = $myApplicationName + " - " + ($myPauseCounter).ToString() + (&{If ($myPauseCount -ne -1) {"/"+($myPauseCount).ToString()}}) + " task executed." #Rename Title
				If ($myPauseCount -ne -1 -And $myPauseCounter -ge $myPauseCount)
				{
					$host.UI.RawUI.WindowTitle = $myApplicationName + " - " + ($myPauseCounter).ToString() + "/" + ($myPauseCount).ToString() + " task executed (Paused...)" #Rename Title
					$myPauseCount = Read-Host -Prompt "Number of execution before going to pause state (default is $myDefaultPauseCount for countinues running without any pause)"
					If(-not($myPauseCount)) {$myPauseCount=$myDefaultPauseCount}
					$myPauseCounter=0
				}
			}
		}
		$host.UI.RawUI.WindowTitle = $myApplicationName + " - " + ($myPauseCounter).ToString() + (&{If ($myPauseCount -ne -1) {"/"+($myPauseCount).ToString()}}) + " task executed (Done)" #Rename Title
		'
	--Print Generated Command
	EXEC dbo.dbasp_print_text @mySQLScript
	IF @LoadMethod=N'POWERSHELL'
		EXEC dbo.dbasp_print_text @myPowershellDequeue

	--Execute Generated Command
	IF @ThreadCount<=1 AND @PrintOnly=0
		PRINT (@myNewLine + N'--Excexution Report--');

		--=======Start of executing commands
		BEGIN TRY
			EXECUTE (@mySQLScript);
		END TRY
		BEGIN CATCH
			DECLARE @CustomMessage NVARCHAR(255)
			SET @CustomMessage='Bulk Insert error on ' + @DestinationDatabaseName
			EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
		END CATCH
		--=======End of executing commands
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_transfer_all_tables_data', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-06-19', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_transfer_all_tables_data', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2020-04-15', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_transfer_all_tables_data', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.9', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_transfer_all_tables_data', NULL, NULL
GO
