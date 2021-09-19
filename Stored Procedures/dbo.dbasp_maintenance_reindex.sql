SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian,Saffarpour>
-- Create date: <4/2/2016>
-- Version:		<3.0.0.4>
-- Description:	<Refresh all enabled unheaped database indexes>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@FillFactor:	'Auto' or 'DISABLE' or '0' to '100'	//use 'Auto' to decision between Reorganzie or Rebuild action automatically based on Low/Mid/HighFragmentation_Boundries)
--	@ForceTo:		'Auto' or 'REBUILD' or 'REORGANIZE'	//--Force to REBUILD or REORGANIZE all indexes also you can use AUTO to decide automatically
--	@IndexesUsedInLastXdays:	0 or any above values //Reindex only index objects that are used in last X days,0 means ignoring this filter option
--	@HugeUntidyDetection: 0 or 1 //Detecting huge tables(MB & Rows) with low fragmentation but high untidy MB/records/pages and reorganizing them, be careful this option can make huge log records in logfile!!!
--	@MinimumRowCountToProcess:	Null or any positive value	//Indicate minimum row count for candidate tables of reindexing process, use Null or zero for ignore this parameter
--	@MaximumRowCountToProcess:	Null or any positive value	//Indicate maximum row count for candidate tables of reindexing process, use Null for ignore this parameter
--	@PrintOnly:		0 or 1
-- =============================================

CREATE PROCEDURE [dbo].[dbasp_maintenance_reindex]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@FillFactor NVARCHAR(10)=N'Auto',
	@ForceTo NVARCHAR(10)=N'Auto',
	@IndexesUsedInLastXdays INT=15,
	@HugeUntidyDetection BIT=0,
	@MinimumRowCountToProcess BIGINT=NULL,
	@MaximumRowCountToProcess BIGINT=NULL,
	@PrintOnly BIT=1
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @Database_ID INT;
	DECLARE @Database_IsReadOnly bit;
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);
	DECLARE @LowFragmentation_Boundry int;
	DECLARE @MedFragmentation_Boundry int;
	DECLARE @HighFragmentation_Boundry int;
	DECLARE @HugeTablesMinSizeMB int
	DECLARE @HugeTablesReorganizeMinSizeMB int
	DECLARE @HugeTablesReorganizeMinRows int
	DECLARE @myMinimumPagesToConsider int
	
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @LowFragmentation_Boundry=5
	SET @MedFragmentation_Boundry=30
	SET @HighFragmentation_Boundry=50
	SET @HugeTablesMinSizeMB=400				--390 MB ~= 50,000 Pages *8KB / 1024KB
	SET @HugeTablesReorganizeMinSizeMB=80		--78 MB ~= 10,000 Pages *8KB / 1024KB
	SET @HugeTablesReorganizeMinRows=500000		--500.000 Records
	SET @myMinimumPagesToConsider=8+1			--Tables/Indexes with size more than 8 pages (Not mixed extents) will be reindex
	
	SET @FillFactor = CASE 
						WHEN ISNUMERIC(LTRIM(RTRIM(@FillFactor)))=1 AND (CAST(LTRIM(RTRIM(@FillFactor)) as int) BETWEEN 0 AND 100) THEN LTRIM(RTRIM(@FillFactor))
						WHEN UPPER(LTRIM(RTRIM(@FillFactor)))=N'DISBALE' THEN N'DISBALE'
						WHEN UPPER(LTRIM(RTRIM(@FillFactor)))=N'AUTO' THEN N'AUTO'
						ELSE N'AUTO'
					   END
	SET @ForceTo = CASE 
						WHEN UPPER(LTRIM(RTRIM(@ForceTo)))=N'REORGANIZE' THEN N'REORGANIZE'
						WHEN UPPER(LTRIM(RTRIM(@ForceTo)))=N'REBUILD' THEN N'REBUILD'
						ELSE N'AUTO'
					   END
					   
    SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
		
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
	WHILE @@Fetch_Status=0
	BEGIN
		SELECT @Database_ID=database_id,@Database_IsReadOnly=CAST(is_read_only as bit) from sys.databases where name=@Database_Name
		SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
			@myNewLine+ N'DECLARE @myIndexesUsedInLastXdays INT;'+
			@myNewLine+ N'DECLARE @myMinimumLastUsedDate Datetime;'+
			@myNewLine+ N'DECLARE @myLowerRowCount BIGINT;'+
			@myNewLine+ N'DECLARE @myUpperRowCount BIGINT;'+
			@myNewLine+ N'SET @myLowerRowCount=' + CAST(ISNULL(@MinimumRowCountToProcess,-1) AS NVARCHAR(MAX)) + N';'+
			@myNewLine+ N'SET @myUpperRowCount=' + CAST(ISNULL(@MaximumRowCountToProcess,-1) AS NVARCHAR(MAX)) + N';'+
			@myNewLine+ N'SET @myIndexesUsedInLastXdays=' + CAST(ABS(ISNULL(@IndexesUsedInLastXdays,0)) AS NVARCHAR(MAX)) + N';'+
			@myNewLine+ N'SET @myMinimumLastUsedDate=DATEADD(Day,(-1 * @myIndexesUsedInLastXdays),GETDATE());'+
			@myNewLine+ N''+
			@myNewLine+	N'CREATE TABLE #PhysicalStat(partition_number INT,avg_fragmentation_in_percent float,alloc_unit_type_desc NVARCHAR(60),page_count BIGINT,object_id INT,index_id INT);'+
			@myNewLine+	N'INSERT INTO #PhysicalStat'+
			@myNewLine+	N'SELECT DISTINCT '+
			@myNewLine+	N'	myStats.partition_number,'+
			@myNewLine+	N'	myStats.avg_fragmentation_in_percent,'+
			@myNewLine+	N'	myStats.alloc_unit_type_desc,'+
			@myNewLine+	N'	myStats.page_count,'+
			@myNewLine+	N'	myStats.[object_id],'+
			@myNewLine+	N'	myStats.index_id'+
			@myNewLine+	N'FROM '+
			@myNewLine+	N'	sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL,''LIMITED'') AS myStats'+
			@myNewLine+	N'	INNER JOIN'+
			@myNewLine+	N'	('+
			@myNewLine+	N'		SELECT '+
			@myNewLine+	N'			ROW_NUMBER() OVER(ORDER BY myPartitionStat.row_count DESC) AS RowNumber,'+
			@myNewLine+	N'			myPartitionStat.OBJECT_ID,'+
			@myNewLine+	N'			myPartitionStat.index_id ,'+
			@myNewLine+	N'			myPartitionStat.row_count'+
			@myNewLine+	N'		FROM '+
			@myNewLine+	N'			sys.dm_db_partition_stats AS myPartitionStat'+
			@myNewLine+	N'			INNER JOIN sys.objects AS myObject ON myObject.object_id = myPartitionStat.OBJECT_ID'+
			@myNewLine+	N'		WHERE'+
			@myNewLine+	N'			myObject.is_ms_shipped = 0'+
			@myNewLine+	N'			AND myPartitionStat.index_id > 0'+
			@myNewLine+	N'			AND CASE WHEN @myLowerRowCount = -1 THEN 1 ELSE myPartitionStat.row_count END >= CASE WHEN @myLowerRowCount = -1 THEN 1 ELSE @myLowerRowCount END'+
			@myNewLine+	N'			AND CASE WHEN @myUpperRowCount = -1 THEN 1 ELSE myPartitionStat.row_count END <= CASE WHEN @myUpperRowCount = -1 THEN 1 ELSE @myUpperRowCount END'+
			@myNewLine+	N'	) AS myPartition ON myPartition.OBJECT_ID = myStats.OBJECT_ID AND myPartition.index_id = myStats.index_id '+
			@myNewLine+	N'	WHERE'+
			@myNewLine+	N'		myStats.page_count >= ' + CAST(ISNULL(@myMinimumPagesToConsider,0) AS NVARCHAR(MAX))+
			@myNewLine+	N''+
			@myNewLine+	N'CREATE TABLE #IndexCommands (ID int IDENTITY, SQLStatement nvarchar(max),CommandsType nvarchar(50),Fragmentation float,IndexTotalSizeMB INT);'+
			@myNewLine+	N'INSERT INTO #IndexCommands (SQLStatement, CommandsType, Fragmentation,IndexTotalSizeMB)'+
			@myNewLine+	N'	SELECT'+
			@myNewLine+	N'		myCore3.CommandStr + CASE '+
			@myNewLine+	N'				WHEN myCore3.CommandsType = N''REORGANIZE'' AND LEN(myCore3.WithStrReorganize)>0 THEN N'' WITH ('' + RIGHT(myCore3.WithStrReorganize,LEN(myCore3.WithStrReorganize)-1)+'')'' '+
			@myNewLine+	N'				WHEN myCore3.CommandsType = N''REBUILD'' AND LEN(myCore3.WithStrRebuild)>0 THEN N'' WITH ('' + RIGHT(myCore3.WithStrRebuild,LEN(myCore3.WithStrRebuild)-1)+'')'' '+
			@myNewLine+	N'				ELSE '''' '+
			@myNewLine+	N'			END + '';'' As SQLStatement, '+
			@myNewLine+	N'		myCore3.CommandsType,'+
			@myNewLine+	N'		myCore3.Fragmentation,'+
			@myNewLine+	N'		myCore3.IndexTotalSizeMB'+
			@myNewLine+	N'	FROM'+
			@myNewLine+	N'		('+
			@myNewLine+	N'		SELECT'+
			@myNewLine+	N'			myCore2.CommandStr,'+
			@myNewLine+	N'			myCore2.WithCompressRowGroups AS WithStrReorganize,'+
			@myNewLine+	N'			myCore2.WithDataCompression + myCore2.WithFillFactor + myCore2.WithOnline + myCore2.WithPadIndex + myCore2.WithSortInTempdb + myCore2.WithStatisticsNoRecompute as WithStrRebuild,'+
			@myNewLine+	N'			CommandsType=CASE '+
			@myNewLine+	N'							WHEN ISNULL(PATINDEX(''ALTER INDEX%ON%REORGANIZE%'',myCore2.CommandStr),0)>0 THEN N''REORGANIZE'''+
			@myNewLine+	N'							WHEN ISNULL(PATINDEX(''ALTER INDEX%ON%REBUILD%'',myCore2.CommandStr),0)>0 THEN N''REBUILD'''+
			@myNewLine+	N'							WHEN ISNULL(PATINDEX(''PRINT %ATTENTION%'',myCore2.CommandStr),0)>0 THEN N''ATTENTION'''+
			@myNewLine+	N'							ELSE N''PRINT'''+
			@myNewLine+	N'						END,'+
			@myNewLine+	N'			myCore2.[object_id],'+
			@myNewLine+	N'			myCore2.index_id,'+
			@myNewLine+	N'			myCore2.Fragmentation,'+
			@myNewLine+	N'			myCore2.IndexTotalSizeMB'+
			@myNewLine+	N'		FROM'+
			@myNewLine+	N'			('+
			@myNewLine+	N'			SELECT'+
			@myNewLine+	N'				CommandStr='+
			@myNewLine+	N'					CASE'+
			@myNewLine+	N'						WHEN (''' + @ForceTo + N''' = ''AUTO'' and myCore1.Fragmentation between ' + CAST(@LowFragmentation_Boundry AS NVARCHAR(MAX)) + N' and ' + CAST(@MedFragmentation_Boundry AS NVARCHAR(MAX)) + N')  or (''' + @ForceTo + N''' = ''AUTO'' and ' + CAST(@HugeUntidyDetection AS NVARCHAR(MAX)) + N' = 1 and myCore1.IsHugeUntidy=1) or (''' + @ForceTo + N'''=''REORGANIZE'') then'+
			@myNewLine+	N'							CASE WHEN myCore1.AllowPageLocks=1 then '+
			@myNewLine+	N'								''ALTER INDEX '' + myCore1.FullIndexName + '' ON '' + myCore1.FullTableName + '' REORGANIZE'' + CASE WHEN myCore1.IsPartitioned=1 THEN '' PARTITION = '' +  CAST(myCore1.PartitionNo as nvarchar(10)) ELSE '''' END'+
			@myNewLine+	N'							WHEN myCore1.AllowPageLocks=0 AND myCore1.IndexType = 5 then	 --Is Clustered Columnstore Index'+
			@myNewLine+	N'								''ALTER INDEX '' + myCore1.FullIndexName + '' ON '' + myCore1.FullTableName + '' REORGANIZE'''+
			@myNewLine+	N'							ELSE '+
			@myNewLine+	N'								''PRINT ''''ATTENTION (You should set allow_page_locks to true)!!! Can not REORGANIZING INDEX ''+ myCore1.FullIndexName +'' ON TABLE ''+ myCore1.FullTableName + CASE WHEN myCore1.IsPartitioned=1 THEN '' of Partition '' + CAST(myCore1.PartitionNo as nvarchar(10)) ELSE '''' END + '' Fragmentation is: '' + CAST(myCore1.Fragmentation as nvarchar(50))+''% - Starting at '' + CAST(Getdate() as nvarchar(50)) + '''''''''+
			@myNewLine+	N'							END '+
			@myNewLine+	N'						WHEN (''' + @ForceTo + N''' = ''AUTO'' and myCore1.Fragmentation > ' + CAST(@MedFragmentation_Boundry AS NVARCHAR(MAX)) + N') or (''' + @ForceTo + N'''=''REBUILD'') then '+
			@myNewLine+	N'							CASE WHEN myCore1.IndexType != 5 then	--Is not Clustered Columnstore Index'+
			@myNewLine+	N'								''ALTER INDEX '' + myCore1.FullIndexName + '' ON '' + myCore1.FullTableName + '' REBUILD '' + CASE WHEN myCore1.IsPartitioned=1 THEN ''PARTITION = '' + CAST(myCore1.PartitionNo as nvarchar(10)) ELSE '''' END'+
			@myNewLine+	N'							ELSE									--Is Clustered Columnstore Index'+
			@myNewLine+	N'								''ALTER INDEX '' + myCore1.FullIndexName + '' ON '' + myCore1.FullTableName + '' REORGANIZE'''+
			@myNewLine+	N'							END '+
			@myNewLine+	N'						ELSE'+
			@myNewLine+	N'							''PRINT ''''INDEX ''+ myCore1.FullIndexName +'' ON TABLE ''+ myCore1.FullTableName + CASE WHEN myCore1.IsPartitioned=1 THEN '' of Partition ''+ CAST(myCore1.PartitionNo as nvarchar(10)) ELSE '''' END + '' Fragmentation is: '' + CAST(myCore1.Fragmentation as nvarchar(50))+''%'''''''+
			@myNewLine+	N'					END,'+
			@myNewLine+	N'				WithFillFactor='+
			@myNewLine+	N'					CASE WHEN myCore1.IsPartitionLimited=0 AND myCore1.IndexType NOT IN (5,6,7) THEN '',FILLFACTOR = '' + CAST(myCore1.TargetFillFactor AS nvarchar(3)) ELSE '''' END,'+
			@myNewLine+	N'				WithPadIndex='+
			@myNewLine+	N'					CASE WHEN myCore1.IsPartitionLimited=0 AND myCore1.IndexType NOT IN (5,6,7) THEN '',PAD_INDEX = ON'' ELSE '''' END,'+
			@myNewLine+	N'				WithStatisticsNoRecompute='+
			@myNewLine+	N'					CASE WHEN myCore1.IsPartitionLimited=0 AND myCore1.IndexType NOT IN (5,6,7) THEN '',STATISTICS_NORECOMPUTE = OFF'' ELSE '''' END,'+
			@myNewLine+	N'				WithOnline='+
			@myNewLine+	N'					CASE WHEN myCore1.IsPartitionLimited=0 AND myCore1.IndexType NOT IN (5,6,7) THEN '',ONLINE=OFF'' ELSE '''' END,'+
			@myNewLine+	N'				WithSortInTempdb='+
			@myNewLine+	N'					CASE WHEN myCore1.IndexType NOT IN (5,6,7) THEN '',SORT_IN_TEMPDB = ON'' ELSE '''' END,'+
			@myNewLine+	N'				WithDataCompression='',DATA_COMPRESSION = '' + CASE myCore1.CompressionType WHEN 0 THEN ''NONE'' WHEN 1 THEN ''ROW'' WHEN 2 THEN ''PAGE'' WHEN 3 THEN ''COLUMNSTORE'' ELSE ''NONE'' END,'+
			@myNewLine+	N'				WithCompressRowGroups=CASE WHEN myCore1.IndexType IN (5,6,7) THEN '',COMPRESS_ALL_ROW_GROUPS = ON'' ELSE '''' END,'+
			@myNewLine+	N'				myCore1.[object_id],'+
			@myNewLine+	N'				myCore1.index_id,'+
			@myNewLine+	N'				myCore1.Fragmentation,'+
			@myNewLine+	N'				myCore1.IndexTotalSizeMB'+
			@myNewLine+	N'			FROM'+
			@myNewLine+	N'				('+
			@myNewLine+	N'				SELECT'+
			@myNewLine+	N'					myCore0.*,'+
			@myNewLine+	N'					QUOTENAME(myCore0.IndexName) as FullIndexName,'+
			@myNewLine+	N'					QUOTENAME(myCore0.SchemaName) + ''.'' + QUOTENAME(myCore0.TableName) as FullTableName,'+
			@myNewLine+	N'					IsPartitioned=CASE WHEN myCore0.PartitionsCount>=1 THEN CAST(1 as bit) ELSE CAST(0 as BIT) END,'+
			@myNewLine+	N'					IsPartitionLimited=CASE WHEN myCore0.PartitionType=''PS'' AND myCore0.PartitionsCount>1 THEN CAST(1 as bit) ELSE CAST(0 as bit) END,'+
			@myNewLine+	N'					IsHugeUntidy=CASE WHEN myCore0.StoredDataType!=''LOB_DATA'' AND myCore0.IndexTotalSizeMB>' + CAST(@HugeTablesMinSizeMB AS NVARCHAR(MAX)) + N' AND myCore0.IndexTotalSizeMB*myCore0.Fragmentation>' + CAST(@HugeTablesReorganizeMinSizeMB AS NVARCHAR(MAX)) + N'  AND myCore0.IndexTotalRowCount*myCore0.Fragmentation>' + CAST(@HugeTablesReorganizeMinRows AS NVARCHAR(MAX)) + N' THEN CAST(1 as bit) ELSE CAST(0 as bit) END'+
			@myNewLine+	N'				FROM'+
			@myNewLine+	N'					('+
			@myNewLine+	N'					SELECT'+
			@myNewLine+	N'						myIndexes.[object_id],'+
			@myNewLine+	N'						myIndexes.index_id,'+
			@myNewLine+	N'						myIndexes.type as IndexType,'+
			@myNewLine+	N'						mySchemas.name as SchemaName,'+
			@myNewLine+	N'						myTables.name as TableName,'+
			@myNewLine+	N'						myIndexes.name as IndexName,'+
			@myNewLine+	N'						mySpace.type as PartitionType,						--FG=Filegroup,PS=PartitionScheme'+
			@myNewLine+	N'						myStats.partition_number as PartitionNo,'+
			@myNewLine+	N'						ISNULL(myPartitionFunction.fanout,0) as PartitionsCount,'+
			@myNewLine+	N'						myStats.avg_fragmentation_in_percent as Fragmentation,'+
			@myNewLine+	N'						myStats.alloc_unit_type_desc as StoredDataType,'+
			@myNewLine+	N'						CASE WHEN ISNULL(myPartitionFunction.fanout,0)>=1 THEN [myPartitionedFileGroups].[is_read_only] ELSE myFileGroups.is_read_only END as IsReadonly,'+
			@myNewLine+	N'						myStats.page_count as IndexTotalPageCount,'+
			@myNewLine+	N'						myPartitions.rows as IndexTotalRowCount,'+
			@myNewLine+	N'						(myStats.page_count*8)/(1024*1.000) as IndexTotalSizeMB,'+
			@myNewLine+	N'						myIndexes.[allow_page_locks] as AllowPageLocks,'+
			@myNewLine+	N'						myPartitions.data_compression as CompressionType,	--0=None,1=Row,2=Page,3=ColumnStore,4=ColumnStore_Archive'+
			@myNewLine+	N'						myIndexes.fill_factor as CurrentFillFactor,'+
			@myNewLine+	N'						TargetFillFactor='+
			@myNewLine+	N'							ISNULL('+
			@myNewLine+	N'							CASE '+
			@myNewLine+	N'								WHEN ''' + @FillFactor + N''' != ''AUTO'' AND '''+ @FillFactor +N''' != ''DISABLE'' THEN ' + CAST(CASE WHEN @FillFactor=N'0' THEN N'100' ELSE CASE WHEN ISNUMERIC(@FillFactor)=1 THEN @FillFactor ELSE N'80' END END AS NVARCHAR(MAX))+
			@myNewLine+	N'								WHEN ''' + @FillFactor + N''' = ''DISABLE'' THEN CASE WHEN myIndexes.fill_factor = 0 THEN 100 ELSE myIndexes.fill_factor END'+
			@myNewLine+	N'								WHEN ''' + @FillFactor + N''' = ''AUTO'' THEN'+
			@myNewLine+	N'									CASE'+
			@myNewLine+	N'										WHEN myStats.avg_fragmentation_in_percent<=' + CAST(@MedFragmentation_Boundry AS NVARCHAR(MAX)) + N' THEN CASE WHEN myIndexes.fill_factor=0 THEN 100 ELSE myIndexes.fill_factor END'+
			@myNewLine+	N'										WHEN myStats.avg_fragmentation_in_percent>' +  CAST(@MedFragmentation_Boundry AS NVARCHAR(MAX)) + N' AND myStats.avg_fragmentation_in_percent<=' + CAST(@HighFragmentation_Boundry AS NVARCHAR(MAX)) + N' THEN 90 '+
			@myNewLine+	N'										WHEN myStats.avg_fragmentation_in_percent>' +  CAST(@HighFragmentation_Boundry AS NVARCHAR(MAX)) +N' THEN 70 '+
			@myNewLine+	N'									END'+
			@myNewLine+	N'								END'+
			@myNewLine+	N'							,80)'+
			@myNewLine+	N'					FROM '+
			@myNewLine+	N'						#PhysicalStat AS myStats'+
			@myNewLine+	N'						INNER JOIN sys.indexes AS myIndexes ON myStats.[object_id] = myIndexes.[object_id] AND myStats.index_id = myIndexes.index_id'+
			@myNewLine+	N'						INNER JOIN sys.tables AS myTables on myTables.[object_id]=myIndexes.[object_id]'+
			@myNewLine+	N'						INNER JOIN sys.schemas AS mySchemas ON mySchemas.[schema_id] = myTables.[schema_id]'+
			@myNewLine+	N'						INNER JOIN sys.data_spaces as mySpace on mySpace.data_space_id=myIndexes.data_space_id'+
			@myNewLine+	N'						INNER JOIN sys.partitions AS myPartitions ON myIndexes.[object_id]=myPartitions.[object_id] AND myIndexes.index_id=myPartitions.index_id AND myStats.partition_number=myPartitions.partition_number'+
			@myNewLine+	N'						LEFT OUTER JOIN sys.dm_db_index_usage_stats AS myIndexesUsage ON [myIndexesUsage].[database_id] = DB_ID() AND myStats.[object_id] = myIndexesUsage.[object_id] AND myStats.index_id = myIndexesUsage.index_id'+
			@myNewLine+	N'						LEFT OUTER JOIN sys.partition_schemes as myPartitionScheme on myPartitionScheme.data_space_id=myIndexes.data_space_id'+
			@myNewLine+	N'						LEFT OUTER JOIN sys.destination_data_spaces AS myDestinationPartitionScheme ON myDestinationPartitionScheme.partition_scheme_id = myPartitionScheme.data_space_id AND myDestinationPartitionScheme.destination_id = myPartitions.partition_number'+
			@myNewLine+	N'						LEFT OUTER JOIN sys.partition_functions as myPartitionFunction on myPartitionFunction.function_id=myPartitionScheme.function_id'+
			@myNewLine+	N'						LEFT OUTER JOIN sys.filegroups AS myFileGroups ON [myFileGroups].[data_space_id] = [myIndexes].[data_space_id]'+
			@myNewLine+	N'						LEFT OUTER JOIN sys.filegroups AS myPartitionedFileGroups ON [myPartitionedFileGroups].[data_space_id] = [myDestinationPartitionScheme].[data_space_id]'+
			@myNewLine+	N'					WHERE'+
			@myNewLine+	N'						myIndexes.name is not NULL AND '+
			@myNewLine+	N'						myIndexes.is_disabled=0 AND'+
			@myNewLine+	N'						myTables.[type]= ''U'' AND'+
			@myNewLine+	N'						(@myIndexesUsedInLastXdays=0 OR ISNULL(myIndexesUsage.last_user_seek,0) >= @myMinimumLastUsedDate OR ISNULL(myIndexesUsage.last_user_scan,0) >= @myMinimumLastUsedDate OR ISNULL(myIndexesUsage.last_user_lookup,0) >= @myMinimumLastUsedDate)'+
			@myNewLine+	N'					) as myCore0'+
			@myNewLine+	N'				WHERE'+
			@myNewLine+	N'					myCore0.IsReadonly=0'+
			@myNewLine+	N'				) as myCore1'+
			@myNewLine+	N'			)as myCore2'+
			@myNewLine+	N'		) as myCore3'+
			@myNewLine+	N'		ORDER BY'+
			@myNewLine+	N'			myCore3.[object_id],'+
			@myNewLine+	N'			myCore3.index_id'+
			@myNewLine+	N''+
			CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'/*' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Comment execution
			@myNewLine+ N'DECLARE @Counter_Rebuild bigint;'+
			@myNewLine+ N'DECLARE @Counter_Reorganize bigint;'+
			@myNewLine+ N'DECLARE @Counter_Attention bigint;'+
			@myNewLine+ N'DECLARE @Counter_Print bigint;'+
			@myNewLine+ N'DECLARE @myCursor Cursor;'+
			@myNewLine+ N'DECLARE @mySQLStatement NVARCHAR(max);'+
			@myNewLine+ N'DECLARE @myCommandType NVARCHAR(50);'+
			@myNewLine+ N''+
			@myNewLine+ N'SET @Counter_Rebuild=0'+
			@myNewLine+ N'SET @Counter_Reorganize=0'+
			@myNewLine+ N'SET @Counter_Attention=0'+
			@myNewLine+ N'SET @Counter_Print=0'+
			@myNewLine+ N''+
			@myNewLine+ N'SET @myCursor=CURSOR For'+
			@myNewLine+	N'	SELECT SQLStatement,CommandsType FROM #IndexCommands ORDER BY CommandsType, Fragmentation DESC;'+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT ''Current database is '+ @Database_Name + N''';' +
			@myNewLine+ N'Open @myCursor'+
			@myNewLine+ N'	FETCH NEXT FROM @myCursor INTO @mySQLStatement,@myCommandType'+
			@myNewLine+ N'		WHILE @@FETCH_STATUS=0'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			BEGIN TRY'+
			@myNewLine+ N'				PRINT N''Executing ('' + @myCommandType + '' on '' + CAST(getdate() as nvarchar(50)) + ''):	'' + @mySQLStatement;'+
			@myNewLine+ N'				IF @myCommandType IN (''REORGANIZE'',''REBUILD'')'+
			@myNewLine+ N'					EXEC (@mySQLStatement);'+
			@myNewLine+ N'			END TRY'+
			@myNewLine+ N'			BEGIN CATCH'+
			@myNewLine+ N'				DECLARE @CustomMessage1 nvarchar(255)'+
			@myNewLine+ N'				SET @CustomMessage1=''Reindexing error on '+@Database_Name+N'''' +
			@myNewLine+ N'				EXECUTE ' + CAST(QUOTENAME(DB_NAME()) AS NVARCHAR(MAX)) + N'.[dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL'+
			@myNewLine+ N'			END CATCH'+
			@myNewLine+ N''+
			@myNewLine+ N'			IF @myCommandType=''REORGANIZE'''+
			@myNewLine+ N'				SET @Counter_Reorganize=@Counter_Reorganize+1'+
			@myNewLine+ N'			IF @myCommandType=''REBUILD'''+
			@myNewLine+ N'				SET @Counter_Rebuild=@Counter_Rebuild+1'+
			@myNewLine+ N'			IF @myCommandType=''ATTENTION'''+
			@myNewLine+ N'				SET @Counter_Attention=@Counter_Attention+1'+
			@myNewLine+ N'			IF @myCommandType=''PRINT'''+
			@myNewLine+ N'				SET @Counter_Print=@Counter_Print+1'+
			@myNewLine+ N''+
			@myNewLine+ N'			FETCH NEXT FROM @myCursor INTO @mySQLStatement,@myCommandType'+
			@myNewLine+ N'		END '+
			@myNewLine+ N'CLOSE @myCursor; '+
			@myNewLine+ N'DEALLOCATE @myCursor; '+
			@myNewLine+ N''+
			@myNewLine+ N'PRINT '''';'+
			@myNewLine+ N'PRINT ''Summery Report on '' + CAST(getdate() as nvarchar(50));'+
			@myNewLine+ N'PRINT ''=============='';'+
			@myNewLine+ N'PRINT ''Reorganize : '' + Cast(@Counter_Reorganize as nVarchar(5));' +
			@myNewLine+ N'PRINT ''Rebuild : '' + Cast(@Counter_Rebuild as nVarchar(5));'+
			@myNewLine+ N'PRINT ''Attention : '' + Cast(@Counter_Attention as nVarchar(5));'+
			@myNewLine+ N'PRINT ''Print : '' + Cast(@Counter_Print as nVarchar(5));'+
			@myNewLine+ N'PRINT ''Total : '' + Cast(@Counter_Reorganize + @Counter_Rebuild as nVarchar(5));'+
			CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'*/' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Comment execution
			CAST(CASE WHEN @PrintOnly=1 THEN @myNewLine+N'SELECT * FROM #IndexCommands ORDER BY CommandsType, Fragmentation DESC;' ELSE N'' END AS NVARCHAR(MAX)) +	--for Print only Command, Return commands list
			@myNewLine+	N'DROP TABLE #IndexCommands;'+
			@myNewLine+	N'DROP TABLE #PhysicalStat;'
			AS NVARCHAR(MAX))

		EXEC [dbo].[dbasp_print_text] @mySQLScript
		IF @PrintOnly=0
			PRINT (@myNewLine + '--Excexution Report--');

		IF @Database_IsReadOnly=0 AND @PrintOnly=0
		BEGIN
			--=======Start of executing commands
			BEGIN TRY
				EXECUTE (@mySQLScript);
			END TRY
			BEGIN CATCH
				DECLARE @CustomMessage1 NVARCHAR(255)
				SET @CustomMessage1='Reindexing error on ' + @Database_Name
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
			END CATCH
			--=======End of executing commands
		END
		ELSE IF @Database_IsReadOnly=1 AND @PrintOnly=0
		BEGIN
			PRINT (@myNewLine + @Database_Name + ' is read-only.');
		END
		FETCH NEXT FROM @myCursor INTO @Database_Name
	END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_reindex', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2016-04-02', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_reindex', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-12-28', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_reindex', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.5', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_reindex', NULL, NULL
GO
