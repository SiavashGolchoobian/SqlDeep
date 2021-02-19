SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/29/2015>
-- Version:		<3.0.0.0>
-- Description:	<Return list of index creation commands of database>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
-- =============================================
CREATE Procedure [dbo].[dbasp_index_get_createscript] (
	@DatabaseNames nvarchar(MAX) = N'<ALL_USER_DATABASES>'
	)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @myNewLine nvarchar(10);
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @CommandList TABLE ([Database_Name] nvarchar(255) ,[CreateIndexScript] nvarchar (max))

	SET @myNewLine=CHAR(13)+CHAR(10)
    SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,0,0)

	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
	WHILE @@FETCH_STATUS=0
		BEGIN
			SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
			SET @mySQLScript = @mySQLScript+
				CAST(
				@myNewLine + N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
				@myNewLine +
					N'SELECT 
						DB_NAME(),
						'' CREATE '' +
						CASE WHEN I.is_unique = 1 THEN '' UNIQUE '' ELSE '''' END  + 
						I.type_desc COLLATE DATABASE_DEFAULT +'' INDEX '' +  
						QUOTENAME(I.name)  + '' ON ''  + 
						QUOTENAME(Schema_name(T.Schema_id))+''.''+QUOTENAME(T.name) + '' ( '' +
						KeyColumns + '' )  '' +
						ISNULL('' INCLUDE (''+IncludedColumns+'' ) '','''') +
						ISNULL('' WHERE  ''+I.Filter_definition,'''') + '' WITH ( '' +
						CASE WHEN I.is_padded = 1 THEN '' PAD_INDEX = ON '' ELSE '' PAD_INDEX = OFF '' END + '',''  +
						''FILLFACTOR = ''+CONVERT(CHAR(5),CASE WHEN I.Fill_factor = 0 THEN 100 ELSE I.Fill_factor END) + '',''  +
						-- default value
						''SORT_IN_TEMPDB = ON ''  + '',''  +
						CASE WHEN I.ignore_dup_key = 1 THEN '' IGNORE_DUP_KEY = ON '' ELSE '' IGNORE_DUP_KEY = OFF '' END + '',''  +
						CASE WHEN ST.no_recompute = 0 THEN '' STATISTICS_NORECOMPUTE = OFF '' ELSE '' STATISTICS_NORECOMPUTE = ON '' END + '',''  +
						-- default value 
						'' DROP_EXISTING = ON ''  + '',''  +
						-- default value 
						'' ONLINE = OFF ''  + '',''  +
						CASE WHEN I.allow_row_locks = 1 THEN '' ALLOW_ROW_LOCKS = ON '' ELSE '' ALLOW_ROW_LOCKS = OFF '' END + '',''  +
						CASE WHEN I.allow_page_locks = 1 THEN '' ALLOW_PAGE_LOCKS = ON '' ELSE '' ALLOW_PAGE_LOCKS = OFF '' END  + '' ) ON ['' +
						DS.name + '' ] ''  [CreateIndexScript]
					FROM 
						sys.indexes as I  
						INNER JOIN sys.tables as T ON T.Object_id = I.Object_id   
						INNER JOIN sys.sysindexes as SI ON I.Object_id = SI.id AND I.index_id = SI.indid  
						INNER JOIN (	--tmp4  
									SELECT 
										* 
									FROM ( --tmp3
										SELECT 
											IC2.object_id
											,IC2.index_id
											,STUFF((SELECT '' , '' + QUOTENAME(C.name) + CASE WHEN MAX(CONVERT(INT,IC1.is_descending_key)) = 1 THEN '' DESC '' ELSE '' ASC '' END
													FROM 
														sys.index_columns as IC1 
														INNER JOIN Sys.columns as C ON C.object_id = IC1.object_id AND C.column_id = IC1.column_id AND IC1.is_included_column = 0 
													WHERE 
														IC1.object_id = IC2.object_id  
														AND IC1.index_id = IC2.index_id  
													GROUP BY 
														IC1.object_id
														,C.name
														,index_id 
													ORDER BY 
														MAX(IC1.key_ordinal) 
													FOR XML PATH('''')), 1, 2, '''') AS KeyColumns
										FROM 
											sys.index_columns as IC2  
										--WHERE 
											--IC2.Object_id = object_id(''Person.Address'') --Comment for all tables 
										GROUP BY 
											IC2.object_id
											,IC2.index_id
											) as tmp3 
										) as tmp4  
										ON I.object_id = tmp4.object_id AND I.Index_id = tmp4.index_id 
						INNER JOIN sys.stats ST ON ST.object_id = I.object_id AND ST.stats_id = I.index_id  
						INNER JOIN sys.data_spaces DS ON I.data_space_id=DS.data_space_id  
						INNER JOIN sys.filegroups FG ON I.data_space_id=FG.data_space_id  
						LEFT OUTER JOIN (	--tmp2   
									SELECT 
										* 
									FROM (  --tmp1  
										SELECT 
											IC2.object_id
											,IC2.index_id
											,STUFF((SELECT '' , '' + QUOTENAME(C.name) 
												FROM 
													sys.index_columns as IC1  
													INNER JOIN Sys.columns as C ON C.object_id = IC1.object_id AND C.column_id = IC1.column_id AND IC1.is_included_column = 1  
												WHERE 
													IC1.object_id = IC2.object_id   
													AND IC1.index_id = IC2.index_id   
												GROUP BY 
													IC1.object_id
													,C.name
													,index_id  
												FOR XML PATH('''')), 1, 2, '''') as IncludedColumns   
										FROM 
											sys.index_columns as IC2   
										--WHERE IC2.Object_id = object_id(''Person.Address'') --Comment for all tables  
										GROUP BY 
											IC2.object_id
											,IC2.index_id
										) as tmp1  
									WHERE 
										IncludedColumns IS NOT NULL 
									) as tmp2
									ON tmp2.object_id = I.object_id AND tmp2.index_id = I.index_id  
					WHERE 
						I.is_primary_key = 0 
						AND I.is_unique_constraint = 0
						AND I.type>0 
						AND T.is_ms_shipped=0
						AND T.name<>''sysdiagrams''
						'
				AS NVARCHAR(MAX))
						--AND I.Object_id = object_id(''Person.Address'') --Comment for all tables
						--AND I.name = ''IX_Address_PostalCode'' --comment for all indexes'
			
			EXEC [dbo].[dbasp_print_text] @mySQLScript
			INSERT INTO @CommandList ([Database_Name],[CreateIndexScript]) EXECUTE sp_executesql @mySQLScript
			FETCH NEXT FROM @myCursor INTO @Database_Name
		END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;

	SELECT [Database_Name],[CreateIndexScript] FROM @CommandList
	----=====================ANOTHER GOOD and SIMPLE script for same job
	----declare @SchemaName varchar(100)declare @TableName varchar(256)
	----declare @IndexName varchar(256)
	----declare @ColumnName varchar(100)
	----declare @is_unique varchar(100)
	----declare @IndexTypeDesc varchar(100)
	----declare @FileGroupName varchar(100)
	----declare @is_disabled varchar(100)
	----declare @IndexOptions varchar(max)
	----declare @IndexColumnId int
	----declare @IsDescendingKey int 
	----declare @IsIncludedColumn int
	----declare @TSQLScripCreationIndex varchar(max)
	----declare @TSQLScripDisableIndex varchar(max)

	----declare CursorIndex cursor for
	----	select 
	----		schema_name(t.schema_id) as [schema_name]
	----		,t.name
	----		,ix.name
	----		,case when ix.is_unique = 1 then 'UNIQUE ' else '' END 
	----		,ix.type_desc
	----		,case when ix.is_padded=1 then 'PAD_INDEX = ON, ' else 'PAD_INDEX = OFF, ' end
	----			+ case when ix.allow_page_locks=1 then 'ALLOW_PAGE_LOCKS = ON, ' else 'ALLOW_PAGE_LOCKS = OFF, ' end
	----			+ case when ix.allow_row_locks=1 then  'ALLOW_ROW_LOCKS = ON, ' else 'ALLOW_ROW_LOCKS = OFF, ' end
	----			+ case when INDEXPROPERTY(t.object_id, ix.name, 'IsStatistics') = 1 then 'STATISTICS_NORECOMPUTE = ON, ' else 'STATISTICS_NORECOMPUTE = OFF, ' end
	----			+ case when ix.ignore_dup_key=1 then 'IGNORE_DUP_KEY = ON, ' else 'IGNORE_DUP_KEY = OFF, ' end
	----			+ 'SORT_IN_TEMPDB = OFF, FILLFACTOR =' + CAST(ix.fill_factor AS VARCHAR(3)) AS IndexOptions
	----		,ix.is_disabled
	----		,FILEGROUP_NAME(ix.data_space_id) as FileGroupName
	----	from 
	----		sys.tables as t 
	----		inner join sys.indexes as ix on t.object_id=ix.object_id
	----	where 
	----		ix.type>0 
	----		and ix.is_primary_key=0 
	----		and ix.is_unique_constraint=0 
	----		--and schema_name(tb.schema_id)= @SchemaName and tb.name=@TableName
	----		and t.is_ms_shipped=0 
	----		and t.name<>'sysdiagrams'
	----	order by 
	----		schema_name(t.schema_id)
	----		,t.name
	----		,ix.name

	----open CursorIndex
	----fetch next from CursorIndex into  @SchemaName, @TableName, @IndexName, @is_unique, @IndexTypeDesc, @IndexOptions,@is_disabled, @FileGroupName

	----while (@@fetch_status=0)
	----begin
	----	declare @IndexColumns varchar(max)
	----	declare @IncludedColumns varchar(max)
 
	----	set @IndexColumns=''
	----	set @IncludedColumns=''
 
	----	declare CursorIndexColumn cursor for 
	----		select 
	----			col.name
	----			,ixc.is_descending_key
	----			,ixc.is_included_column
	----		from 
	----			sys.tables as tb 
	----			inner join sys.indexes as ix on tb.object_id=ix.object_id
	----			inner join sys.index_columns as ixc on ix.object_id=ixc.object_id and ix.index_id= ixc.index_id
	----			inner join sys.columns as col on ixc.object_id =col.object_id  and ixc.column_id=col.column_id
	----		where 
	----			ix.type>0 
	----			and (ix.is_primary_key=0 or ix.is_unique_constraint=0)
	----			and schema_name(tb.schema_id)=@SchemaName 
	----			and tb.name=@TableName 
	----			and ix.name=@IndexName
	----		order by 
	----			ixc.index_column_id
 
	----	open CursorIndexColumn 
	----	fetch next from CursorIndexColumn into  @ColumnName, @IsDescendingKey, @IsIncludedColumn
 
	----	while (@@fetch_status=0)
	----	begin
	----		if @IsIncludedColumn=0 
	----			set @IndexColumns=@IndexColumns + @ColumnName  + case when @IsDescendingKey=1  then ' DESC, ' else  ' ASC, ' end
	----		else 
	----			set @IncludedColumns=@IncludedColumns  + @ColumnName  +', ' 

	----	fetch next from CursorIndexColumn into @ColumnName, @IsDescendingKey, @IsIncludedColumn
	----	end

	----	close CursorIndexColumn
	----	deallocate CursorIndexColumn

	----	set @IndexColumns = substring(@IndexColumns, 1, len(@IndexColumns)-1)
	----	set @IncludedColumns = case when len(@IncludedColumns) >0 then substring(@IncludedColumns, 1, len(@IncludedColumns)-1) else '' end
	----	--  print @IndexColumns
	----	--  print @IncludedColumns

	----	set @TSQLScripCreationIndex =''
	----	set @TSQLScripDisableIndex =''
	----	set @TSQLScripCreationIndex='CREATE '+ @is_unique  +@IndexTypeDesc + ' INDEX ' +QUOTENAME(@IndexName)+' ON ' + QUOTENAME(@SchemaName) +'.'+ QUOTENAME(@TableName)+ '('+@IndexColumns+') '+ 
	----	case when len(@IncludedColumns)>0 then CHAR(13) +'INCLUDE (' + @IncludedColumns+ ')' else '' end + CHAR(13)+'WITH (' + @IndexOptions+ ') ON ' + QUOTENAME(@FileGroupName) + ';'  

	----	if @is_disabled=1 
	----		set  @TSQLScripDisableIndex=  CHAR(13) +'ALTER INDEX ' +QUOTENAME(@IndexName) + ' ON ' + QUOTENAME(@SchemaName) +'.'+ QUOTENAME(@TableName) + ' DISABLE;' + CHAR(13) 

	----	--print @TSQLScripCreationIndex
	----	--print @TSQLScripDisableIndex
	----	INSERT INTO @CommandList ([CreateIndexScript]) VALUES (@TSQLScripCreationIndex)

	----	fetch next from CursorIndex into  @SchemaName, @TableName, @IndexName, @is_unique, @IndexTypeDesc, @IndexOptions,@is_disabled, @FileGroupName
	----end

	----close CursorIndex
	----deallocate CursorIndex
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_index_get_createscript', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-29', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_index_get_createscript', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_index_get_createscript', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_index_get_createscript', NULL, NULL
GO
