SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <03/28/2020>
-- Version:		<3.0.0.0>
-- Description:	<Return long running queries stats form xe files>
-- Input Parameters:
--	@XeFilePath:	Filepath of XE file(s) in exact full name or wildcard file names, default path is system log directory
--	@FromDate		xe data processing start point in time, default value is Yesterday 00:00:00
--	@ToDate:		xe data processing end point in time, default value is Today 23:59:59
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_analyze_long_running_queries](@XeFilePath NVARCHAR(256)=NULL,@FromDate DATETIME=NULL,@ToDate DATETIME=NULL) AS
BEGIN
	CREATE TABLE #myXeTable (RecordId BIGINT IDENTITY PRIMARY KEY, LogDate DATE, LogDateTime DATETIME,CategoryName NVARCHAR(60), event_data XML)
	DECLARE @myXeFilePath AS NVARCHAR(256)
	DECLARE @myLocalDateTime AS DATETIME
	DECLARE @myUTCDateTime AS DATETIME
	DECLARE @myLocalDiffToUTC INT
	DECLARE @versionString NVARCHAR(20);
	DECLARE @serverVersion DECIMAL(10,5);
	DECLARE @sqlServer2017Version DECIMAL(10,5);
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myParmDefinition nvarchar(500);
	DECLARE @myNewLine nvarchar(10);

	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @versionString = CAST(SERVERPROPERTY('productversion') AS NVARCHAR(20))
	SET @serverVersion = CAST(LEFT(@versionString,CHARINDEX('.', @versionString)) AS DECIMAL(10,5))
	SET @sqlServer2017Version = 14.0 -- SQL Server 2017

	--Validate filepath conditions
	IF @XeFilePath IS NULL
		RETURN

	--Validate date conditions
	IF(@serverVersion >= @sqlServer2017Version)
	BEGIN
		IF @FromDate IS NULL
			SET @FromDate = CAST(DATEADD(DAY,-1,CAST(GETDATE() AS DATE)) AS DATETIME)
		IF @ToDate IS NULL
			SET @ToDate = DATEADD(SECOND,-1,CAST(DATEADD(DAY,1,CAST(GETDATE() AS DATE)) AS DATETIME))
	END
	ELSE
	BEGIN
		SET @FromDate=GETDATE()
		SET @ToDate=@FromDate
	END

	PRINT CONCAT(N'Contention report from ', @FromDate, N' To ', @ToDate,N' based on ',@XeFilePath, CASE WHEN (@serverVersion < @sqlServer2017Version) THEN N', but SQL version is under MSSQL 2017 and you can not use date filters.' ELSE N'' END)
	SET @myXeFilePath= @XeFilePath
	SET @myUTCDateTime=GETUTCDATE()
	SET @myLocalDateTime=GETDATE()
	SET @myLocalDiffToUTC = DATEDIFF(MINUTE,@myUTCDateTime,@myLocalDateTime)
	SET @mySQLScript = CAST(N'' AS NVARCHAR(MAX))
	IF(@serverVersion >= @sqlServer2017Version)
	BEGIN
		SET @myParmDefinition = N'@myLocalDiffToUTC INT, @myXeFilePath AS NVARCHAR(256)'
		SET @mySQLScript=@mySQLScript+
			CAST(
				@myNewLine+ N'SELECT'+
				@myNewLine+ N'	CAST(DATEADD(MINUTE,@myLocalDiffToUTC,[myXefile].[timestamp_utc]) AS DATE) AS LogDate,'+
				@myNewLine+ N'	DATEADD(MINUTE,@myLocalDiffToUTC,[myXefile].[timestamp_utc]) AS LogDateTime,'+
				@myNewLine+ N'	[myXefile].[object_name] AS CategoryName,'+
				@myNewLine+ N'	CONVERT(XML, event_data) AS event_data'+
				@myNewLine+ N'FROM '+
				@myNewLine+ N'	sys.fn_xe_file_target_read_file(@myXeFilePath, NULL, NULL, NULL) AS myXefile'
				AS NVARCHAR(MAX))
		INSERT INTO [#myXeTable] ([LogDate], [LogDateTime], [CategoryName], [event_data])
		EXECUTE sp_executesql @mySQLScript, @myParmDefinition, @myLocalDiffToUTC = @myLocalDiffToUTC, @myXeFilePath=@myXeFilePath;
	END
	ELSE
	BEGIN
		SET @myParmDefinition = N'@FromDate DateTime, @myXeFilePath AS NVARCHAR(256)'
		SET @mySQLScript=@mySQLScript+
			CAST(
				@myNewLine+ N'SELECT'+
				@myNewLine+ N'	CAST(@FromDate AS DATE) AS LogDate,'+
				@myNewLine+ N'	@FromDate AS LogDateTime,'+
				@myNewLine+ N'	[myXefile].[object_name] AS CategoryName,'+
				@myNewLine+ N'	CONVERT(XML, event_data) AS event_data'+
				@myNewLine+ N'FROM '+
				@myNewLine+ N'	sys.fn_xe_file_target_read_file(@myXeFilePath, NULL, NULL, NULL) AS myXefile'
				AS NVARCHAR(MAX))
		INSERT INTO [#myXeTable] ([LogDate], [LogDateTime], [CategoryName], [event_data])
		EXECUTE sp_executesql @mySQLScript, @myParmDefinition, @FromDate = @FromDate, @myXeFilePath=@myXeFilePath;
	END

	--SELECT TOP 100 * FROM [#myXeTable]
	--=====================================Extract Contentions
	SELECT
		--CONVERT(
		--		   DATETIME2,
		--		   SWITCHOFFSET(
		--						   CONVERT(DATETIMEOFFSET, myXefile.[event_data].[value]('(@timestamp)[1]', 'datetime2')),
		--						   DATENAME(TZOFFSET, SYSDATETIMEOFFSET())
		--					   )
		--	   )																			AS [datetime_local]
		[myXefile].[LogDateTime],
		CONVERT (FLOAT,[xed].[event_data].[value]('(data[@name="duration"]/value)[1]', 'BIGINT')) / 1000000 AS [Duration (s)],
		CONVERT (FLOAT,[xed].[event_data].[value]('(data[@name="cpu_time"]/value)[1]', 'BIGINT')) / 1000000 AS [CPU Time (s)],
		[xed].[event_data].[value]('(data[@name="physical_reads"]/value)[1]', 'INT') AS [Physical Reads (# page Reads)],
		[xed].[event_data].[value]('(data[@name="logical_reads"]/value)[1]', 'INT') AS [Logical Reads (# page Reads)],
		[xed].[event_data].[value]('(data[@name="writes"]/value)[1]', 'INT') AS [Writes (# Page writes)],
		[xed].[event_data].[value]('(action[@name="database_id"]/value)[1]', 'INT') AS [Database Id],
		[xed].[event_data].[value]('(action[@name="statement"]/value)[1]', 'NVARCHAR(MAX)') AS [Statement],
		[xed].[event_data].[value]('(action[@name="session_id"]/value)[1]', 'INT') AS [Session Id],
		[xed].[event_data].[value]('(action[@name="session_nt_username"]/value)[1]', 'NVARCHAR(MAX)') AS [User Name],
		[xed].[event_data].[value]('(action[@name="sql_text"]/value)[1]', 'NVARCHAR(MAX)') AS [SQL Statement],
		[xed].[event_data].[value]('(action[@name="client_hostname"]/value)[1]', 'NVARCHAR(MAX)') AS [Client Host Name],
		[xed].[event_data].[value]('(action[@name="client_app_name"]/value)[1]', 'NVARCHAR(MAX)') AS [Client App Name],
		[xed].[event_data].[value]('(action[@name="plan_handle"]/value)[1]', 'NVARCHAR(MAX)') AS [Plan Handle]
	FROM
		[#myXeTable] AS myXefile
		CROSS APPLY myXefile.[event_data].nodes('/event') AS [xed]([event_data])
	WHERE
		[myXefile].[LogDateTime] BETWEEN @FromDate AND @ToDate
	ORDER BY
		[Duration (s)] DESC
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_long_running_queries', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2022-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_long_running_queries', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2022-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_long_running_queries', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_long_running_queries', NULL, NULL
GO
