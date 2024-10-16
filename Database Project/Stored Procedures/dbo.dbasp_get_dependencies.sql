SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Golchoobian>
-- Create date: <3/3/2021>
-- Version:		<3.0.0.0>
-- Description:	<Calculate object dependency hierarchy>
-- Input Parameters:
--	@DatabaseName:		name of database
--	@ObjectTypeFilters:	any combination of object types like: [FN],[IF],[TF],[V],[U],[P], you can find object types via sys.all_objects
--	@PrintOnly:			0 or 1
-- =============================================

CREATE PROCEDURE [dbo].[dbasp_get_dependencies]
	@DatabaseName sysname,
	@ObjectTypeFilters NVARCHAR(MAX)=N'[FN],[IF],[TF],[V],[U],[P]',
	@PrintOnly BIT=0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myDatabaseName NVARCHAR(128);
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);

	SET @myDatabaseName=@DatabaseName
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
	SET @mySQLScript=@mySQLScript+
		CAST(
		@myNewLine+ N'USE '+ CAST(QUOTENAME(@myDatabaseName) AS NVARCHAR(MAX)) + N';'+
		@myNewLine+ N'DECLARE @myResultList TABLE (ObjectId INT PRIMARY KEY, ObjectName NVARCHAR(256),ObjectType NVARCHAR(5), DependencyLevel INT, DependentObjects NVARCHAR(MAX))'+
		@myNewLine+ N'DECLARE @myDependentList TABLE (ReferencingId INT,ReferencedId INT)'+
		@myNewLine+ N'DECLARE @myTargetObjects NVARCHAR(MAX)'+
		@myNewLine+ N'SET @myTargetObjects=N'''+@ObjectTypeFilters+''''+
		@myNewLine+ N''+
		@myNewLine+ N'INSERT INTO @myDependentList([ReferencingId], [ReferencedId])'+
		@myNewLine+ N'SELECT DISTINCT'+
		@myNewLine+ N'	[myDepend].[referencing_id],'+
		@myNewLine+ N'	[myDepend].[referenced_id]'+
		@myNewLine+ N'FROM'+
		@myNewLine+ N'	[sys].[sql_expression_dependencies] AS myDepend'+
		@myNewLine+ N'	INNER JOIN [sys].[all_objects] AS myReferencingObject ON [myDepend].[referencing_id]=[myReferencingObject].[object_id]'+
		@myNewLine+ N'	INNER JOIN [sys].[all_objects] AS myReferencedObject ON [myDepend].[referenced_id]=[myReferencedObject].[object_id]'+
		@myNewLine+ N'WHERE'+
		@myNewLine+ N'	[myDepend].[referencing_class]=1'+
		@myNewLine+ N'	AND [myDepend].[referenced_class]=1'+
		@myNewLine+ N'	AND [myDepend].[referencing_minor_id]=0'+
		@myNewLine+ N'	AND [myDepend].[referenced_minor_id]=0'+
		@myNewLine+ N'	AND PATINDEX(''%[[]'' + TRIM(CAST([myReferencingObject].[type] AS NVARCHAR(5))) + '']%'',@myTargetObjects)>0'+
		@myNewLine+ N'	AND PATINDEX(''%[[]'' + TRIM(CAST([myReferencedObject].[type]  AS NVARCHAR(5))) + '']%'',@myTargetObjects)>0'+
		@myNewLine+ N''+
		@myNewLine+ N'INSERT INTO @myResultList ([ObjectId], [ObjectName], [ObjectType], [DependencyLevel], [DependentObjects])'+
		@myNewLine+ N'SELECT '+
		@myNewLine+ N'	[myObjects].[object_id] AS ObjectId,'+
		@myNewLine+ N'	CONCAT(QUOTENAME([mySchema].[name]),''.'',QUOTENAME([myObjects].[name])) AS ObjectName,'+
		@myNewLine+ N'	[myObjects].[type],'+
		@myNewLine+ N'	0 AS DependencyLevel,'+
		@myNewLine+ N'	NULL'+
		@myNewLine+ N'FROM '+
		@myNewLine+ N'	[sys].[all_objects] AS myObjects'+
		@myNewLine+ N'	INNER JOIN [sys].[schemas] AS mySchema ON [mySchema].[schema_id] = [myObjects].[schema_id]'+
		@myNewLine+ N'	LEFT OUTER JOIN @myDependentList AS myValidDependentList ON [myObjects].[object_id]=[myValidDependentList].[ReferencingId]'+
		@myNewLine+ N'WHERE'+
		@myNewLine+ N'	[myObjects].[is_ms_shipped]=0'+
		@myNewLine+ N'	AND PATINDEX(''%[[]'' + TRIM(CAST([myObjects].[type] AS NVARCHAR(5))) + '']%'',@myTargetObjects)>0'+
		@myNewLine+ N'	AND [myValidDependentList].[ReferencingId] IS NULL'+
		@myNewLine+ N''+
		@myNewLine+ N'INSERT INTO @myResultList ([ObjectId], [ObjectName], [ObjectType], [DependencyLevel], [DependentObjects])'+
		@myNewLine+ N'SELECT DISTINCT'+
		@myNewLine+ N'	[myReferenced].[ReferencedId],'+
		@myNewLine+ N'	CONCAT(QUOTENAME([mySchema].[name]),''.'',QUOTENAME([myObjects].[name])) AS ObjectName,'+
		@myNewLine+ N'	[myObjects].[type],'+
		@myNewLine+ N'	1 AS DependencyLevel,'+
		@myNewLine+ N'	NULL'+
		@myNewLine+ N'FROM'+
		@myNewLine+ N'	@myDependentList AS myReferenced'+
		@myNewLine+ N'	INNER JOIN [sys].[all_objects] AS myObjects ON [myReferenced].[ReferencedId]=[myObjects].[object_id]'+
		@myNewLine+ N'	INNER JOIN [sys].[schemas] AS mySchema ON [mySchema].[schema_id] = [myObjects].[schema_id]'+
		@myNewLine+ N'	LEFT OUTER JOIN @myDependentList AS myReferencing ON [myReferenced].[ReferencedId]=[myReferencing].[ReferencingId]'+
		@myNewLine+ N'WHERE'+
		@myNewLine+ N'	[myReferencing].[ReferencingId] IS NULL'+
		@myNewLine+ N'	AND [myReferenced].[ReferencedId] NOT IN (SELECT [ObjectId] FROM @myResultList)'+
		@myNewLine+ N''+
		@myNewLine+ N'WHILE EXISTS(SELECT [ReferencingId] AS ObjectId FROM @myDependentList UNION SELECT [ReferencedId] AS ObjectId FROM @myDependentList EXCEPT SELECT [ObjectId] FROM @myResultList)'+
		@myNewLine+ N'BEGIN'+
		@myNewLine+ N'	INSERT INTO @myResultList ([ObjectId], [ObjectName], [ObjectType], [DependencyLevel], [DependentObjects])'+
		@myNewLine+ N'	SELECT'+
		@myNewLine+ N'		[myPreccessedStat].[ReferencingId],'+
		@myNewLine+ N'		CONCAT(QUOTENAME([mySchema].[name]),''.'',QUOTENAME([myObjects].[name])) AS ObjectName,'+
		@myNewLine+ N'		[myObjects].[type],'+
		@myNewLine+ N'		[myPreccessedStat].[DependencyLevel]+1 AS [DependencyLevel],'+
		@myNewLine+ N'		[myPreccessedStat].[DependentObjects]'+
		@myNewLine+ N'	FROM'+
		@myNewLine+ N'		('+
		@myNewLine+ N'		SELECT'+
		@myNewLine+ N'			[myUnProccessedList].[ReferencingId],'+
		@myNewLine+ N'			COUNT(1) AS TotalReferencedCount'+
		@myNewLine+ N'		FROM'+
		@myNewLine+ N'			@myDependentList AS myUnProccessedList'+
		@myNewLine+ N'		WHERE'+
		@myNewLine+ N'			[myUnProccessedList].[ReferencingId] NOT IN (SELECT [ObjectId] FROM @myResultList)'+
		@myNewLine+ N'		GROUP BY'+
		@myNewLine+ N'			[myUnProccessedList].[ReferencingId]'+
		@myNewLine+ N'		) AS myTotalStat'+
		@myNewLine+ N'		INNER JOIN'+
		@myNewLine+ N'		('+
		@myNewLine+ N'		SELECT'+
		@myNewLine+ N'			[myUnProccessedList].[ReferencingId],'+
		@myNewLine+ N'			COUNT(1) AS ProccessedReferencedCount,'+
		@myNewLine+ N'			MAX([myReferencedList].[DependencyLevel]) AS [DependencyLevel],'+
		@myNewLine+ N'			STRING_AGG(CONCAT(CAST([myUnProccessedList].[ReferencedId] AS NVARCHAR(MAX)),'','',[myReferencedList].[DependentObjects]) ,'','') AS DependentObjects'+
		@myNewLine+ N'		FROM'+
		@myNewLine+ N'			@myDependentList AS myUnProccessedList'+
		@myNewLine+ N'			INNER JOIN @myResultList AS myReferencedList ON [myUnProccessedList].[ReferencedId]=[myReferencedList].[ObjectId]'+
		@myNewLine+ N'		WHERE'+
		@myNewLine+ N'			[myUnProccessedList].[ReferencingId] NOT IN (SELECT [ObjectId] FROM @myResultList)'+
		@myNewLine+ N'		GROUP BY'+
		@myNewLine+ N'			[myUnProccessedList].[ReferencingId]'+
		@myNewLine+ N'		) AS myPreccessedStat ON [myPreccessedStat].[ReferencingId] = [myTotalStat].[ReferencingId]'+
		@myNewLine+ N'		INNER JOIN [sys].[all_objects] AS myObjects ON [myPreccessedStat].[ReferencingId]=[myObjects].[object_id]'+
		@myNewLine+ N'		INNER JOIN [sys].[schemas] AS mySchema ON [mySchema].[schema_id] = [myObjects].[schema_id]'+
		@myNewLine+ N'	WHERE'+
		@myNewLine+ N'		[myTotalStat].[TotalReferencedCount]<=[myPreccessedStat].[ProccessedReferencedCount]'+
		@myNewLine+ N'END'+
		@myNewLine+ N''+
		@myNewLine+ N'SELECT '+
		@myNewLine+ N'	[ObjectId],'+
		@myNewLine+ N'	[ObjectName],'+
		@myNewLine+ N'	[ObjectType],'+
		@myNewLine+ N'	[DependencyLevel],'+
		@myNewLine+ N'	[DependentObjects]'+
		@myNewLine+ N'FROM '+
		@myNewLine+ N'	@myResultList '+
		@myNewLine+ N'ORDER BY '+
		@myNewLine+ N'	[DependencyLevel],'+
		@myNewLine+ N'	[ObjectType],'+
		@myNewLine+ N'	[ObjectName]'
		AS NVARCHAR(MAX))

		EXEC [dbo].[dbasp_print_text] @mySQLScript
		IF @PrintOnly=0
		BEGIN
			--=======Start of executing commands
			BEGIN TRY
				EXECUTE (@mySQLScript);
			END TRY
			BEGIN CATCH
				DECLARE @CustomMessage1 NVARCHAR(255)
				SET @CustomMessage1='Dependency calculaor eror ' + @myDatabaseName
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
			END CATCH
			--=======End of executing commands
		END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_dependencies', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2021-03-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_dependencies', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-03-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_dependencies', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_dependencies', NULL, NULL
GO
