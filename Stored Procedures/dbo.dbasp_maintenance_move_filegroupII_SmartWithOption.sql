SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		<Golchoobian>
-- Create date: <3/26/2016>
-- Version:		<3.0.0.6>
-- Description:	<Move all tables from @SourceFilegroup to TargetFilegroups>
-- Input Parameters:
--	@SourceFilegroup:			'Primary' or 'xxx' Filegroup that you want to move it's objects
--	@TargetHeapFilegroup:		'HeapFG' or 'xxx' Filegroup name for heap table objects of @SourceFilegroup
--	@TargetClusteredFilegroup:	'ClusterFG' or 'xxx' Filegroup name for clustered table objects of @SourceFilegroup
--	@TargetIndexFilegroup:		'IndexFG' or 'xxx' Filegroup name for NCI Index objects of @SourceFilegroup
--	@TargetFilestreamFilegroup:	'FilestreamFG' or 'xxx' Filegroup name for Filestream column objects of tables under @SourceFilegroup
--	@IndexWithOptions:			Null for Original Options or any extra/replaceable with options for index creation, maximum switches are (you can modify sp code to force some smart options): N'STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, ONLINE = OFF, DATA_COMPRESSION = PAGE, MAXDOP=0'
--	@ConstraintWithOptions:		Null for Original Options or any extra/replaceable with options for constraint creation, maximum switches are (you can modify sp code to force some smart options): N'STATISTICS_NORECOMPUTE = OFF, DATA_COMPRESSION = PAGE'
--	@UsePartitioningForTextImageMovement: 0 or 1, use 1 to move TEXT/IMAGE data via Partitioning feature, but it will create much free space at the end of data file(s)
--	@ExceptedObjectIds:			list of object_id's should be excepted from migration, default is N''
--	@PrintOnly:		0 or 1
-- =============================================
-- !!! YOU SHOULD RUN THIS SP INSIDE OF TARGET DATABASE !!!
CREATE PROCEDURE [dbo].[dbasp_maintenance_move_filegroupII_SmartWithOption]
(
	@SourceFilegroup NVARCHAR(128)=N'Primary',
	@TargetHeapFilegroup NVARCHAR(128)=N'HeapTabelFG',
	@TargetClusteredFilegroup NVARCHAR(128)=N'ClusterdTabelFG',
	@TargetIndexFilegroup NVARCHAR(128)=N'IndexDataFG',
	@TargetFilestreamFilegroup NVARCHAR(128)=N'FilestramDataFG',
	@IndexWithOptions NVARCHAR(1000)=N'STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, ONLINE = OFF, DATA_COMPRESSION = ROW, MAXDOP=0',	--These values will be modify original values
	@ConstraintWithOptions NVARCHAR(1000)=N'STATISTICS_NORECOMPUTE = OFF, DATA_COMPRESSION = ROW',	--These values will be modify original values
	@UsePartitioningForTextImageMovement BIT=1,
	@ExceptedObjectIds NVARCHAR(MAX)=N'',
	@PrintOnly BIT=1
)
AS
BEGIN
	SET NOCOUNT ON;

	--=====Internal Parameters
	DECLARE @myIsPrerequisitesPassed BIT
	DECLARE @myMessage nvarchar(4000)
	DECLARE @myNewLine nvarchar(10)
	DECLARE @myCursor CURSOR
	DECLARE @myTablesList CURSOR
	DECLARE @myRowIsProcessed BIT
	DECLARE @myRow_id BIGINT
	DECLARE @myObject_id INT
	DECLARE @myTableName NVARCHAR(256)
	DECLARE @myIndex_id INT
	DECLARE @myIndex_name NVARCHAR(128)
	DECLARE @myIndex_type TINYINT
	DECLARE @myIs_disabled BIT
	--DECLARE @myOriginalWithOptions NVARCHAR(1000)
	DECLARE @myGeneratedIndexWithOptions NVARCHAR(1000)
	DECLARE @myGeneratedConstraintWithOptions NVARCHAR(1000)
	DECLARE @myHas_filter BIT
	DECLARE @myFilter_definition NVARCHAR(MAX)
	DECLARE @myTableHasPrimaryKey BIT
	DECLARE @myTableHasUniqueCnst BIT
	DECLARE @myTableHasUniqueIndex BIT
	DECLARE @myTableHasIdentity BIT
	DECLARE @myTableHasRowGuidCol BIT
	DECLARE @myTableHasSpareColumn BIT
	DECLARE @myWithOption NVARCHAR(MAX)
	DECLARE @myConstraintWithOptions NVARCHAR(MAX)
	DECLARE @myTableHasFilestream BIT
	DECLARE @myFilestreamFilegroupName NVARCHAR(128)
	DECLARE @myTableHasLOB BIT
	DECLARE @mySqlStr NVARCHAR(MAX)
	DECLARE @myTempIndexName NVARCHAR(50)
	DECLARE @myTempPartitionColumnName NVARCHAR(128)
	DECLARE @myTempPartitionColumnType NVARCHAR(128)
	DECLARE @myTempPartitionColumnTypeConverted NVARCHAR(128)
	DECLARE @myTempPartitionFunctionName NVARCHAR(256)
	DECLARE @myTempPartitionSchemeNameHeap NVARCHAR(256)
	DECLARE @myTempPartitionSchemeNameClustered NVARCHAR(256)
	DECLARE @myTempPartitionSchemeNameFilestream NVARCHAR(256)
	DECLARE @myExceptedObjectIds TABLE (ObjectId INT NOT NULL)
	DECLARE @myExceptedObjectIdsXML XML
    DECLARE @myDefaultMaxDOP AS TINYINT

	--=====Parameters Initialization
	SET @myIsPrerequisitesPassed=1
	SET @myMessage=N''
	SET @mySqlStr=CAST(N'' AS NVARCHAR(MAX))
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myTempIndexName=CAST(NEWID() AS NVARCHAR(50))
	SET @IndexWithOptions=CAST(LTRIM(RTRIM(REPLACE(ISNULL(@IndexWithOptions,N''),N' ',N''))) AS NVARCHAR(MAX))
	SET @ConstraintWithOptions=CAST(LTRIM(RTRIM(REPLACE(ISNULL(@ConstraintWithOptions,N''),N' ',N''))) AS NVARCHAR(MAX))
	SET @ExceptedObjectIds=ISNULL(@ExceptedObjectIds,N'')
	SELECT @myExceptedObjectIdsXML=CAST(N'<ITEM>' + REPLACE(@ExceptedObjectIds,',','</ITEM><ITEM>')+ '</ITEM>' AS XML)
	INSERT INTO @myExceptedObjectIds ([ObjectId]) SELECT DISTINCT i.value('.', 'int') AS ObjectId FROM @myExceptedObjectIdsXML.nodes('/ITEM') AS Item(i) WHERE i.value('.', 'int')!=0
	--Determin Default Max DOP
	IF EXISTS (SELECT 1 FROM sys.[all_objects] WHERE name='database_scoped_configurations' AND [object_id]<0 AND [is_ms_shipped]=1)
	BEGIN
		--Database Scoped MAXDOP
		SELECT @myDefaultMaxDOP=CAST([value] AS SMALLINT) FROM sys.database_scoped_configurations WHERE [name]='MAXDOP'
	END
	ELSE IF EXISTS (SELECT 1 FROM sys.[all_objects] WHERE name='configurations' AND [object_id]<0 AND [is_ms_shipped]=1)
	BEGIN
		--Instance Scoped MAXDOP
		SELECT @myDefaultMaxDOP=CAST([value] AS SMALLINT) FROM sys.[configurations] WHERE name=N'max degree of parallelism'
	END
	ELSE
	BEGIN
		SET @myDefaultMaxDOP=0
	END

	--=====Prerequisites Control
	--Check @SourceFilegroup existence
	IF NOT EXISTS(SELECT 1 FROM sys.filegroups as myFG WHERE myFG.name=@SourceFilegroup)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myMessage=@myMessage + N'Source filegroup (' + @SourceFilegroup + N') does not exists.' + @myNewLine
	END
	--Check @TargetHeapFilegroup existence
	IF NOT EXISTS(SELECT 1 FROM sys.filegroups as myFG WHERE myFG.name=@TargetHeapFilegroup)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myMessage=@myMessage + N'Target heap table filegroup (' + @TargetHeapFilegroup + N') does not exists.' + @myNewLine
	END
	--Check @TargetClusteredFilegroup existence
	IF NOT EXISTS(SELECT 1 FROM sys.filegroups as myFG WHERE myFG.name=@TargetClusteredFilegroup)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myMessage=@myMessage + N'Target clustered table filegroup (' + @TargetClusteredFilegroup + N') does not exists.' + @myNewLine
	END
	--Check @TargetIndexFilegroup existence
	IF NOT EXISTS(SELECT 1 FROM sys.filegroups as myFG WHERE myFG.name=@TargetIndexFilegroup)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myMessage=@myMessage + N'Target index filegroup (' + @TargetIndexFilegroup + N') does not exists.' + @myNewLine
	END
	--Check @TargetFilestreamFilegroup existence
	IF NOT EXISTS(SELECT 1 FROM sys.filegroups as myFG WHERE myFG.name=@TargetFilestreamFilegroup)
	BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myMessage=@myMessage + N'Target filestream filegroup (' + @TargetFilestreamFilegroup + N') does not exists.' + @myNewLine
	END

	IF @myIsPrerequisitesPassed=0
	BEGIN
		Print @myMessage
		RETURN
	END

	--=====Request Proccessing
	--=====Create Table for Special Conditions
	--Tables with sapre columns can not be compressed
	CREATE TABLE #mySpecialTableList (Row_id BIGINT IDENTITY, ObjectID INT,TableHasSpareColumn BIT DEFAULT (0),TableHasLOB BIT DEFAULT (0))
	INSERT INTO #mySpecialTableList (ObjectID,TableHasSpareColumn)
	SELECT
		myColumns.[object_id] as ObjectID,
		CAST(1 as BIT) as HasSpareColumn
	FROM 
		sys.columns as myColumns
	WHERE 
		(myColumns.is_sparse=1
		OR myColumns.is_column_set=1)
		AND [myColumns].[object_id] NOT IN (SELECT [ObjectId] FROM @myExceptedObjectIds)	--Except user requested objects
	GROUP BY
		myColumns.[object_id]

	-- Update TableHasLOB Column
	MERGE [#mySpecialTableList] AS myTarget
	USING
		(
		SELECT DISTINCT
			[myObjects].[object_id]
		FROM
			sys.allocation_units as myAllocationUnits
			inner join sys.partitions as myPartition on myPartition.partition_id=myAllocationUnits.container_id
			inner join sys.indexes as myIndex on myPartition.object_id=myIndex.object_id and myPartition.index_id=myIndex.index_id
			inner join sys.all_objects as myObjects on myIndex.object_id=myObjects.object_id
		WHERE
			myAllocationUnits.type = 2	--LOB data
			AND [myObjects].[object_id] NOT IN (SELECT [ObjectId] FROM @myExceptedObjectIds)	--Except user requested objects
		) AS mySouce ([object_id]) ON ([myTarget].[ObjectID]=[mySouce].[object_id])
		WHEN MATCHED THEN UPDATE SET [myTarget].[TableHasLOB]=1
		WHEN NOT MATCHED THEN
			INSERT ([ObjectID],[TableHasLOB])
			VALUES ([mySouce].[object_id],1);
	--=====Create Commands Table
	CREATE TABLE #myCommandList (Row_id BIGINT IDENTITY, ObjectID INT,TableType INT, SqlCommand NVARCHAR(max))
	CREATE TABLE #myCleanupCommandList (Row_id BIGINT IDENTITY, ObjectID INT,TableType INT, SqlCommand NVARCHAR(max))
	--=====Iterate through tables and Indexes
	CREATE TABLE #myTablesList (Row_id BIGINT IDENTITY,[object_id] INT,TableName NVARCHAR(256),index_id INT,index_name NVARCHAR(128),
								index_type TINYINT,is_disabled BIT,has_filter BIT,filter_definition NVARCHAR(MAX),TableHasPrimaryKey BIT,
								TableHasUniqueCnst BIT,TableHasUniqueIndex BIT,TableHasIdentity BIT,TableHasRowGuidCol BIT,TableHasSpareColumn BIT,
								GeneratedIndexWithOptions NVARCHAR(1000),GeneratedConstraintWithOptions NVARCHAR(1000),TableHasFilestream BIT,FilestreamFilegroupName NVARCHAR(128),TableHasLOB BIT)
	INSERT INTO #myTablesList
			( [object_id] ,
			  TableName ,
			  index_id ,	--0=Heap,1=Clustered,>2=Nonclustered
			  index_name,
			  index_type ,	--0=Heap,1=Clustered,2=Nonclustered,3=XML,4=Spatial,5=Clustered columnstore index,6=Nonclustered columnstore index,7=Nonclustered hash index
			  is_disabled ,
			  has_filter ,
			  filter_definition,
			  TableHasPrimaryKey,
			  TableHasUniqueCnst,
			  TableHasUniqueIndex,
			  TableHasIdentity,
			  TableHasRowGuidCol,
			  TableHasSpareColumn,
			  --OriginalWithOptions,
			  GeneratedIndexWithOptions,
			  GeneratedConstraintWithOptions,
			  TableHasFilestream,
			  FilestreamFilegroupName,
			  TableHasLOB
			)
	SELECT
		myIndexes.[object_id],
		QUOTENAME(mySchema.name)+N'.'+QUOTENAME(myTables.name) as TableName,
		myIndexes.index_id,
		QUOTENAME(myIndexes.name) AS index_name,
		myIndexes.[type] as index_type,
		myIndexes.is_disabled,
		ISNULL(myIndexes.has_filter,0) AS has_filter,
		myIndexes.filter_definition,
		myIndexes.is_primary_key AS TableHasPrimaryKey,
		CAST(CASE WHEN myIndexes.is_unique_constraint=1 AND myIndexes.is_disabled=0 THEN 1 ELSE 0 END AS BIT) AS TableHasUniqueCnst,
		CAST(CASE WHEN myIndexes.is_unique=1 AND myIndexes.is_disabled=0 THEN 1 ELSE 0 END AS BIT) AS TableHasUniqueIndex,
		CASE WHEN myIndexes.[type] = 0 THEN OBJECTPROPERTY(myIndexes.[object_id], 'TableHasIdentity') ELSE NULL END AS TableHasIdentity,
		CASE WHEN myIndexes.[type] = 0 THEN OBJECTPROPERTY(myIndexes.[object_id], 'TableHasRowGuidCol') ELSE NULL END AS TableHasRowGuidCol,
		ISNULL(mySpecialTableList.TableHasSpareColumn,CAST(0 as BIT)) as TableHasSpareColumn,
		GeneratedIndexWithOptions=ISNULL(
			CASE WHEN ISNULL(CHARINDEX(N'PAD_INDEX',@IndexWithOptions),0)=0 THEN CASE WHEN myIndexes.is_padded=1 THEN N'PAD_INDEX = ON,' ELSE N'PAD_INDEX = OFF,' END ELSE N'' END + 
			CASE WHEN ISNULL(CHARINDEX(N'IGNORE_DUP_KEY',@IndexWithOptions),0)=0 THEN CASE WHEN myIndexes.[ignore_dup_key]=1 THEN N'IGNORE_DUP_KEY = ON,' ELSE N'IGNORE_DUP_KEY = OFF,' END ELSE N'' END + 
			CASE WHEN ISNULL(CHARINDEX(N'ALLOW_ROW_LOCKS',@IndexWithOptions),0)=0 THEN CASE WHEN myIndexes.[allow_row_locks]=1 THEN N'ALLOW_ROW_LOCKS = ON,' ELSE N'ALLOW_ROW_LOCKS = OFF,' END ELSE N'' END + 
			CASE WHEN ISNULL(CHARINDEX(N'ALLOW_PAGE_LOCKS',@IndexWithOptions),0)=0 THEN CASE WHEN myIndexes.[allow_page_locks]=1 THEN N'ALLOW_PAGE_LOCKS = ON,' ELSE N'ALLOW_PAGE_LOCKS = OFF,' END ELSE N'' END + 
			CASE WHEN ISNULL(CHARINDEX(N'DATA_COMPRESSION',@IndexWithOptions),0)=0 THEN CASE WHEN ISNULL(myIndexOptions.[CompressionType],0)=0 THEN N'DATA_COMPRESSION = NONE,' ELSE N'DATA_COMPRESSION = ' + CASE [myIndexOptions].[CompressionType] WHEN 0 THEN N'NONE' WHEN 1 THEN N'ROW' WHEN 2 THEN N'PAGE' WHEN 3 THEN N'COLUMNSTORE' ELSE N'NONE' END + N',' END ELSE N'' END + 
			CASE WHEN ISNULL(CHARINDEX(N'STATISTICS_NORECOMPUTE',@IndexWithOptions),0)=0 THEN CASE WHEN ISNULL(myIndexOptions.[StatisticsNoRecompute],N'OFF')=N'OFF' THEN N'STATISTICS_NORECOMPUTE = OFF,' ELSE N'STATISTICS_NORECOMPUTE = ON,' END ELSE N'' END + 
			CASE WHEN ISNULL(CHARINDEX(N'SORT_IN_TEMPDB',@IndexWithOptions),0)=0 THEN CASE WHEN ISNULL(myIndexOptions.[SortInTempdb],N'ON')=N'ON' THEN N'SORT_IN_TEMPDB = ON,' ELSE N'SORT_IN_TEMPDB = OFF,' END ELSE N'' END + 
			CASE WHEN ISNULL(CHARINDEX(N'MAXDOP',@IndexWithOptions),0)=0 THEN CASE WHEN ISNULL(@myDefaultMaxDOP,0)=0 THEN N'MAXDOP = 0,' ELSE N'MAXDOP = ' + CAST(@myDefaultMaxDOP AS NVARCHAR(50)) + N',' END ELSE N'' END + 
			CASE WHEN ISNULL(CHARINDEX(N'FILLFACTOR',@IndexWithOptions),0)=0 THEN CASE WHEN myIndexes.fill_factor>0 THEN N'FILLFACTOR = ' + CAST(myIndexes.fill_factor AS NVARCHAR(3)) + N',' ELSE N'' END ELSE N'' END ,N''),
		GeneratedConstraintWithOptions=ISNULL(
			CASE WHEN ISNULL(CHARINDEX(N'DATA_COMPRESSION',@ConstraintWithOptions),0)=0 THEN CASE WHEN ISNULL(myIndexOptions.[CompressionType],0)=0 THEN N'DATA_COMPRESSION = NONE,' ELSE N'DATA_COMPRESSION = ' + CASE [myIndexOptions].[CompressionType] WHEN 0 THEN N'NONE' WHEN 1 THEN N'ROW' WHEN 2 THEN N'PAGE' WHEN 3 THEN N'COLUMNSTORE' ELSE N'NONE' END + N',' END ELSE N'' END + 
			CASE WHEN ISNULL(CHARINDEX(N'STATISTICS_NORECOMPUTE',@ConstraintWithOptions),0)=0 THEN CASE WHEN ISNULL(myIndexOptions.[StatisticsNoRecompute],N'OFF')=N'OFF' THEN N'STATISTICS_NORECOMPUTE = OFF,' ELSE N'STATISTICS_NORECOMPUTE = ON,' END ELSE N'' END ,N''),
		TableHasFilestream=
			CASE WHEN [myTables].[filestream_data_space_id] IS NULL THEN 0 ELSE 1 END,
		FILEGROUP_NAME([myTables].[filestream_data_space_id]) AS FilestreamFilegroupName,
		ISNULL(mySpecialTableList.[TableHasLOB],CAST(0 as BIT)) as TableHasLOB
	FROM 
		sys.indexes as myIndexes
		INNER JOIN sys.data_spaces as myDataSpace on myIndexes.data_space_id=myDataSpace.data_space_id
		INNER JOIN sys.tables as myTables on myIndexes.[object_id]=myTables.[object_id]
		INNER JOIN sys.schemas as mySchema on myTables.[schema_id]=mySchema.[schema_id]
		LEFT OUTER JOIN #mySpecialTableList as mySpecialTableList on myIndexes.[object_id]=mySpecialTableList.ObjectID
		LEFT OUTER JOIN (
						SELECT
							[myIndexesII].[object_id],
							[myIndexesII].[index_id],
							MAX([myPartitionsII].[data_compression]) AS CompressionType,
							N'OFF' AS StatisticsNoRecompute ,
							N'ON' AS SortInTempdb,
							N'OFF' AS OnlineIndexing
						FROM
							sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL,NULL) AS myStatsII
							INNER JOIN sys.indexes AS myIndexesII ON myStatsII.[object_id] = myIndexesII.[object_id] AND myStatsII.index_id = myIndexesII.index_id
							INNER JOIN sys.partitions AS myPartitionsII ON myIndexesII.[object_id]=myPartitionsII.[object_id] AND myIndexesII.index_id=myPartitionsII.index_id AND myStatsII.partition_number=myPartitionsII.partition_number
						GROUP BY
							[myIndexesII].[object_id],
							[myIndexesII].[index_id]
						) AS myIndexOptions ON [myIndexes].[object_id]=[myIndexOptions].[object_id] AND [myIndexes].[index_id]=[myIndexOptions].[index_id]
	WHERE
		myTables.is_ms_shipped=0	--User Tables
		AND myDataSpace.name = @SourceFilegroup	--Tables stored in SourceFilegroup
		AND myIndexes.[object_id] NOT IN (SELECT [ObjectId] FROM @myExceptedObjectIds)	--Except user requested objects
	ORDER BY
		myIndexes.[object_id],
		myIndexes.is_disabled,
		myIndexes.index_id
	

	SET @myCursor=CURSOR FOR SELECT Row_id ,[object_id] ,TableName ,index_id ,index_name ,index_type ,is_disabled ,has_filter ,filter_definition ,TableHasPrimaryKey ,TableHasUniqueCnst ,TableHasUniqueIndex ,TableHasIdentity ,TableHasRowGuidCol ,TableHasSpareColumn ,GeneratedIndexWithOptions,GeneratedConstraintWithOptions,TableHasFilestream,FilestreamFilegroupName,TableHasLOB FROM #myTablesList
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @myRow_id ,@myObject_id ,@myTableName ,@myIndex_id ,@myIndex_name ,@myIndex_type ,@myIs_disabled ,@myHas_filter ,@myFilter_definition ,@myTableHasPrimaryKey ,@myTableHasUniqueCnst ,@myTableHasUniqueIndex ,@myTableHasIdentity ,@myTableHasRowGuidCol ,@myTableHasSpareColumn ,@myGeneratedIndexWithOptions, @myGeneratedConstraintWithOptions ,@myTableHasFilestream, @myFilestreamFilegroupName, @myTableHasLOB
	WHILE @@FETCH_STATUS=0
	BEGIN
		SET @mySqlStr=CAST(N'' AS NVARCHAR(MAX))
		SET @myRowIsProcessed=0
		SET @myTempPartitionColumnName=NULL
		SET @myTempPartitionColumnType=NULL
		SET @myTempPartitionColumnTypeConverted=NULL
		SET @myTempPartitionFunctionName=NULL
		SET @myTempPartitionSchemeNameHeap=NULL
		SET @myTempPartitionSchemeNameClustered=NULL
		SET @myTempPartitionSchemeNameFilestream=NULL
		SET @myWithOption=
				CASE	--DATA_COMPRESSION feature can not be used with Spare Column enabled tables
					WHEN LEN(@IndexWithOptions)>0 AND @myTableHasSpareColumn=0 THEN ISNULL(@myGeneratedIndexWithOptions,N'') + N',' + ISNULL(@IndexWithOptions ,N'')
					WHEN LEN(@IndexWithOptions)>0 AND @myTableHasSpareColumn=1 THEN REPLACE(REPLACE(ISNULL(@myGeneratedIndexWithOptions,N'') + N',' + ISNULL(@IndexWithOptions,N'') ,N'PAGE',N'NONE'),N'ROW',N'NONE')
					ELSE ISNULL(@myGeneratedIndexWithOptions,N'') + N',' + ISNULL(@IndexWithOptions ,N'')
				 END
		SET @myWithOption=REPLACE(REPLACE(@myWithOption,N' ',N''),N',,',N',')
		SET @myWithOption=CASE WHEN LEFT(@myWithOption,1)=N',' THEN RIGHT(@myWithOption,LEN(@myWithOption)-1) ELSE @myWithOption END
		SET @myWithOption=CASE WHEN RIGHT(@myWithOption,1)=N',' THEN LEFT(@myWithOption,LEN(@myWithOption)-1) ELSE @myWithOption END
		SET @myConstraintWithOptions=
				CASE	--DATA_COMPRESSION feature can not be used with Spare Column enabled tables
					WHEN LEN(@ConstraintWithOptions)>0 AND @myTableHasSpareColumn=0 THEN ISNULL(@myGeneratedConstraintWithOptions,N'') + N',' + ISNULL(@ConstraintWithOptions,N'')
					WHEN LEN(@ConstraintWithOptions)>0 AND @myTableHasSpareColumn=1 THEN REPLACE(REPLACE(ISNULL(@myGeneratedConstraintWithOptions,N'') + N',' + ISNULL(@ConstraintWithOptions,N'') ,N'PAGE',N'NONE'),N'ROW',N'NONE')
					ELSE ISNULL(@myGeneratedConstraintWithOptions,N'') + N',' + ISNULL(@ConstraintWithOptions,N'')
				 END
		SET @myConstraintWithOptions=REPLACE(REPLACE(@myConstraintWithOptions,N' ',N''),N',,',N',')
		SET @myConstraintWithOptions=CASE WHEN LEFT(@myConstraintWithOptions,1)=N',' THEN RIGHT(@myConstraintWithOptions,LEN(@myConstraintWithOptions)-1) ELSE @myConstraintWithOptions END
		SET @myConstraintWithOptions=CASE WHEN RIGHT(@myConstraintWithOptions,1)=N',' THEN LEFT(@myConstraintWithOptions,LEN(@myConstraintWithOptions)-1) ELSE @myConstraintWithOptions END

		--=====HEAP TABLE
		-- Check whether the heap table has an identity column.
		-- If it does - apply the CI with the new filegroup on the identity column.
		-- Once done - remove the CI. If it does not - check whether the table has a primary
		-- key and apply the CI there on the new file group, and then drop the CI.
		-- If the table does not have an identity column, or a primary key,
		-- then a new identity column is created for the table and the CI
		-- is applied on it, and then the CI and the identity column are removed.
		-- This whole shabang is done in order to make the CI creation as fast as possible.
		-- The case where the table does not have a clustered index to begin with implies
		-- bad table design, and should not be common anyhow.
		IF @myIndex_type=0 AND @myRowIsProcessed=0 AND @myIs_disabled=0
		BEGIN	--<Heap Block>

			-- Here, the table originally had an identity. We apply the CI
			-- on the identity column, and then remove it.
			IF @myTableHasIdentity=1 AND @myRowIsProcessed=0
			BEGIN
				DECLARE @myIdentColumnName NVARCHAR(128)
				SET @myIdentColumnName=NULL
				SELECT @myIdentColumnName=QUOTENAME(myHeapTableColumns.name) FROM sys.columns AS myHeapTableColumns WHERE myHeapTableColumns.[object_id]=@myObject_id AND myHeapTableColumns.is_identity=1
				
				-- If table has LOB column, system creating coresponding PF and PS for moving Regular data + LOB data via this mechanism (Partitioning)
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SET @myTempPartitionColumnName=@myIdentColumnName
					SELECT 
						@myTempPartitionColumnType=[myDataType].[name]+
							CASE 
								WHEN [myDataType].[name] IN (N'varchar', N'char', N'varbinary', N'binary', N'text')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'nvarchar', N'nchar', N'ntext')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length / 2 AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'datetime2', N'time2', N'datetimeoffset') 
									THEN N'(' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								WHEN [myDataType].[name] IN (N'decimal') 
									THEN N'(' + CAST([myColumns].[precision] AS NVARCHAR(MAX)) + N',' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								ELSE
									N''
							END 
					FROM sys.columns AS myColumns INNER JOIN sys.[types] AS myDataType ON [myColumns].[system_type_id]=[myDataType].[user_type_id] WHERE myColumns.[object_id]=@myObject_id AND QUOTENAME(myColumns.[name])=@myIdentColumnName
					SET @myTempPartitionColumnTypeConverted=REPLACE(REPLACE(REPLACE(REPLACE(@myTempPartitionColumnType,N'(',N''),N')',N''),N',',N'o'),N',',N'o')
					SET @myTempPartitionFunctionName=N'PF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameHeap=N'PSH' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameFilestream=N'PSF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					--Create Corrsponding Partition FUNCTION (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION FUNCTION \' + QUOTENAME(@myTempPartitionFunctionName) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS NVARCHAR(MAX)) + N' (' + CAST(@myTempPartitionColumnType AS NVARCHAR(MAX)) + N') AS RANGE RIGHT FOR VALUES()' AS NVARCHAR(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS NVARCHAR(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Heaps (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameHeap) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS NVARCHAR(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS NVARCHAR(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetHeapFilegroup) AS NVARCHAR(MAX)) + N')' AS NVARCHAR(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS NVARCHAR(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Filestream (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameFilestream) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS NVARCHAR(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS NVARCHAR(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS NVARCHAR(MAX)) + N')' AS NVARCHAR(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS NVARCHAR(MAX)))
					END
				END

				SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS NVARCHAR(MAX)) + N'
									ON ' + CAST(@myTableName AS nvarchar(MAX)) + N'(' + CAST(@myIdentColumnName AS nvarchar(MAX)) + N')
									WITH (' + @myWithOption + N')
									ON ' + 
											CASE
												WHEN NOT(@myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1) THEN CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
												ELSE CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX))+N'(' + CAST(@myTempPartitionColumnName AS nvarchar(MAX)) + N')' + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) ELSE N'' END
											END 
								AS NVARCHAR(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				
				-- IF Table has LOB Column we should recreating CI again without Partitioning to Resident LOB data on new Filegroup
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
										ON ' + CAST(@myTableName AS nvarchar(MAX)) + N'(' + CAST(@myIdentColumnName AS nvarchar(MAX)) + N')
										WITH (DROP_EXISTING = ON' + CASE WHEN LEN(@myWithOption)>0 THEN N',' ELSE N'' END + @myWithOption + N')
										ON ' + CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
								AS nvarchar(MAX))
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				END

				-- The table is now moved -> Remove the CI.
				SET @mySqlStr=N'DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

				-- Flag this row as processed
				SET @myRowIsProcessed=1
			END

			-- If the table has a PK, so we might as well
			-- apply the CI on the column(s) of the PK.
			-- First, get the column(s) of the PK.
			IF @myTableHasPrimaryKey=1 AND @myRowIsProcessed=0
			BEGIN
				DECLARE @myPKName NVARCHAR(128)
				DECLARE @myPK_index_id INT
				DECLARE @myPKColumnList NVARCHAR(MAX)
				SET @myPKName=NULL
				SET @myPK_index_id=NULL
				SET @myPKColumnList=NULL

				-- Extract PK name and it's related index id
				SELECT @myPKName=QUOTENAME(myPKConstraints.name),@myPK_index_id=myPKConstraints.unique_index_id FROM sys.key_constraints AS myPKConstraints WHERE myPKConstraints.[parent_object_id]=@myObject_id AND myPKConstraints.[type]='PK'
				-- Extract PK columns list and put it in @myPKColumnList
				SELECT 
					@myPKColumnList=CAST(ISNULL(@myPKColumnList,CAST(N'' AS nvarchar(MAX))) + CAST(QUOTENAME(myColumns.name) AS nvarchar(MAX)) +
									 CASE myIndexColumns.is_descending_key WHEN 1 THEN N' DESC' ELSE N' ASC' END + N',' AS nvarchar(MAX))
				FROM 
					sys.index_columns AS myIndexColumns
					INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id
				WHERE 
					myIndexColumns.[object_id]=@myObject_id AND myIndexColumns.index_id=@myPK_index_id
				ORDER BY 
					myIndexColumns.index_column_id
				-- Remove last semi column
				SET @myPKColumnList=CASE WHEN LEN(@myPKColumnList)>1 THEN LEFT(@myPKColumnList,LEN(@myPKColumnList)-1) ELSE N'' END

				-- If table has LOB column, system creating coresponding PF and PS for moving Regular data + LOB data via this mechanism (Partitioning)
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SELECT TOP 1 
						@myTempPartitionColumnName=QUOTENAME([myColumns].[name]), 
						@myTempPartitionColumnType=[myDataType].[name]+
							CASE 
								WHEN [myDataType].[name] IN (N'varchar', N'char', N'varbinary', N'binary', N'text')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'nvarchar', N'nchar', N'ntext')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length / 2 AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'datetime2', N'time2', N'datetimeoffset') 
									THEN N'(' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								WHEN [myDataType].[name] IN (N'decimal') 
									THEN N'(' + CAST([myColumns].[precision] AS NVARCHAR(MAX)) + N',' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								ELSE
									N''
								END
					FROM sys.index_columns AS myIndexColumns INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id INNER JOIN sys.[types] AS myDataType ON [myColumns].[system_type_id]=[myDataType].[user_type_id] WHERE myIndexColumns.[object_id]=@myObject_id AND myIndexColumns.index_id=@myPK_index_id ORDER BY myIndexColumns.index_column_id
					SET @myTempPartitionColumnTypeConverted=REPLACE(REPLACE(REPLACE(@myTempPartitionColumnType,N'(',N''),N')',N''),N',',N'o')
					SET @myTempPartitionFunctionName=N'PF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameHeap=N'PSH' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameFilestream=N'PSF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					--Create Corrsponding Partition FUNCTION (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION FUNCTION \' + QUOTENAME(@myTempPartitionFunctionName) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' (' + CAST(@myTempPartitionColumnType AS nvarchar(MAX)) + N') AS RANGE RIGHT FOR VALUES()' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Heaps (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameHeap) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + N')' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Filestream (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameFilestream) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) + N')' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)))
					END
				END

				-- Now, apply the CI on the primary key columns. The CI is not
				-- created as a unique CI, since if the PK was added with the NOCHECK
				-- option, there could be duplicate entries in the PK.
				SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
								 ON ' + CAST(@myTableName AS nvarchar(MAX)) + N'(' + CAST(@myPKColumnList AS nvarchar(MAX)) + N')
								 WITH (' + @myWithOption + N')
								 ON ' + 
										CASE
											WHEN NOT(@myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1) THEN CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
											ELSE CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX))+N'(' + CAST(@myTempPartitionColumnName AS nvarchar(MAX)) + N')' + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) ELSE N'' END
										END
							AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
			
				-- IF Table has LOB Column we should recreating CI again without Partitioning to Resident LOB data on new Filegroup
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
										ON ' + CAST(@myTableName AS nvarchar(MAX)) + N'(' + CAST(@myPKColumnList AS nvarchar(MAX)) + N')
										WITH (DROP_EXISTING = ON' + CASE WHEN LEN(@myWithOption)>0 THEN N',' ELSE N'' END + @myWithOption + N')
										ON ' + CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
									AS nvarchar(MAX))
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				END

				-- The last command moved the CI (and thus the table), so we
				-- can now drop the CI.
				SET @mySqlStr=CAST(N'DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

				-- Flag this row as processed
				SET @myRowIsProcessed=1
			END

			-- If the table has UQ constraints, so we might as well
			-- apply the CI on the column(s) of the UQ.
			-- First, get the column(s) of the UQ.
			IF @myTableHasUniqueCnst=1 AND @myRowIsProcessed=0
			BEGIN
				DECLARE @myUQName NVARCHAR(128)
				DECLARE @myUQ_index_id INT
				DECLARE @myUQColumnList NVARCHAR(MAX)
				SET @myUQName=NULL
				SET @myUQ_index_id=NULL
				SET @myUQColumnList=NULL

				-- Extract UQ name and it's related index id
				SELECT @myUQName=QUOTENAME(myUQConstraints.name),@myUQ_index_id=myUQConstraints.unique_index_id FROM sys.key_constraints AS myUQConstraints WHERE myUQConstraints.[parent_object_id]=@myObject_id AND myUQConstraints.[type]='UQ'
				-- Extract UQ columns list and put it in @myUQColumnList
				SELECT 
					@myUQColumnList=CAST(ISNULL(@myUQColumnList,CAST(N'' AS nvarchar(MAX))) + CAST(QUOTENAME(myColumns.name) AS nvarchar(MAX)) +
									 CASE myIndexColumns.is_descending_key WHEN 1 THEN N' DESC' ELSE N' ASC' END + N',' AS nvarchar(MAX))
				FROM 
					sys.index_columns AS myIndexColumns
					INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id
				WHERE 
					myIndexColumns.[object_id]=@myObject_id AND myIndexColumns.index_id=@myUQ_index_id
				ORDER BY 
					myIndexColumns.index_column_id
				-- Remove last semi column
				SET @myUQColumnList=CASE WHEN LEN(@myUQColumnList)>1 THEN LEFT(@myUQColumnList,LEN(@myUQColumnList)-1) ELSE N'' END

				-- If table has LOB column, system creating coresponding PF and PS for moving Regular data + LOB data via this mechanism (Partitioning)
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SELECT TOP 1 
						@myTempPartitionColumnName=QUOTENAME([myColumns].[name]), 
						@myTempPartitionColumnType=[myDataType].[name]+
							CASE 
								WHEN [myDataType].[name] IN (N'varchar', N'char', N'varbinary', N'binary', N'text')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'nvarchar', N'nchar', N'ntext')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length / 2 AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'datetime2', N'time2', N'datetimeoffset') 
									THEN N'(' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								WHEN [myDataType].[name] IN (N'decimal') 
									THEN N'(' + CAST([myColumns].[precision] AS NVARCHAR(MAX)) + N',' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								ELSE
									N''
								END
					FROM sys.index_columns AS myIndexColumns INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id INNER JOIN sys.[types] AS myDataType ON [myColumns].[system_type_id]=[myDataType].[user_type_id] WHERE myIndexColumns.[object_id]=@myObject_id AND myIndexColumns.index_id=@myUQ_index_id ORDER BY myIndexColumns.index_column_id
					SET @myTempPartitionColumnTypeConverted=REPLACE(REPLACE(REPLACE(@myTempPartitionColumnType,N'(',N''),N')',N''),N',',N'o')
					SET @myTempPartitionFunctionName=N'PF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameHeap=N'PSH' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameFilestream=N'PSF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					--Create Corrsponding Partition FUNCTION (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION FUNCTION \' + QUOTENAME(@myTempPartitionFunctionName) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' (' + CAST(@myTempPartitionColumnType AS nvarchar(MAX)) + N') AS RANGE RIGHT FOR VALUES()' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Heaps (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameHeap) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + N')' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Filestream (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameFilestream) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) + N')' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)))
					END
				END

				-- Now, apply the CI on the primary key columns. The CI is not
				-- created as a unique CI, since if the UQ was added with the NOCHECK
				-- option, there could be duplicate entries in the UQ.
				SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
								 ON ' + CAST(@myTableName AS nvarchar(MAX)) + N'(' + CAST(@myUQColumnList AS nvarchar(MAX)) + N')
								 WITH (' + @myWithOption + N')
								 ON ' + 
										CASE
											WHEN NOT(@myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1) THEN CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
											ELSE CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX))+N'(' + CAST(@myTempPartitionColumnName AS nvarchar(MAX)) + N')' + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) ELSE N'' END
										END
							AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
			
				-- IF Table has LOB Column we should recreating CI again without Partitioning to Resident LOB data on new Filegroup
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
										ON ' + CAST(@myTableName AS nvarchar(MAX)) + N'(' + CAST(@myUQColumnList AS nvarchar(MAX)) + N')
										WITH (DROP_EXISTING = ON' + CASE WHEN LEN(@myWithOption)>0 THEN N',' ELSE N'' END + @myWithOption + N')
										ON ' + CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
								AS nvarchar(MAX))
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				END

				-- The last command moved the CI (and thus the table), so we
				-- can now drop the CI.
				SET @mySqlStr=CAST(N'DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

				-- Flag this row as processed
				SET @myRowIsProcessed=1
			END

			-- If the table has UQ non-filtered index, so we might as well
			-- apply the CI on the column(s) of the UQ index.
			-- First, get the column(s) of the UQ index.
			IF @myTableHasUniqueIndex=1 AND @myHas_filter=0 AND @myRowIsProcessed=0
			BEGIN
				DECLARE @myUQIXColumnList NVARCHAR(MAX)
				SET @myUQIXColumnList=NULL

				-- Extract UQ index columns list and put it in @myUQIXColumnList
				SELECT 
					@myUQIXColumnList=CAST(ISNULL(@myUQIXColumnList,CAST(N'' AS nvarchar(MAX))) + CAST(QUOTENAME(myColumns.name) AS nvarchar(MAX)) +
									 CASE myIndexColumns.is_descending_key WHEN 1 THEN N' DESC' ELSE N' ASC' END + N',' AS nvarchar(MAX))
				FROM 
					sys.index_columns AS myIndexColumns
					INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id
				WHERE 
					myIndexColumns.[object_id]=@myObject_id AND myIndexColumns.index_id=@myIndex_id
				ORDER BY 
					myIndexColumns.index_column_id
				-- Remove last semi column
				SET @myUQIXColumnList=CASE WHEN LEN(@myUQIXColumnList)>1 THEN LEFT(@myUQIXColumnList,LEN(@myUQIXColumnList)-1) ELSE N'' END

				-- If table has LOB column, system creating coresponding PF and PS for moving Regular data + LOB data via this mechanism (Partitioning)
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SELECT TOP 1 
						@myTempPartitionColumnName=QUOTENAME([myColumns].[name]), 
						@myTempPartitionColumnType=[myDataType].[name]+
							CASE 
								WHEN [myDataType].[name] IN (N'varchar', N'char', N'varbinary', N'binary', N'text')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'nvarchar', N'nchar', N'ntext')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length / 2 AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'datetime2', N'time2', N'datetimeoffset') 
									THEN N'(' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								WHEN [myDataType].[name] IN (N'decimal') 
									THEN N'(' + CAST([myColumns].[precision] AS NVARCHAR(MAX)) + N',' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								ELSE
									N''
								END
					FROM sys.index_columns AS myIndexColumns INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id INNER JOIN sys.[types] AS myDataType ON [myColumns].[system_type_id]=[myDataType].[user_type_id] WHERE myIndexColumns.[object_id]=@myObject_id AND myIndexColumns.index_id=@myIndex_id ORDER BY myIndexColumns.index_column_id
					SET @myTempPartitionColumnTypeConverted=REPLACE(REPLACE(REPLACE(@myTempPartitionColumnType,N'(',N''),N')',N''),N',',N'o')
					SET @myTempPartitionFunctionName=N'PF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameHeap=N'PSH' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameFilestream=N'PSF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					--Create Corrsponding Partition FUNCTION (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION FUNCTION \' + QUOTENAME(@myTempPartitionFunctionName) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' (' + CAST(@myTempPartitionColumnType AS nvarchar(MAX)) + N') AS RANGE RIGHT FOR VALUES()' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Heaps (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameHeap) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + N')' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Filestream (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameFilestream) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) + N')' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)))
					END
				END

				-- Now, apply the CI on the unique index key columns. The CI is not
				-- created as a unique CI, since if the UQ index was added with the NOCHECK
				-- option, there could be duplicate entries in the UQ.
				SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
								 ON ' + CAST(@myTableName AS nvarchar(MAX)) + N'(' + CAST(@myUQIXColumnList AS nvarchar(MAX)) + N')
								 WITH (' + @myWithOption + N')
								 ON ' + 
										CASE
											WHEN NOT(@myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1) THEN CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
											ELSE CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX))+N'(' + CAST(@myTempPartitionColumnName AS nvarchar(MAX)) + N')' + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) ELSE N'' END
										END
								AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
			
				-- IF Table has LOB Column we should recreating CI again without Partitioning to Resident LOB data on new Filegroup
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
										ON ' + CAST(@myTableName AS nvarchar(MAX)) + N'(' + CAST(@myUQIXColumnList AS nvarchar(MAX)) + N')
										WITH (DROP_EXISTING = ON' + CASE WHEN LEN(@myWithOption)>0 THEN N',' ELSE N'' END + @myWithOption + N')
										ON ' + CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
								AS nvarchar(MAX))
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				END

				-- The last command moved the CI (and thus the table), so we
				-- can now drop the CI.
				SET @mySqlStr=CAST(N'DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

				-- Flag this row as processed
				SET @myRowIsProcessed=1
			END

			-- Only if the table has no PK/UQ/UQIX or Identity, then create an identity
			-- column on it. This new column will hold the CI.
			IF @myRowIsProcessed=0
			BEGIN
				--Create an identity column on heap table
				SET @mySqlStr=CAST(N' ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' ADD ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N' BIGINT IDENTITY (1, 1) ' AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				
				-- If table has LOB column, system creating coresponding PF and PS for moving Regular data + LOB data via this mechanism (Partitioning)
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SET @myTempPartitionColumnName= QUOTENAME(@myTempIndexName)
					SET @myTempPartitionColumnType=N'bigint'
					SET @myTempPartitionColumnTypeConverted=REPLACE(REPLACE(REPLACE(@myTempPartitionColumnType,N'(',N''),N')',N''),N',',N'o')
					SET @myTempPartitionFunctionName=N'PF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameHeap=N'PSH' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameFilestream=N'PSF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					--Create Corrsponding Partition FUNCTION (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION FUNCTION \' + QUOTENAME(@myTempPartitionFunctionName) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=N'CREATE PARTITION FUNCTION ' + QUOTENAME(@myTempPartitionFunctionName) + N' (' + @myTempPartitionColumnType + N') AS RANGE RIGHT FOR VALUES()'
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION FUNCTION ' + QUOTENAME(@myTempPartitionFunctionName))
					END
					--Create Corrsponding Partition SCHEME for Heaps (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameHeap) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=N'CREATE PARTITION SCHEME ' + QUOTENAME(@myTempPartitionSchemeNameHeap) + N' AS PARTITION ' + QUOTENAME(@myTempPartitionFunctionName) + N' ALL TO (' + QUOTENAME(@TargetHeapFilegroup) + N')'
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + QUOTENAME(@myTempPartitionSchemeNameHeap))
					END
					--Create Corrsponding Partition SCHEME for Filestream (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameFilestream) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=N'CREATE PARTITION SCHEME ' + QUOTENAME(@myTempPartitionSchemeNameFilestream) + N' AS PARTITION ' + QUOTENAME(@myTempPartitionFunctionName) + N' ALL TO (' + QUOTENAME(@TargetFilestreamFilegroup) + N')'
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + QUOTENAME(@myTempPartitionSchemeNameFilestream))
					END
				END

				-- Apply the CI on the identity column. We don't create the CI
				-- as unique, since the identity column may be non-unique,
				-- due to reseeding.
				SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
								 ON ' + CAST(@myTableName AS nvarchar(MAX)) + N'(' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N')
								 WITH (' + @myWithOption + N')
								 ON ' + 
										CASE
											WHEN NOT(@myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1) THEN CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
											ELSE CAST(QUOTENAME(@myTempPartitionSchemeNameHeap) AS nvarchar(MAX))+N'(' + CAST(@myTempPartitionColumnName AS nvarchar(MAX)) + N')' + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) ELSE N'' END
										END
							AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

				-- IF Table has LOB Column we should recreating CI again without Partitioning to Resident LOB data on new Filegroup
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
										ON ' + CAST(@myTableName AS nvarchar(MAX)) + N'(' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N')
										WITH (DROP_EXISTING = ON' + CASE WHEN LEN(@myWithOption)>0 THEN N',' ELSE N'' END + @myWithOption + N')
										ON ' + CAST(QUOTENAME(@TargetHeapFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
								AS nvarchar(MAX))
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				END

				-- The table is now moved -> Remove the CI.
				SET @mySqlStr=CAST(N'DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

				-- Finally, remove the added identity column
				SET @mySQLStr=CAST(N' ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' DROP COLUMN ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

				-- Flag this row as processed
				SET @myRowIsProcessed=1
			END
		END		--</Heap Block>



		--=====Clustered TABLE
		-- The table already has a clustered index. Here, we select the name of the
		-- existing clustered index, then drop it from the table, and recreate
		-- it on the other filegroup (on the same columns and order as was
		-- originally defined for the table).
		-- If the CI is also a PK/UQ/unique index, then we first check all foreign
		-- keys for the PK/UQ/UI, drop them if they exist, drop the PK/UQ/UI
		-- then recreate the PK/UQ/UI as CLUSTERED, and then reapply all the
		-- foreign keys constraints. If the CI is non-unique (thus is not
		-- associated with a PK/UQ/UI), we just drop and recreate it on the
		-- target file group.
		ELSE IF @myIndex_type=1 AND @myRowIsProcessed=0 AND @myIs_disabled=0
		BEGIN	--<Clustered Block>
			--=====<Initializing global variable> for CI procesing before doing any CI type check and descision
				DECLARE @myCIColumnList NVARCHAR(MAX)
				SET @myCIColumnList=NULL
				-- Extract CI columns list and put it in @myCIColumnList
				SELECT 
					@myCIColumnList=CAST(ISNULL(@myCIColumnList,CAST(N'' AS nvarchar(MAX))) + CAST(QUOTENAME(myColumns.name) AS nvarchar(MAX)) +
										CASE myIndexColumns.is_descending_key WHEN 1 THEN N' DESC' ELSE N' ASC' END + N','
									 AS nvarchar(MAX))
				FROM 
					sys.index_columns AS myIndexColumns
					INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id
				WHERE 
					myIndexColumns.[object_id]=@myObject_id AND myIndexColumns.index_id=@myIndex_id
				ORDER BY 
					myIndexColumns.index_column_id
				-- Remove last semi column
				SET @myCIColumnList=CASE WHEN LEN(@myCIColumnList)>1 THEN LEFT(@myCIColumnList,LEN(@myCIColumnList)-1) ELSE N'' END

			-- Here, the CI is not a PK/UQ/UQIX, so we drop the CI from
			-- the current filegroup, and recreate it on the
			-- target filegroup, as a non-unique index.
			IF @myTableHasPrimaryKey=0 AND @myTableHasUniqueCnst=0 AND @myTableHasUniqueIndex=0 AND @myRowIsProcessed=0
			BEGIN
				--1: Remove the CI.
					SET @mySqlStr=CAST(N'DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(@myIndex_name AS nvarchar(MAX)) AS nvarchar(MAX))
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

				--2: If table has LOB column, we should create coresponding PF and PS for moving Regular data + LOB data via this mechanism (Partitioning)
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SELECT TOP 1 
						@myTempPartitionColumnName=QUOTENAME([myColumns].[name]), 
						@myTempPartitionColumnType=[myDataType].[name]+
							CASE 
								WHEN [myDataType].[name] IN (N'varchar', N'char', N'varbinary', N'binary', N'text')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'nvarchar', N'nchar', N'ntext')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length / 2 AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'datetime2', N'time2', N'datetimeoffset') 
									THEN N'(' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								WHEN [myDataType].[name] IN (N'decimal') 
									THEN N'(' + CAST([myColumns].[precision] AS NVARCHAR(MAX)) + N',' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								ELSE
									N''
								END
					FROM sys.index_columns AS myIndexColumns INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id INNER JOIN sys.[types] AS myDataType ON [myColumns].[system_type_id]=[myDataType].[user_type_id] WHERE myIndexColumns.[object_id]=@myObject_id AND myIndexColumns.index_id=@myIndex_id ORDER BY myIndexColumns.index_column_id
					SET @myTempPartitionColumnTypeConverted=REPLACE(REPLACE(REPLACE(@myTempPartitionColumnType,N'(',N''),N')',N''),N',',N'o')
					SET @myTempPartitionFunctionName=N'PF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameClustered=N'PSC' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameFilestream=N'PSF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					--Create Corrsponding Partition FUNCTION (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION FUNCTION \' + QUOTENAME(@myTempPartitionFunctionName) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' (' + CAST(@myTempPartitionColumnType AS nvarchar(MAX)) + N') AS RANGE RIGHT FOR VALUES()' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Clusters (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameClustered) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameClustered) AS nvarchar(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetClusteredFilegroup) AS nvarchar(MAX)) + N')' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameClustered) AS nvarchar(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Filestream (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameFilestream) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) + N')' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' +  CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)))
					END
				END

				--3: Recreate the index on the same columns and column order, as
				-- they were defined on the original table, and in this
				-- case, the CI is not unique.
					SET @mySqlStr=CAST(N'CREATE ' + CASE @myTableHasUniqueIndex WHEN 1 THEN N'UNIQUE ' ELSE N'' END  + N'CLUSTERED INDEX ' + CAST(@myIndex_name AS nvarchar(MAX)) + N' 
									 ON '+ CAST(@myTableName AS nvarchar(MAX)) + ' (' + CAST(@myCIColumnList AS nvarchar(MAX)) + N')
									 WITH (' + @myWithOption + N')
									 ON ' + 
											CASE
												WHEN NOT(@myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1) THEN CAST(QUOTENAME(@TargetClusteredFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
												ELSE CAST(QUOTENAME(@myTempPartitionSchemeNameClustered) AS nvarchar(MAX))+N'(' + CAST(@myTempPartitionColumnName AS nvarchar(MAX)) + N')' + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) ELSE N'' END
											END
								AS nvarchar(MAX))
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

				-- 4: IF Table has LOB Column we should recreating CI again without Partitioning to Resident LOB data on new Filegroup
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SET @mySqlStr=CAST(N'CREATE ' + CASE @myTableHasUniqueIndex WHEN 1 THEN N'UNIQUE ' ELSE N'' END  + N'CLUSTERED INDEX ' + CAST(@myIndex_name AS nvarchar(MAX)) + N' 
									 ON '+ CAST(@myTableName AS nvarchar(MAX)) + ' (' + CAST(@myCIColumnList AS nvarchar(MAX)) + N')
									 WITH (DROP_EXISTING = ON' + CASE WHEN LEN(@myWithOption)>0 THEN N',' ELSE N'' END + @myWithOption + N')
									 ON ' + CAST(QUOTENAME(@TargetClusteredFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
								AS nvarchar(MAX))
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				END

				-- Flag this row as processed
				SET @myRowIsProcessed=1
			END

			-- Check whether the clustered index is also the PK, or a unique constraint (UQ),
			-- or a unique index (UI) that is neither a PK or a UQ.
			-- If the CI is either one of the above, we first check whether any foreign keys
			-- references this PK/UQ/UI. If so - we drop the FKs, then drop the PK/UQ/UI,
			-- then recreate the PK/UQ/UI on the target filegroup, and finally recreate all
			-- the foreign keys dropped earlier.
			-- If the CI is anything else (i.e., it is a non-unique clustered index)
			-- then we simply drop it and recreate it on the target filegroup.
			IF (@myTableHasPrimaryKey=1 OR @myTableHasUniqueCnst=1 OR (@myTableHasUniqueIndex=1 AND @myHas_filter=0)) AND @myRowIsProcessed=0
			BEGIN
				-- This case stands for a CI which is a PK/UQ/UQIX(non-filtered).
				-- First, we drop all foreign keys associated with the PK/UQ/UQIX.
				-- These FK constraints will be re-applied on the PK later,
				-- (i.e., after the PK/UQ/UQIX is recreated on the target filegroup).

				-- Get all the FK constraints associated with the PK/UQ/UQIX.
				-- Here, we query sysreferences so we could get our hands on all the
				-- foreign keys that reference the PK/UQ/UQIX of the table
				-- that needs to be moved.
								  
				--0:Store foreign key definitions
				CREATE TABLE #myForeignKeys_CI (Row_id BIGINT IDENTITY(1,1), ForeignTableName NVARCHAR(128), ForeignKeyName NVARCHAR(128), PKColumnList NVARCHAR(MAX), FKColumnList NVARCHAR(MAX), UpdateCascade TINYINT, DeleteCascase TINYINT,NotForReplication BIT, IsNotTrusted BIT)
				INSERT INTO #myForeignKeys_CI  (ForeignTableName ,ForeignKeyName ,PKColumnList ,FKColumnList ,UpdateCascade, DeleteCascase, NotForReplication, [IsNotTrusted])
				SELECT
					QUOTENAME(mySchema.name) + N'.' + QUOTENAME(myTables.name) AS ForeignTableName,
					QUOTENAME(myForeignKeys.name) AS ForeignKeyName,
					(SELECT
						QUOTENAME(myColumns.name) + N',' AS 'data()'
					 FROM
						sys.foreign_key_columns AS myForeignKeyCols
						INNER JOIN sys.columns AS myColumns ON myForeignKeyCols.referenced_object_id=myColumns.[object_id] AND myForeignKeyCols.referenced_column_id=myColumns.column_id
					 WHERE
						myForeignKeyCols.constraint_object_id=myForeignKeys.[object_id]
					 ORDER BY 
						myForeignKeyCols.constraint_column_id
					 FOR XML PATH('')
					) AS PKColumnList,
					(SELECT
						QUOTENAME(myColumns.name) + N',' AS 'data()'
					 FROM
						sys.foreign_key_columns AS myForeignKeyCols
						INNER JOIN sys.columns AS myColumns ON myForeignKeyCols.parent_object_id=myColumns.[object_id] AND myForeignKeyCols.parent_column_id=myColumns.column_id
					 WHERE
						myForeignKeyCols.constraint_object_id=myForeignKeys.[object_id]
					 ORDER BY 
						myForeignKeyCols.constraint_column_id
					 FOR XML PATH('')
					) AS FKColumnList,
					myForeignKeys.update_referential_action,
					myForeignKeys.delete_referential_action,
					myForeignKeys.is_not_for_replication,
					CAST(CASE WHEN [myForeignKeys].[is_disabled]=1 OR [myForeignKeys].[is_not_trusted]=1 THEN 1 ELSE 0 END AS BIT)
				FROM
					sys.foreign_keys AS myForeignKeys
					INNER JOIN sys.tables AS myTables ON myTables.[object_id] = myForeignKeys.parent_object_id
					INNER JOIN sys.schemas AS mySchema ON mySchema.[schema_id] = myTables.[schema_id]
				WHERE
					myForeignKeys.referenced_object_id=@myObject_id
					AND myForeignKeys.key_index_id=@myIndex_id

				--1:Drop the FK constraints
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand )
					SELECT 
						@myObject_id,
						@myIndex_type,
						CAST(N'ALTER TABLE ' + CAST(#myForeignKeys_CI.ForeignTableName AS nvarchar(MAX)) + N' DROP CONSTRAINT ' + CAST(#myForeignKeys_CI.ForeignKeyName AS nvarchar(MAX)) AS nvarchar(MAX))
					FROM
						#myForeignKeys_CI

				--2:Create Temporary NonClustered PK/UQ/UQIX Constraint as replacement of actual Clustered PK/UQ/UQIX, for passing Filestream requirements
					IF @myTableHasFilestream=1
					BEGIN
						IF @myTableHasPrimaryKey=1 OR @myTableHasUniqueCnst=1	-- The CREATE statement is different for PK or UQ or UQIX
						BEGIN
							--!!!Below statement was commented because we could not have more than One Primary Key constraint per Table object, 
							--!!!then it's better to create UNIQUE CONSTRAINT, instead of another PK
							--SET @mySqlStr=N'ALTER TABLE ' + @myTableName + N' 
							--				 WITH NOCHECK ADD CONSTRAINT ' + QUOTENAME(@myTempIndexName) + N'
							--				 PRIMARY KEY NONCLUSTERED (' + @myCIColumnList + N')
							--				 WITH (' + @myWithOption + N')
							--				 ON ' + QUOTENAME(@SourceFilegroup)
							SET @mySqlStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' 
											 WITH NOCHECK ADD CONSTRAINT ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
											 UNIQUE NONCLUSTERED (' + CAST(@myCIColumnList AS nvarchar(MAX)) + N')
											 WITH (' + @myConstraintWithOptions + N')
											 ON ' + CAST(QUOTENAME(@SourceFilegroup) AS nvarchar(MAX))
										AS nvarchar(MAX))
							INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						END
						ELSE IF @myTableHasUniqueIndex=1	-- The CREATE statement is different for PK or UQ or UQIX(non-filterd)
						BEGIN
							SET @mySqlStr=CAST(N'CREATE UNIQUE NONCLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N' 
											 ON '+ CAST(@myTableName AS nvarchar(MAX)) + N' (' + CAST(@myCIColumnList AS nvarchar(MAX)) + N')
											 WITH (' + @myWithOption + N')
											 ON ' + CAST(QUOTENAME(@SourceFilegroup) AS nvarchar(MAX))
										AS nvarchar(MAX))
							INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						END
					END
				--3:Drop Existed Clustered PK/UQ/UQIX Constraint
					IF @myTableHasPrimaryKey=1 OR @myTableHasUniqueCnst=1
					BEGIN
						SET @mySQLStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' DROP CONSTRAINT ' + CAST(@myIndex_name AS nvarchar(MAX)) AS nvarchar(MAX))
					END
					ELSE IF @myTableHasUniqueIndex=1
					BEGIN
						SET @mySqlStr=CAST(N'DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(@myIndex_name AS nvarchar(MAX)) AS nvarchar(MAX))
					END
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				--4: If table has LOB column, we should creating coresponding PF and PS for moving Regular data + LOB data via this mechanism (Partitioning)
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					SELECT TOP 1 
						@myTempPartitionColumnName=QUOTENAME([myColumns].[name]), 
						@myTempPartitionColumnType=[myDataType].[name]+
							CASE 
								WHEN [myDataType].[name] IN (N'varchar', N'char', N'varbinary', N'binary', N'text')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'nvarchar', N'nchar', N'ntext')
									THEN N'(' + CASE WHEN [myColumns].max_length = -1 THEN N'MAX' ELSE CAST([myColumns].max_length / 2 AS NVARCHAR(MAX)) END + N')'
								WHEN [myDataType].[name] IN (N'datetime2', N'time2', N'datetimeoffset') 
									THEN N'(' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								WHEN [myDataType].[name] IN (N'decimal') 
									THEN N'(' + CAST([myColumns].[precision] AS NVARCHAR(MAX)) + N',' + CAST([myColumns].scale AS NVARCHAR(MAX)) + N')'
								ELSE
									N''
								END
					FROM sys.index_columns AS myIndexColumns INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id INNER JOIN sys.[types] AS myDataType ON [myColumns].[system_type_id]=[myDataType].[user_type_id] WHERE myIndexColumns.[object_id]=@myObject_id AND myIndexColumns.index_id=@myIndex_id ORDER BY myIndexColumns.index_column_id
					SET @myTempPartitionColumnTypeConverted=REPLACE(REPLACE(REPLACE(@myTempPartitionColumnType,N'(',N''),N')',N''),N',',N'o')
					SET @myTempPartitionFunctionName=N'PF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameClustered=N'PSC' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					SET @myTempPartitionSchemeNameFilestream=N'PSF' + @myTempIndexName + N'_' + @myTempPartitionColumnTypeConverted
					--Create Corrsponding Partition FUNCTION (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION FUNCTION \' + QUOTENAME(@myTempPartitionFunctionName) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' (' + CAST(@myTempPartitionColumnType AS nvarchar(MAX)) + N') AS RANGE RIGHT FOR VALUES()' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION FUNCTION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Clusters (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameClustered) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameClustered) AS nvarchar(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetClusteredFilegroup) AS nvarchar(MAX)) + N')' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameClustered) AS nvarchar(MAX)))
					END
					--Create Corrsponding Partition SCHEME for Filestream (if not exists)
					IF NOT EXISTS (SELECT 1 FROM #myCommandList AS myCommandList WHERE myCommandList.[SqlCommand] LIKE N'CREATE PARTITION SCHEME \' + QUOTENAME(@myTempPartitionSchemeNameFilestream) + N'%' ESCAPE '\')
					BEGIN
						SET @mySqlStr=CAST(N'CREATE PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) + N' AS PARTITION ' + CAST(QUOTENAME(@myTempPartitionFunctionName) AS nvarchar(MAX)) + N' ALL TO (' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) + N')' AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID,TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						INSERT INTO [#myCleanupCommandList]	([ObjectID],[TableType],[SqlCommand]) VALUES (@myObject_id,@myIndex_type,N'DROP PARTITION SCHEME ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)))
					END
				END
				--5:Create New Clustered PK/UQ/UQIX*****************************************
					IF @myTableHasPrimaryKey=1	-- The CREATE statement is different for PK or UQ or UQIX
					BEGIN
						SET @mySqlStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' 
										 WITH NOCHECK ADD CONSTRAINT ' + CAST(@myIndex_name AS nvarchar(MAX)) + N'
										 PRIMARY KEY CLUSTERED (' + CAST(@myCIColumnList AS nvarchar(MAX)) + N')
										 WITH (' + @myConstraintWithOptions + N')
										 ON ' + 
												CASE
													WHEN NOT(@myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1) THEN CAST(QUOTENAME(@TargetClusteredFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
													ELSE CAST(QUOTENAME(@myTempPartitionSchemeNameClustered) AS nvarchar(MAX))+N'(' + CAST(@myTempPartitionColumnName AS nvarchar(MAX)) + N')' + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) ELSE N'' END
												END
									AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
					ELSE IF @myTableHasUniqueCnst=1	-- The CREATE statement is different for PK or UQ or UI
					BEGIN
						SET @mySqlStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' 
										 WITH NOCHECK ADD CONSTRAINT ' + CAST(@myIndex_name AS nvarchar(MAX)) + N'
										 UNIQUE CLUSTERED (' + CAST(@myCIColumnList AS nvarchar(MAX)) + N')
										 WITH (' + @myConstraintWithOptions + N')
										 ON ' + 
												CASE
													WHEN NOT(@myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1) THEN CAST(QUOTENAME(@TargetClusteredFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
													ELSE CAST(QUOTENAME(@myTempPartitionSchemeNameClustered) AS nvarchar(MAX))+N'(' + CAST(@myTempPartitionColumnName AS nvarchar(MAX)) + N')' + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) ELSE N'' END
												END
									AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
					ELSE IF @myTableHasUniqueIndex=1	-- The CREATE statement is different for PK or UQ or UQIX (non-filtered)
					BEGIN
						SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(@myIndex_name AS nvarchar(MAX)) + N' 
										 ON '+ CAST(@myTableName AS nvarchar(MAX)) + N' (' + CAST(@myCIColumnList AS nvarchar(MAX)) + N')
										 WITH (' + @myWithOption + N')
										 ON ' + 
												CASE
													WHEN NOT(@myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1) THEN CAST(QUOTENAME(@TargetClusteredFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
													ELSE CAST(QUOTENAME(@myTempPartitionSchemeNameClustered) AS nvarchar(MAX))+N'(' + CAST(@myTempPartitionColumnName AS nvarchar(MAX)) + N')' + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@myTempPartitionSchemeNameFilestream) AS nvarchar(MAX)) ELSE N'' END
												END
									AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
				-- 6: IF Table has LOB Column we should recreating CI again without Partitioning to Resident LOB data on new Filegroup
				IF @myTableHasLOB=1 AND @UsePartitioningForTextImageMovement=1
				BEGIN
					IF @myTableHasPrimaryKey=1	-- The CREATE statement is different for PK or UQ or UI
					BEGIN
						SET @mySQLStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' DROP CONSTRAINT ' + CAST(@myIndex_name AS nvarchar(MAX)) AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

						SET @mySqlStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' 
										 WITH NOCHECK ADD CONSTRAINT ' + CAST(@myIndex_name AS nvarchar(MAX)) + N'
										 PRIMARY KEY CLUSTERED (' + CAST(@myCIColumnList AS nvarchar(MAX)) + N')
										 WITH (' + @myConstraintWithOptions + N')
										 ON ' + CAST(QUOTENAME(@TargetClusteredFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
									AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
					ELSE IF @myTableHasUniqueCnst=1	-- The CREATE statement is different for PK or UQ or UI
					BEGIN
						SET @mySQLStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' DROP CONSTRAINT ' + CAST(@myIndex_name AS nvarchar(MAX)) AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

						SET @mySqlStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' 
										 WITH NOCHECK ADD CONSTRAINT ' + CAST(@myIndex_name AS nvarchar(MAX)) + N'
										 UNIQUE CLUSTERED (' + CAST(@myCIColumnList AS nvarchar(MAX)) + N')
										 WITH (' + @myConstraintWithOptions + N')
										 ON ' + CAST(QUOTENAME(@TargetClusteredFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
									AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
					ELSE IF @myTableHasUniqueIndex=1	-- The CREATE statement is different for PK or UQ or UQIX (non-filtered)
					BEGIN
						SET @mySqlStr=CAST(N'CREATE UNIQUE CLUSTERED INDEX ' + CAST(@myIndex_name AS nvarchar(MAX)) + N' 
										 ON '+ CAST(@myTableName AS nvarchar(MAX)) + N' (' + CAST(@myCIColumnList AS nvarchar(MAX)) + N')
										 WITH (DROP_EXISTING = ON' + CASE WHEN LEN(@myWithOption)>0 THEN N',' ELSE N'' END + @myWithOption + N')
										 ON ' + CAST(QUOTENAME(@TargetClusteredFilegroup) AS nvarchar(MAX)) + CASE @myTableHasFilestream WHEN 1 THEN N' FILESTREAM_ON ' + CAST(QUOTENAME(@TargetFilestreamFilegroup) AS nvarchar(MAX)) ELSE N'' END
									AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
				END
				-- 7:Drop Temporary NonClustered PK/UQ/UQIX Constraint used for Filestream purpose
					IF @myTableHasFilestream=1
					BEGIN
						IF @myTableHasPrimaryKey=1 OR @myTableHasUniqueCnst=1
						BEGIN
							SET @mySQLStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' DROP CONSTRAINT ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) AS nvarchar(MAX))
						END
						ELSE IF @myTableHasUniqueIndex=1
						BEGIN
							SET @mySqlStr=CAST(N'DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) AS nvarchar(MAX))
						END
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
				-- 8:Recreate the FK constraints
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand )
					SELECT 
						@myObject_id,
						@myIndex_type,
						  N'ALTER TABLE ' + #myForeignKeys_CI.ForeignTableName 
						+ N' WITH ' + CASE #myForeignKeys_CI.[IsNotTrusted] WHEN 1 THEN N'NOCHECK' ELSE N'CHECK' END + N' ADD CONSTRAINT ' + #myForeignKeys_CI.ForeignKeyName 
						+ N' FOREIGN KEY (' + CASE WHEN LEN(#myForeignKeys_CI.FKColumnList)>1 THEN LEFT(#myForeignKeys_CI.FKColumnList,LEN(#myForeignKeys_CI.FKColumnList)-1) ELSE N'' END + N')'
						+ N' REFERENCES ' + @myTableName + N' (' + CASE WHEN LEN(#myForeignKeys_CI.PKColumnList)>1 THEN LEFT(#myForeignKeys_CI.PKColumnList,LEN(#myForeignKeys_CI.PKColumnList)-1) ELSE N'' END + N' )'
						+ N' ON UPDATE '  + CASE #myForeignKeys_CI.UpdateCascade 
											WHEN 0 THEN N'NO ACTION '
											WHEN 1 THEN N'CASCADE '
											WHEN 2 THEN N'SET NULL '
											WHEN 3 THEN N'SET DEFAULT '
											ELSE N' '
											END
						+ N' ON DELETE '  + CASE #myForeignKeys_CI.UpdateCascade 
											WHEN 0 THEN N'NO ACTION '
											WHEN 1 THEN N'CASCADE '
											WHEN 2 THEN N'SET NULL '
											WHEN 3 THEN N'SET DEFAULT '
											ELSE N' '
											END
						+ CASE WHEN #myForeignKeys_CI.NotForReplication=1 THEN N' NOT FOR REPLICATION ' ELSE N' ' END
					FROM
						#myForeignKeys_CI
				-- 9:Destroy Temporal ForeignKeys Table
					DROP TABLE #myForeignKeys_CI

				-- Flag this row as processed
				SET @myRowIsProcessed=1
			END
		END		--</Clustered Block>



		--=====Non-Clustered Index
		-- Great. Now the table is on the new file group.
		-- Now we move the non-clustered indexes of the tables to
		-- the new file group. The structure of the code
		-- One comment: The fillfactor and padindex are not carried over,
		-- for the indexes and constraints. A good DBA would set the defaults
		-- on both filegroups the same.
		ELSE IF @myIndex_type>1 AND @myRowIsProcessed=0 AND @myIs_disabled=0
		BEGIN	--<NCI Block>
			--=====Initializing global variable for NCI procesing before doing any NCI type check and descision
			DECLARE @myNCIColumnList NVARCHAR(MAX)
			DECLARE @myNCI_IncludeColumnList NVARCHAR(MAX)

			SET @myNCIColumnList=NULL
			SET @myNCI_IncludeColumnList=NULL
			-- Extract NCI columns list and put it in @myNCIColumnList
			SELECT 
				@myNCIColumnList=CAST(ISNULL(@myNCIColumnList,CAST(N'' AS nvarchar(MAX))) + 
									CASE WHEN myIndexColumns.is_included_column=0 THEN 
										CAST(QUOTENAME(myColumns.name) AS nvarchar(MAX)) + CASE myIndexColumns.is_descending_key WHEN 1 THEN N' DESC' ELSE N' ASC' END + N','
									ELSE 
										CAST(N'' AS nvarchar(MAX))
									END AS nvarchar(MAX)),
				@myNCI_IncludeColumnList=CAST(ISNULL(@myNCI_IncludeColumnList,CAST(N'' AS nvarchar(MAX))) + 
									CASE WHEN myIndexColumns.is_included_column=1 THEN 
										CAST(QUOTENAME(myColumns.name) AS nvarchar(MAX)) /*+ CASE myIndexColumns.is_descending_key WHEN 1 THEN N' DESC' ELSE N' ASC' END*/ + N','
									ELSE
										CAST(N'' AS nvarchar(MAX))
									END AS nvarchar(MAX))
			FROM 
				sys.index_columns AS myIndexColumns 
				INNER JOIN sys.columns AS myColumns ON myColumns.[object_id] = myIndexColumns.[object_id] AND myColumns.column_id = myIndexColumns.column_id
			WHERE 
				myIndexColumns.[object_id]=@myObject_id AND myIndexColumns.index_id=@myIndex_id
			ORDER BY 
				myIndexColumns.index_column_id
			-- Remove last semi columns
			SET @myNCIColumnList=CASE WHEN LEN(@myNCIColumnList)>1 THEN LEFT(@myNCIColumnList,LEN(@myNCIColumnList)-1) ELSE N'' END
			SET @myNCI_IncludeColumnList=CASE WHEN LEN(@myNCI_IncludeColumnList)>1 THEN LEFT(@myNCI_IncludeColumnList,LEN(@myNCI_IncludeColumnList)-1) ELSE N'' END
			--====

			-- Here, the NCI is not a PK/UQ/UI, so we drop the NCI from
			-- the current filegroup, and recreate it on the
			-- target filegroup
			IF @myTableHasPrimaryKey=0 AND @myTableHasUniqueCnst=0 AND @myTableHasUniqueIndex=0 AND @myRowIsProcessed=0
			BEGIN
				-- Remove old NCI index
				SET @mySqlStr=CAST(N' DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(@myIndex_name AS nvarchar(MAX)) AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				-- Create new NCI index
				SET @mySqlStr=CAST(N'CREATE NONCLUSTERED INDEX ' + CAST(@myIndex_name AS nvarchar(MAX)) + N' 
									ON '+ CAST(@myTableName AS nvarchar(MAX)) + ' (' + CAST(@myNCIColumnList AS nvarchar(MAX)) + N')
									 ' + CASE WHEN LEN(@myNCI_IncludeColumnList)>0 THEN N'INCLUDE (' + CAST(@myNCI_IncludeColumnList AS nvarchar(MAX)) + N')' ELSE N'' END + N'
									 ' + CASE WHEN @myHas_filter=1 THEN N' WHERE ' + CAST(@myFilter_definition AS nvarchar(MAX)) ELSE N'' END + N'
									WITH (' + @myWithOption + N')
									ON ' + CAST(QUOTENAME(@TargetIndexFilegroup) AS nvarchar(MAX))
							AS nvarchar(MAX))
				INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				-- Flag this row as processed
				SET @myRowIsProcessed=1
			END

			-- Check whether the non-clustered index is also the PK, or a unique constraint (UQ),
			-- or a unique index (UI) that is neither a PK or a UQ.
			-- If the NCI is either one of the above, we first check whether any foreign keys
			-- reference this PK/UQ/UI. If so - we drop the FKs, then drop the PK/UQ/UI,
			-- then recreate the PK/UQ/UI on the target filegroup, and then recreate all
			-- the foreign keys dropped earlier.
			-- If the NCI is other than the above (i.e., it is a non-unique clustered index)
			-- then we simply drop it and recreate it on the target filegroup.
			IF (@myTableHasPrimaryKey=1 OR @myTableHasUniqueCnst=1 OR @myTableHasUniqueIndex=1) AND @myRowIsProcessed=0
			BEGIN
				-- This case stands for a NCI which is a PK/UQ/UI.
				-- First, we drop all foreign keys associated with the PK/UQ/UI.
				-- These FK constraints will be reapplied on the PK later,
				-- (i.e., after the PK/UQ/UI is recreated on the target filegroup).

				-- Get all the FK constraints associated with the PK/UQ/UI.
				-- Here, we query sysreferences so we could get our hands on all the
				-- foreign keys that reference the PK/UQ/UI of the table
				-- that needs to be moved.
							  
				-- Store foreign key definitions
				CREATE TABLE #myForeignKeys_NCI (Row_id BIGINT IDENTITY(1,1), ForeignTableName NVARCHAR(128), ForeignKeyName NVARCHAR(128), PKColumnList NVARCHAR(MAX), FKColumnList NVARCHAR(MAX), UpdateCascade TINYINT, DeleteCascase TINYINT,NotForReplication BIT, IsNotTrusted BIT)
				INSERT INTO #myForeignKeys_NCI  (ForeignTableName ,ForeignKeyName ,PKColumnList ,FKColumnList ,UpdateCascade, DeleteCascase, NotForReplication, IsNotTrusted)
				SELECT
					QUOTENAME(mySchema.name) + N'.' + QUOTENAME(myTables.name) AS ForeignTableName,
					QUOTENAME(myForeignKeys.name) AS ForeignKeyName,
					(SELECT
						QUOTENAME(myColumns.name) + N',' AS 'data()'
					 FROM
						sys.foreign_key_columns AS myForeignKeyCols
						INNER JOIN sys.columns AS myColumns ON myForeignKeyCols.referenced_object_id=myColumns.[object_id] AND myForeignKeyCols.referenced_column_id=myColumns.column_id
					 WHERE
						myForeignKeyCols.constraint_object_id=myForeignKeys.[object_id]
					 ORDER BY 
						myForeignKeyCols.constraint_column_id
					 FOR XML PATH('')
					) AS PKColumnList,
					(SELECT
						QUOTENAME(myColumns.name) + N',' AS 'data()'
					 FROM
						sys.foreign_key_columns AS myForeignKeyCols
						INNER JOIN sys.columns AS myColumns ON myForeignKeyCols.parent_object_id=myColumns.[object_id] AND myForeignKeyCols.parent_column_id=myColumns.column_id
					 WHERE
						myForeignKeyCols.constraint_object_id=myForeignKeys.[object_id]
					 ORDER BY 
						myForeignKeyCols.constraint_column_id
					 FOR XML PATH('')
					) AS FKColumnList,
					myForeignKeys.update_referential_action,
					myForeignKeys.delete_referential_action,
					myForeignKeys.is_not_for_replication,
					CAST(CASE WHEN [myForeignKeys].[is_disabled]=1 OR [myForeignKeys].[is_not_trusted]=1 THEN 1 ELSE 0 END AS BIT)
				FROM
					sys.foreign_keys AS myForeignKeys
					INNER JOIN sys.tables AS myTables ON myTables.[object_id] = myForeignKeys.parent_object_id
					INNER JOIN sys.schemas AS mySchema ON mySchema.[schema_id] = myTables.[schema_id]
				WHERE
					myForeignKeys.referenced_object_id=@myObject_id
					AND myForeignKeys.key_index_id=@myIndex_id

				--1:Drop the FK constraints
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand )
					SELECT 
						@myObject_id,
						@myIndex_type,
						CAST(N'ALTER TABLE ' + CAST(#myForeignKeys_NCI.ForeignTableName AS nvarchar(MAX)) + N' DROP CONSTRAINT ' + CAST(#myForeignKeys_NCI.ForeignKeyName AS nvarchar(MAX)) AS nvarchar(MAX))
					FROM
						#myForeignKeys_NCI
				--2:Create Temporary NonClustered PK/UQ/UQIX Constraint as replacement of actual Clustered PK/UQ/UI, for passing Filestream requirements
					IF @myTableHasFilestream=1
					BEGIN
						IF @myTableHasPrimaryKey=1 OR @myTableHasUniqueCnst=1	-- The CREATE statement is different for PK or UQ or UI
						BEGIN
							--!!!Below statement was commented because we could not have more than One Primary Key constraint per Table object, 
							--!!!then it's better to create UNIQUE CONSTRAINT, instead of another PK
							--SET @mySqlStr=N'ALTER TABLE ' + @myTableName + N' 
							--				 WITH NOCHECK ADD CONSTRAINT ' + QUOTENAME(@myTempIndexName) + N'
							--				 PRIMARY KEY NONCLUSTERED (' + @myNCIColumnList + N')
							--				 WITH (' + @myWithOption + N')
							--				 ON ' + QUOTENAME(@SourceFilegroup)
							SET @mySqlStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' 
											 WITH NOCHECK ADD CONSTRAINT ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N'
											 UNIQUE NONCLUSTERED (' + CAST(@myNCIColumnList AS nvarchar(MAX)) + N')
											 WITH (' + @myConstraintWithOptions + N')
											 ON ' + CAST(QUOTENAME(@SourceFilegroup) AS nvarchar(MAX))
										AS nvarchar(MAX))
							INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						END
						ELSE IF @myTableHasUniqueIndex=1	-- The CREATE statement is different for PK or UQ or UI
						BEGIN
							SET @mySqlStr=CAST(N'CREATE UNIQUE NONCLUSTERED INDEX ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) + N' 
											 ON '+ CAST(@myTableName AS nvarchar(MAX)) + N' (' + CAST(@myNCIColumnList AS nvarchar(MAX)) + N')
											 ' + CASE WHEN @myHas_filter=1 THEN N' WHERE ' + CAST(@myFilter_definition AS nvarchar(MAX)) ELSE N'' END + N' 
											 WITH (' + @myWithOption + N')
											 ON ' + CAST(QUOTENAME(@SourceFilegroup) AS nvarchar(MAX))
										AS nvarchar(MAX))
							INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
						END
					END
				--3:Drop Existed Non-Clustered PK/UQ/UI Constraint
					IF @myTableHasPrimaryKey=1 OR @myTableHasUniqueCnst=1
					BEGIN
						SET @mySQLStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' DROP CONSTRAINT ' + CAST(@myIndex_name AS nvarchar(MAX)) AS nvarchar(MAX))
					END
					ELSE IF @myTableHasUniqueIndex=1
					BEGIN
						SET @mySqlStr=CAST(N'DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(@myIndex_name AS nvarchar(MAX)) AS nvarchar(MAX))
					END
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
				--4:Create New Non-Clustered PK/UQ/US
					IF @myTableHasPrimaryKey=1	-- The CREATE statement is different for PK or UQ or UI
					BEGIN
						SET @mySqlStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' 
										 WITH NOCHECK ADD CONSTRAINT ' + CAST(@myIndex_name AS nvarchar(MAX)) + N'
										 PRIMARY KEY NONCLUSTERED (' + CAST(@myNCIColumnList AS nvarchar(MAX)) + N')
										 WITH (' + @myConstraintWithOptions + N')
										 ON ' + CAST(QUOTENAME(@TargetIndexFilegroup) AS nvarchar(MAX))
									AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
					ELSE IF @myTableHasUniqueCnst=1	-- The CREATE statement is different for PK or UQ or UI
					BEGIN
						SET @mySqlStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' 
										 WITH NOCHECK ADD CONSTRAINT ' + CAST(@myIndex_name AS nvarchar(MAX)) + N'
										 UNIQUE NONCLUSTERED (' + CAST(@myNCIColumnList AS nvarchar(MAX)) + N')
										 WITH (' + @myConstraintWithOptions + N')
										 ON ' + CAST(QUOTENAME(@TargetIndexFilegroup) AS nvarchar(MAX))
									AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
					ELSE IF @myTableHasUniqueIndex=1	-- The CREATE statement is different for PK or UQ or UI
					BEGIN
						SET @mySqlStr=CAST(N'CREATE UNIQUE NONCLUSTERED INDEX ' + CAST(@myIndex_name AS nvarchar(MAX)) + N' 
										 ON '+ CAST(@myTableName AS nvarchar(MAX)) + ' (' + CAST(@myNCIColumnList AS nvarchar(MAX)) + N')
										 ' + CASE WHEN LEN(@myNCI_IncludeColumnList)>0 THEN N'INCLUDE (' + CAST(@myNCI_IncludeColumnList AS nvarchar(MAX)) + N')' ELSE N'' END + N'
										 ' + CASE WHEN @myHas_filter=1 THEN N' WHERE ' + CAST(@myFilter_definition AS nvarchar(MAX)) ELSE N'' END + N' 
										 WITH (' + @myWithOption + N')
										 ON ' + CAST(QUOTENAME(@TargetIndexFilegroup) AS nvarchar(MAX))
									AS nvarchar(MAX))
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
				--5:Drop Temporary NonClustered PK/UQ/UI Constraint
					IF @myTableHasFilestream=1
					BEGIN
						IF @myTableHasPrimaryKey=1 OR @myTableHasUniqueCnst=1
						BEGIN
							SET @mySQLStr=CAST(N'ALTER TABLE ' + CAST(@myTableName AS nvarchar(MAX)) + N' DROP CONSTRAINT ' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) AS nvarchar(MAX))
						END
						ELSE IF @myTableHasUniqueIndex=1
						BEGIN
							SET @mySqlStr=CAST(N'DROP INDEX ' + CAST(@myTableName AS nvarchar(MAX)) + N'.' + CAST(QUOTENAME(@myTempIndexName) AS nvarchar(MAX)) AS nvarchar(MAX))
						END
						INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)
					END
				--6:Recreate the FK constraints
					INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand )
					SELECT 
						@myObject_id,
						@myIndex_type,
						  N'ALTER TABLE ' + #myForeignKeys_NCI.ForeignTableName 
						+ N' WITH ' + CASE #myForeignKeys_NCI.[IsNotTrusted] WHEN 1 THEN N'NOCHECK' ELSE N'CHECK' END + N' ADD CONSTRAINT ' + #myForeignKeys_NCI.ForeignKeyName 
						+ N' FOREIGN KEY (' + CASE WHEN LEN(#myForeignKeys_NCI.FKColumnList)>1 THEN LEFT(#myForeignKeys_NCI.FKColumnList,LEN(#myForeignKeys_NCI.FKColumnList)-1) ELSE N'' END + N')'
						+ N' REFERENCES ' + @myTableName + N' (' + CASE WHEN LEN(#myForeignKeys_NCI.PKColumnList)>1 THEN LEFT(#myForeignKeys_NCI.PKColumnList,LEN(#myForeignKeys_NCI.PKColumnList)-1) ELSE N'' END + N' )'
						+ N' ON UPDATE '  + CASE #myForeignKeys_NCI.UpdateCascade 
											WHEN 0 THEN N'NO ACTION '
											WHEN 1 THEN N'CASCADE '
											WHEN 2 THEN N'SET NULL '
											WHEN 3 THEN N'SET DEFAULT '
											ELSE N' '
											END
						+ N' ON DELETE '  + CASE #myForeignKeys_NCI.UpdateCascade 
											WHEN 0 THEN N'NO ACTION '
											WHEN 1 THEN N'CASCADE '
											WHEN 2 THEN N'SET NULL '
											WHEN 3 THEN N'SET DEFAULT '
											ELSE N' '
											END
						+ CASE WHEN #myForeignKeys_NCI.NotForReplication=1 THEN N' NOT FOR REPLICATION ' ELSE N' ' END
					FROM
						#myForeignKeys_NCI
				--5:Destroy Temporal ForeignKeys Table
					DROP TABLE #myForeignKeys_NCI

				-- Flag this row as processed
				SET @myRowIsProcessed=1
			END
		END		--</NCI Block>
	

		--=====Others (Disabled Indexes)
		-- This Section will set Disabled indexes to Disable state after moving all enabled indexes (in some cases disabled indexes coming enable after 
		-- altering Constraints and we should re disable them)
		ELSE IF @myRowIsProcessed=0 AND @myIs_disabled=1
		BEGIN	--<Disabled IDX Block>
		
			-- Redisable, originally disabled indexes
			SET @mySqlStr=CAST(N'ALTER INDEX ' + CAST(@myIndex_name AS nvarchar(MAX)) + N' ON ' + CAST(@myTableName AS nvarchar(MAX)) + N' DISABLE' AS nvarchar(MAX))
			INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand ) VALUES (@myObject_id,@myIndex_type,@mySqlStr)

			-- Flag this row as processed
			SET @myRowIsProcessed=1
		END		--</Disabled IDX Block>

		FETCH NEXT FROM @myCursor INTO @myRow_id ,@myObject_id ,@myTableName ,@myIndex_id ,@myIndex_name ,@myIndex_type ,@myIs_disabled ,@myHas_filter ,@myFilter_definition ,@myTableHasPrimaryKey ,@myTableHasUniqueCnst ,@myTableHasUniqueIndex ,@myTableHasIdentity ,@myTableHasRowGuidCol ,@myTableHasSpareColumn ,@myGeneratedIndexWithOptions, @myGeneratedConstraintWithOptions ,@myTableHasFilestream, @myFilestreamFilegroupName, @myTableHasLOB
	END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;

	--Remove Temporary Generated Partitions
	INSERT INTO #myCommandList (ObjectID, TableType, SqlCommand )
	SELECT ObjectID, TableType, SqlCommand FROM [#myCleanupCommandList] ORDER BY [Row_id] DESC

	--Put Semicolon at the end of lines
	UPDATE #myCommandList SET [SqlCommand]=CAST([SqlCommand] AS NVARCHAR(MAX))+N';'

	SELECT * FROM #myTablesList
	SELECT 
		#myCommandList.Row_id,
		#myCommandList.ObjectID,
		#myCommandList.TableType,
		N'Print N''Row_id: ' + CAST(#myCommandList.Row_id as nvarchar(255)) + N''';' + #myCommandList.SqlCommand as SqlCommand
	FROM #myCommandList ORDER BY Row_id

	DROP TABLE #myTablesList
	DROP TABLE #myCommandList
	DROP TABLE #mySpecialTableList
	DROP TABLE [#myCleanupCommandList]

	--=======Control Unmoved Objects
	--SELECT 
	--	QUOTENAME(mySchema.name) + N'.' + QUOTENAME(myObjects.name) AS ObjectName,
	--	myObjects.type_desc AS ObjectType,
	--	myIndex.*
	--FROM 
	--	sys.indexes AS myIndex WITH (READPAST)
	--	INNER JOIN sys.all_objects AS myObjects WITH (READPAST) ON myObjects.[object_id] = myIndex.[object_id]
	--	INNER JOIN sys.schemas AS mySchema WITH (READPAST) ON mySchema.[schema_id] = myObjects.[schema_id]
	--	INNER JOIN sys.data_spaces AS myDataSpace WITH (READPAST) ON myDataSpace.data_space_id = myIndex.data_space_id 
	--WHERE 
	--	myDataSpace.name=@SourceFilegroup	--myDataSpace.data_space_id=1
	--	AND is_ms_shipped=0
	--	AND [myObjects].[type]='U'
	--ORDER BY
	--	myIndex.[object_id],
	--	myIndex.is_disabled,
	--	myIndex.index_id
	
	----=====Equality Test on FK's of New DB and Previous DB
	--SELECT
	--	QUOTENAME(mySchema.name)+N'.'+QUOTENAME(myObject.name)+N'.'+QUOTENAME(ISNULL(myFK.name,N'NULL')) as FullName,
	--	myFK.[type],
	--	QUOTENAME(myParentSchema.name)+N'.'+QUOTENAME(myParentObject.name) as ParentFullName,
	--	QUOTENAME(myRefSchema.name)+N'.'+QUOTENAME(myRefObject.name) as RefFullName,
	--	(SELECT
	--		QUOTENAME(myColumns.name) + N',' AS 'data()'
	--	 FROM
	--		framework941224.sys.foreign_key_columns AS myForeignKeyCols WITH (NOLOCK)
	--		INNER JOIN framework941224.sys.columns AS myColumns WITH (NOLOCK) ON myForeignKeyCols.referenced_object_id=myColumns.[object_id] AND myForeignKeyCols.referenced_column_id=myColumns.column_id
	--	 WHERE
	--		myForeignKeyCols.constraint_object_id=myFK.[object_id]
	--	 ORDER BY 
	--		myForeignKeyCols.constraint_column_id
	--	 FOR XML PATH('')
	--	) AS PKColumnList,
	--	(SELECT
	--		QUOTENAME(myColumns.name) + N',' AS 'data()'
	--	 FROM
	--		framework941224.sys.foreign_key_columns AS myForeignKeyCols WITH (NOLOCK)
	--		INNER JOIN framework941224.sys.columns AS myColumns WITH (NOLOCK) ON myForeignKeyCols.parent_object_id=myColumns.[object_id] AND myForeignKeyCols.parent_column_id=myColumns.column_id
	--	 WHERE
	--		myForeignKeyCols.constraint_object_id=myFK.[object_id]
	--	 ORDER BY 
	--		myForeignKeyCols.constraint_column_id
	--	 FOR XML PATH('')
	--	) AS FKColumnList
	--FROM
	--	framework941224.sys.foreign_keys as myFK
	--	INNER JOIN framework941224.sys.objects as myObject on myFK.[object_id]=myObject.[object_id]
	--	INNER JOIN framework941224.sys.schemas as mySchema on myObject.[schema_id]=mySchema.[schema_id]
	--	INNER JOIN framework941224.sys.objects as myParentObject on myFK.[parent_object_id]=myParentObject.[object_id]
	--	INNER JOIN framework941224.sys.schemas as myParentSchema on myParentObject.[schema_id]=myParentSchema.[schema_id]
	--	INNER JOIN framework941224.sys.objects as myRefObject on myFK.[referenced_object_id]=myRefObject.[object_id]
	--	INNER JOIN framework941224.sys.schemas as myRefSchema on myRefObject.[schema_id]=myRefSchema.[schema_id]
	--WHERE
	--	myObject.is_ms_shipped=0
	--EXCEPT
	--SELECT
	--	QUOTENAME(mySchema.name)+N'.'+QUOTENAME(myObject.name)+N'.'+QUOTENAME(ISNULL(myFK.name,N'NULL')) as FullName,
	--	myFK.[type],
	--	QUOTENAME(myParentSchema.name)+N'.'+QUOTENAME(myParentObject.name) as ParentFullName,
	--	QUOTENAME(myRefSchema.name)+N'.'+QUOTENAME(myRefObject.name) as RefFullName,
	--	(SELECT
	--		QUOTENAME(myColumns.name) + N',' AS 'data()'
	--	 FROM
	--		KasraSplit.sys.foreign_key_columns AS myForeignKeyCols WITH (NOLOCK)
	--		INNER JOIN KasraSplit.sys.columns AS myColumns WITH (NOLOCK) ON myForeignKeyCols.referenced_object_id=myColumns.[object_id] AND myForeignKeyCols.referenced_column_id=myColumns.column_id
	--	 WHERE
	--		myForeignKeyCols.constraint_object_id=myFK.[object_id]
	--	 ORDER BY 
	--		myForeignKeyCols.constraint_column_id
	--	 FOR XML PATH('')
	--	) AS PKColumnList,
	--	(SELECT
	--		QUOTENAME(myColumns.name) + N',' AS 'data()'
	--	 FROM
	--		KasraSplit.sys.foreign_key_columns AS myForeignKeyCols WITH (NOLOCK)
	--		INNER JOIN KasraSplit.sys.columns AS myColumns WITH (NOLOCK) ON myForeignKeyCols.parent_object_id=myColumns.[object_id] AND myForeignKeyCols.parent_column_id=myColumns.column_id
	--	 WHERE
	--		myForeignKeyCols.constraint_object_id=myFK.[object_id]
	--	 ORDER BY 
	--		myForeignKeyCols.constraint_column_id
	--	 FOR XML PATH('')
	--	) AS FKColumnList
	--FROM
	--	KasraSplit.sys.foreign_keys as myFK
	--	INNER JOIN KasraSplit.sys.objects as myObject on myFK.[object_id]=myObject.[object_id]
	--	INNER JOIN KasraSplit.sys.schemas as mySchema on myObject.[schema_id]=mySchema.[schema_id]
	--	INNER JOIN KasraSplit.sys.objects as myParentObject on myFK.[parent_object_id]=myParentObject.[object_id]
	--	INNER JOIN KasraSplit.sys.schemas as myParentSchema on myParentObject.[schema_id]=myParentSchema.[schema_id]
	--	INNER JOIN KasraSplit.sys.objects as myRefObject on myFK.[referenced_object_id]=myRefObject.[object_id]
	--	INNER JOIN KasraSplit.sys.schemas as myRefSchema on myRefObject.[schema_id]=myRefSchema.[schema_id]
	--WHERE
	--	myObject.is_ms_shipped=0

	----=====Equality Test on Indexes of New DB and Previous DB
	--SELECT
	--	QUOTENAME(mySchema.name)+N'.'+QUOTENAME(myObject.name)+N'.'+QUOTENAME(ISNULL(myIndex.name,N'NULL')) as FullName,
	--	myIndex.[type]
	--FROM
	--	framework941224.sys.indexes as myIndex
	--	INNER JOIN framework941224.sys.objects as myObject on myIndex.[object_id]=myObject.[object_id]
	--	INNER JOIN framework941224.sys.schemas as mySchema on myObject.[schema_id]=mySchema.[schema_id]
	--WHERE
	--	myObject.is_ms_shipped=0
	--EXCEPT
	--SELECT
	--	QUOTENAME(mySchema.name)+N'.'+QUOTENAME(myObject.name)+N'.'+QUOTENAME(ISNULL(myIndex.name,N'NULL')) as FullName,
	--	myIndex.[type]
	--FROM
	--	KasraSplit.sys.indexes as myIndex
	--	INNER JOIN KasraSplit.sys.objects as myObject on myIndex.[object_id]=myObject.[object_id]
	--	INNER JOIN KasraSplit.sys.schemas as mySchema on myObject.[schema_id]=mySchema.[schema_id]
	--WHERE
	--	myObject.is_ms_shipped=0
END
GO
