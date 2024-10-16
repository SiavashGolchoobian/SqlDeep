SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <2/4/2015>
-- Version:		<3.0.0.1>
-- Description:	<Return list of related database names>
-- Input Parameters:
--	@DatabaseNames:			'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or '<ALL_MIRROR_DATABASES>' or 'dbname1,dbname2,...,dbnameN' also you can use '<EXCLUDE:dbname1,dbname2,...,dbnameN>' and '<INCLUDE:dbname1,dbname2,...,dbnameN>' within only '<ALL_SYSTEM_DATABASES>' , '<ALL_SYSTEM_DATABASES>' and '<ALL_DATABASES>' syntax 
--							Ex:'<ALL_SYSTEM_DATABASES><INCLUDE:AdventureWorks,test1><EXCLUDE:model,distribution>'
--	@Validate:				Validate DatabaseNames existence
--	@ExcludeTempdb:			Exclude tempdb from returned list
--	@ExcludeSnapshots:		Exclude snapshot db's from returned list
--	@ExcludeReadonly:		Exclude read-only db's from returned list
--	@ExcludeAoagReplicas:	Exclude AOAG Replica db's from returned list
-- =============================================
CREATE FUNCTION [dbo].[dbafn_database_list] (
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>'
	,@Validate BIT=1
	,@ExcludeTempdb BIT=1
	,@ExcludeSnapshots BIT=1
	,@ExcludeReadonly BIT=1
	,@ExcludeAoagReplicas BIT=1
	)
RETURNS 
@DatabaseList TABLE ([Name] NVARCHAR(255))
AS
BEGIN
	DECLARE @ListIsGenerated BIT
	DECLARE @StartPoint INT
	DECLARE @EndPoint INT
	DECLARE @ExceptNames NVARCHAR(MAX)
	DECLARE @ProductVersionString NVARCHAR(255)
	DECLARE @ProductVersionNumber INT

	SET @ListIsGenerated=0
	SET @ProductVersionString=CAST(SERVERPROPERTY('productversion') AS NVARCHAR(255))
	SET @ProductVersionNumber = CAST(LEFT(@ProductVersionString,CHARINDEX('.',@ProductVersionString)-1) AS INT)

	--Phase 0: Create Return List
	IF UPPER(@DatabaseNames) LIKE UPPER(N'<ALL_USER_DATABASES>%')
	BEGIN
		SET @ListIsGenerated=1
		INSERT INTO @DatabaseList ([Name]) SELECT CAST([name] as nvarchar(255)) FROM sys.databases WHERE database_id>4 and state <> 6	--Is in normal mode
	END
	
	IF UPPER(@DatabaseNames) LIKE UPPER(N'<ALL_SYSTEM_DATABASES>%')
	BEGIN
		SET @ListIsGenerated=1
		INSERT INTO @DatabaseList ([Name]) SELECT CAST([name] as nvarchar(255)) FROM sys.databases WHERE database_id<=4	--Is in normal mode and its not a snapshot
	END
	
	IF UPPER(@DatabaseNames) LIKE UPPER(N'<ALL_DATABASES>%')
	BEGIN
		SET @ListIsGenerated=1
		INSERT INTO @DatabaseList ([Name]) SELECT CAST([name] as nvarchar(255)) FROM sys.databases WHERE state <> 6
	END

	IF UPPER(@DatabaseNames) LIKE UPPER(N'<ALL_MIRROR_DATABASES>%')
	BEGIN
		SET @ListIsGenerated=1
		INSERT INTO @DatabaseList ([Name]) SELECT CAST(DB_NAME(database_id) as nvarchar(255)) FROM master.sys.database_mirroring WHERE mirroring_role=2	--Mirrored Databases
	END

	IF UPPER(@DatabaseNames) LIKE UPPER(N'%<EXCLUDE:%>%')
	BEGIN
		SET @StartPoint=0
		SET @EndPoint=0
		SET @ExceptNames=N''
		SELECT @StartPoint = CHARINDEX(N'<EXCLUDE:',@DatabaseNames)
		SELECT @EndPoint = CHARINDEX(N'>',RIGHT(@DatabaseNames,LEN(@DatabaseNames)-@StartPoint))
		IF @StartPoint>0 AND @EndPoint>0
		BEGIN
			SET @ExceptNames=REPLACE(SUBSTRING(@DatabaseNames,@StartPoint,@EndPoint),N'<EXCLUDE:',N'')
			DELETE FROM @DatabaseList WHERE [Name] IN (Select Parameter FROM [dbo].dbafn_split(N',',@ExceptNames) as myExclude WHERE LEN(myExclude.Parameter)>0)
		END
	END

	IF UPPER(@DatabaseNames) LIKE UPPER(N'%<INCLUDE:%>%')
	BEGIN
		SET @StartPoint=0
		SET @EndPoint=0
		SET @ExceptNames=N''
		SELECT @StartPoint = CHARINDEX(N'<INCLUDE:',@DatabaseNames)
		SELECT @EndPoint = CHARINDEX(N'>',RIGHT(@DatabaseNames,LEN(@DatabaseNames)-@StartPoint))
		IF @StartPoint>0 AND @EndPoint>0
		BEGIN
			SET @ExceptNames=REPLACE(SUBSTRING(@DatabaseNames,@StartPoint,@EndPoint),N'<INCLUDE:',N'')
			INSERT INTO @DatabaseList 
				SELECT Parameter 
				FROM [dbo].dbafn_split(N',',@ExceptNames) as myInclude 
				WHERE	LEN(myInclude.Parameter)>0 
						AND myInclude.Parameter NOT IN (SELECT [Name] FROM @DatabaseList)
		END
	END

	IF @ListIsGenerated=0
	BEGIN
		INSERT INTO @DatabaseList ([Name]) Select Parameter FROM [dbo].dbafn_split(N',',@DatabaseNames)	
	END
	
	--Phase 1: Filter Returned List
	--Filter only Normal State databases
	IF UPPER(@DatabaseNames) NOT LIKE UPPER(N'<ALL_MIRROR_DATABASES>%')
		DELETE FROM	@DatabaseList WHERE [Name] IN (select CAST(myDbs.[name] collate arabic_ci_as as nvarchar(255)) from sys.databases as myDbs WHERE myDbs.[state]<>0)	--Is not in normal mode

	--Validate databases
	IF @Validate=1
		DELETE FROM	@DatabaseList WHERE [Name] NOT IN (select CAST(myDbs.[name] collate arabic_ci_as as nvarchar(255)) from sys.databases as myDbs)

	--Remove Snapshots
	IF @ExcludeSnapshots=1
		DELETE FROM	@DatabaseList WHERE [Name] IN (select CAST(myDbs.[name] collate arabic_ci_as as nvarchar(255)) from sys.databases as myDbs WHERE myDbs.source_database_id is not null)
		
	--Remove tempdb
	IF @ExcludeTempdb=1
		DELETE FROM	@DatabaseList WHERE [Name] = N'tempdb'

	--Remove Read-only dbs
	IF @ExcludeReadonly=1
		DELETE FROM	@DatabaseList WHERE [Name] in (select CAST(myDbs.[name] collate arabic_ci_as as nvarchar(255)) from sys.databases as myDbs WHERE myDbs.is_read_only=1)
				
	--Remove Secondary AOAG Replica dbs
	IF @ExcludeAoagReplicas=1 AND @ProductVersionNumber>10
		DELETE FROM	@DatabaseList WHERE [Name] in (SELECT CAST([myDatabases].[name] collate arabic_ci_as as nvarchar(255)) FROM [sys].[databases] AS myDatabases INNER JOIN [sys].[dm_hadr_availability_replica_states] AS myReplicaStatus ON [myReplicaStatus].[replica_id] = [myDatabases].[replica_id] WHERE [myReplicaStatus].[role]=2)
	RETURN 
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_database_list', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-02-04', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_database_list', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2023-09-11', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_database_list', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.1', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_database_list', NULL, NULL
GO
