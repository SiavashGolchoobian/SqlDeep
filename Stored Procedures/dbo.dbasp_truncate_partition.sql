SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[dbasp_truncate_partition] @SchemaName VARCHAR(20),@TabName VARCHAR(100), @PartitionNo INT 
AS
BEGIN 

/*
- Procedure Name: dbo.TRUNCATE_PARTITION
- Date of creation: 06-Jan-2010
- Author- Mr. Vidhaydhar Vijay Pandekar
- Email- 
 vidya_pande@yahoo.com
 
- Description: Truncates specified Partition from partitioned table.
- Application: 
 1. To truncate the partition automatically and to avoid sequence of manual steps required for truncating partitions
 2. As a replacement to the ALTER TABLE TRUNCATE PARITION statement of oracle. This becomes useful when oracle code
 requires replacement for this statement while migrating to SQL Server.

- Input Parameters: 
 1. @SchemaName - Partitioned Table Schema Name 
 2. @TabName - Partitioned Table Name
 3. @PartitionNo - Partition number to be truncated

- Command for execution- exec TRUNCATE_PARTITION 'SchemaName','TableName',PartitionNumber
 i.e. exe TRUNCATE_PARTITION 'dbo','Table1',3
- Successful Test results for- 
 1 No Clustered Primary key and No Clustered Index
 2 Clustered Primary key 
 3 No Primary key and Clustered Index
 4. Non Clustered Primary key
- Change History
 v1.0 Creation - 06-Jan-2010
 V2.0 Modied - 9th Feb-2010- Table Schema name issue resolved
 V3.0 Modified- 10th Feb 2010 - step1.5 Added functionality to consider if source table/ partition is compressed    
 v4.0 Modified-11th Feb 2010 - Step 2- modified Pk related issue 
*/

SET NOCOUNT ON

BEGIN TRANSACTION;
 
 BEGIN TRY

 /* Step-1 start create staging table*/
 DECLARE @PkIndex VARCHAR(200)
 DECLARE @CreateTab VARCHAR(8000)
 SELECT @CreateTab='select top 0 * into '+@SchemaName+'.'+@TabName+'_'+CONVERT(VARCHAR(5),@PartitionNo)+' from '+@SchemaName+'.'+@TabName
 EXEC (@CreateTab)
 /* End create staging table*/
 
 --STEP 1.5 
 -- ADDED ON 10th Feb 2010. Added functionality to the script of source partitioned table/ partition is compressed.
 
 declare @IsCompressed int
 declare @CompressionType varchar(10)
 declare @altStatement varchar(1000)
 SELECT @IsCompressed=data_compression,@CompressionType=data_compression_desc 
 FROM sys.PARTITIONS where object_id=OBJECT_ID(@SchemaName+'.'+@TabName) and partition_number=@PartitionNo and index_id=0

 
 If @IsCompressed=1
 BEGIN
  select @altStatement = 'ALTER TABLE '+@SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)+' REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = '+@CompressionType+')'
  exec (@altStatement)
 END

 /*Step2-start add PK */
 DECLARE @Pk_available INT =0
 DECLARE @CI_available INT =0

 SELECT @Pk_available =(SELECT 1 FROM sys.objects a inner join sys.indexes b ON a.object_id=b.object_id 
 WHERE a.object_id =OBJECT_ID(@SchemaName+'.'+@TabName) and (b.is_primary_key=1 AND b.index_id=1))
 SELECT @CI_available =(SELECT 1 FROM sys.objects a inner join sys.indexes b ON a.object_id=b.object_id 
 WHERE a.object_id =OBJECT_ID(@SchemaName+'.'+@TabName) and (b.is_primary_key=0 AND b.index_id=1))
--added on 11th Feb 2010
 if @Pk_available is null
 set @Pk_available=0

 if @CI_available is null
 set @CI_available=0
------

 IF (@Pk_available='1' or @CI_available='1')
 BEGIN
 DECLARE @TAB_ID1 int
 SELECT @TAB_ID1= OBJECT_ID(@SchemaName+'.'+@TabName) 
 DECLARE @pkInfo table (SCHEMANAME VARCHAR(20),table_name varchar(100), pk_name varchar(100),columnName varchar(100), asckey char(1),IsUnique char(1))
 INSERT INTO @pkInfo 
 (SCHEMANAME, table_name,pk_name,columnName,asckey,IsUnique)
 SELECT 
 SCHEMANAME=@SchemaName,
 B.NAME TABLE_NAME, 
 PK_NAME=
 (SELECT a.name PK_NAME FROM sys.indexes a 
 WHERE A.OBJECT_ID=B.OBJECT_ID AND A.index_id=1),
 COLUMN_NAME=
 (SELECT name FROM sys.columns E WHERE E.OBJECT_ID=B.object_id AND E.column_id=D.column_id),
 D.is_descending_key,
 C.is_unique
 FROM SYS.OBJECTS B 
 INNER JOIN sys.INDEXES C ON 
 B.object_id=C.object_id
 INNER JOIN sys.index_columns D ON
 B.object_id=D.object_id
 WHERE B.TYPE='U'
 AND (C.index_id=1)
 AND B.object_id=@TAB_ID1

 DECLARE @alterstatement VARCHAR(8000) 
 DECLARE @Pkname VARCHAR(100),@columns VARCHAR(4000)

 SELECT @Pkname=pk_name FROM @pkInfo
 
 DECLARE @ALLcolumns TABLE (idcol1 INT IDENTITY,colname VARCHAR(100))
 INSERT INTO @ALLcolumns (colname)SELECT columnName FROM @pkInfo
 DECLARE @cnt INT
 DECLARE @clncnt INT
 SELECT @cnt=1
 SELECT @clncnt=COUNT(*) FROM @ALLcolumns
 DECLARE @cols VARCHAR(400)
 SELECT @cols=''
 while @clncnt>=@cnt
 begin
 select @cols=@cols+','+ colname FROM @ALLcolumns WHERE idcol1=@cnt
 select @cnt=@cnt+1
 end 
 select @columns=SUBSTRING(@cols,2,len(@cols))
 
 end 
 
 

 if @Pk_available='1'
 select @alterstatement='ALTER TABLE '+@SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)+ ' ADD CONSTRAINT '+@Pkname+CONVERT(varchar(5),@PartitionNo)+' PRIMARY KEY CLUSTERED ('+@columns+')'
 if @Pk_available<>'1' 
 SELECT @alterstatement='ALTER TABLE '+@SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)+' ADD IDCOL INT CONSTRAINT PK_'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo) +' PRIMARY KEY'
 exec (@alterstatement)
 
 
 /*end add PK */

 /* Step3- Start identify file group of partition to be truncated*/

 Declare @filegroup varchar(50)
 SELECT @filegroup=
 CASE
 WHEN fg.name IS NULL THEN ds.name
 ELSE fg.name
 END 
 FROM sys.dm_db_partition_stats p
 INNER JOIN sys.indexes i
 ON i.OBJECT_ID = p.OBJECT_ID AND i.index_id = p.index_id
 INNER JOIN sys.data_spaces ds
 ON ds.data_space_id = i.data_space_id
 LEFT OUTER JOIN sys.partition_schemes ps
 ON ps.data_space_id = i.data_space_id
 LEFT OUTER JOIN sys.destination_data_spaces dds
 ON dds.partition_scheme_id = ps.data_space_id
 AND dds.destination_id = p.partition_number
 LEFT OUTER JOIN sys.filegroups fg
 ON fg.data_space_id = dds.data_space_id
 LEFT OUTER JOIN sys.partition_range_values prv_right
 ON prv_right.function_id = ps.function_id
 AND prv_right.boundary_id = p.partition_number
 LEFT OUTER JOIN sys.partition_range_values prv_left
 ON prv_left.function_id = ps.function_id
 AND prv_left.boundary_id = p.partition_number - 1
 WHERE
 OBJECTPROPERTY(p.OBJECT_ID, 'ISMSSHipped') = 0
 AND p.index_id IN (0,1)
 AND OBJECT_NAME(p.OBJECT_ID)=@TabName 
 AND p.partition_number=@PartitionNo


 /* end identify file group of partition to be truncated*/


 /*Step4- Start Move table to File group of Partition Table */
 
 
 if (@Pk_available='1' )
 BEGIN
 select @alterstatement ='ALTER TABLE '+@SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)+ ' DROP CONSTRAINT '+@Pkname+CONVERT(varchar(5),@PartitionNo)+' WITH (MOVE TO ['+@filegroup+'])'
 exec (@alterstatement)

 select @alterstatement='ALTER TABLE '+@SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)+ ' ADD CONSTRAINT '+@Pkname+CONVERT(varchar(5),@PartitionNo)+' PRIMARY KEY ( '+@columns+')'
 exec (@alterstatement)
 END
 
 if (@Pk_available<>'1' )
 BEGIN
 
 select @alterstatement ='ALTER TABLE '+@SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)+ ' DROP CONSTRAINT PK_'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo) +' WITH (MOVE TO ['+@filegroup+'])'
 exec (@alterstatement)

 
 select @alterstatement='ALTER TABLE '+@SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)+ ' drop column idcol'
 exec (@alterstatement)
 END 
 
 /*Step5- Create clustered index of staging table if it is there on source partitioned table to make the schema equal */
 if (@CI_available='1' ) 
 BEGIN
 DECLARE @IsUnique char(1) 
 select @IsUnique= IsUnique from @pkInfo
 IF @CI_available='1' AND @IsUnique='1'
 select @alterstatement='CREATE UNIQUE CLUSTERED INDEX '+@Pkname+CONVERT(varchar(5),@PartitionNo)+' ON '+ @SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)+ ' ( '+@columns+')'
 IF @CI_available='1' AND @IsUnique='0' 
 select @alterstatement='CREATE CLUSTERED INDEX '+@Pkname+CONVERT(varchar(5),@PartitionNo)+' ON '+ @SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)+ ' ( '+@columns+')'

 exec (@alterstatement)
 
 END
 

 --Step6 - switch partition
 select @alterstatement='alter table '+@SCHEMANAME+'.'+@TabName+' switch partition '+CONVERT(varchar(5),@PartitionNo)+' to '+@SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)
 exec (@alterstatement)

 --Step7 drop staging table 
 select @alterstatement='drop table '+@SCHEMANAME+'.'+@TabName+'_'+CONVERT(varchar(5),@PartitionNo)
 exec (@alterstatement)
 
 
 END TRY
 --Error Handling
 BEGIN CATCH
 Print 'Truncate Partition Failed due to error.'
 SELECT 
ERROR_NUMBER() AS ErrorNumber
,ERROR_SEVERITY() AS ErrorSeverity
,ERROR_STATE() AS ErrorState
,ERROR_PROCEDURE() AS ErrorProcedure
,ERROR_LINE() AS ErrorLine
,ERROR_MESSAGE() AS ErrorMessage;

IF @@TRANCOUNT > 0
ROLLBACK TRANSACTION;
 END CATCH;
 
 IF @@TRANCOUNT > 0
COMMIT TRANSACTION;

END




GO
EXEC sp_addextendedproperty N'Author', N'Mr.Vidhaydhar Vijay Pandekar', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_partition', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2010-01-06', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_partition', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_partition', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_truncate_partition', NULL, NULL
GO
