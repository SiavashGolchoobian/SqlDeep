SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Golchoobian>
-- Create date: <03/28/2020>
-- Version:		<3.0.0.0>
-- Description:	<Return blocking and deadlock stats form xe files>
-- Input Parameters:
--	@XeFilePath:	Filepath of XE file(s) in exact full name or wildcard file names, default path is system log directory
--	@FromDate		xe data processing start point in time, default value is Yesterday 00:00:00
--	@ToDate:		xe data processing end point in time, default value is Today 23:59:59
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_analyze_deadlock_block](@XeFilePath NVARCHAR(256)=NULL,@FromDate DATETIME=NULL,@ToDate DATETIME=NULL) AS
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
	BEGIN
		SELECT @XeFilePath=[myLogPath].[path]+N'system_health_*' FROM sys.dm_os_server_diagnostics_log_configurations AS myLogPath
		IF @XeFilePath IS NULL
			RETURN
	END

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

	PRINT CONCAT(N'Performance report from ', @FromDate, N' To ', @ToDate,N' based on ',@XeFilePath, CASE WHEN (@serverVersion < @sqlServer2017Version) THEN N', but SQL version is under MSSQL 2017 and you can not use date filters.' ELSE N'' END)
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
				@myNewLine+ N'	sys.fn_xe_file_target_read_file(@myXeFilePath, NULL, NULL, NULL) AS myXefile'+
				@myNewLine+ N'	WHERE'+
				@myNewLine+ N'	[myXefile].[object_name] IN (N''xml_deadlock_report'',N''blocked_process_report'')'
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
				@myNewLine+ N'	sys.fn_xe_file_target_read_file(@myXeFilePath, NULL, NULL, NULL) AS myXefile'+
				@myNewLine+ N'	WHERE'+
				@myNewLine+ N'	[myXefile].[object_name] IN (N''xml_deadlock_report'',N''blocked_process_report'')'
				AS NVARCHAR(MAX))
		INSERT INTO [#myXeTable] ([LogDate], [LogDateTime], [CategoryName], [event_data])
		EXECUTE sp_executesql @mySQLScript, @myParmDefinition, @FromDate = @FromDate, @myXeFilePath=@myXeFilePath;
	END

	
	--SELECT TOP 100 * FROM [#myXeTable]
	--=====================================Calculate KPI
	SELECT 
		[myXefile].[LogDate],
		[myXefile].[CategoryName],
		COUNT(1) AS OccurancePerDay
		--CONVERT(XML, event_data),
		--[myXefile].*
	FROM 
		[#myXeTable] AS myXefile
	WHERE
		[myXefile].[LogDateTime] BETWEEN @FromDate AND @ToDate
	GROUP BY
		[myXefile].[LogDate],
		[myXefile].[CategoryName]
	--=====================================Extract Deadlock Parties
	CREATE TABLE #myDeadlockStat (RecordId BIGINT PRIMARY KEY, DeadlockFactors XML,HashValue INT, [event_data] XML)
	INSERT INTO [#myDeadlockStat] ([RecordId], [DeadlockFactors], [HashValue], [event_data])
	SELECT
		[myDeadlockCombination].[RecordId],
		[myDeadlockCombination].[DeadlockFactors],
		BINARY_CHECKSUM(CAST([myDeadlockCombination].[DeadlockFactors] AS NVARCHAR(MAX))) AS HashValue,
		[myDeadlockCombination].[event_data]
	FROM
		(
		SELECT 
			[myXefile].[RecordId],
			[myXefile].[event_data].query('event/data/value/deadlock/process-list/process/inputbuf') AS DeadlockFactors,
			[myXefile].[event_data]
		FROM
			[#myXeTable] AS myXefile
		WHERE
			[myXefile].[LogDateTime] BETWEEN @FromDate AND @ToDate
			AND [myXefile].[CategoryName]=N'xml_deadlock_report'
			AND [myXefile].[event_data].exist('/event[@name="xml_deadlock_report"]/data/value/deadlock/process-list/process/inputbuf')=1 
		) AS myDeadlockCombination

	SELECT 
		[myStat].[HashValue] AS [Id],
		CAST(MAX(CAST([myStat].[DeadlockFactors] AS NVARCHAR(MAX))) AS XML) AS [DeadlockFactors],
		COUNT(1) AS Occurane,
		CAST(MAX(CAST([myStat].[event_data] AS NVARCHAR(MAX))) AS XML) AS SampleXmlData
	FROM 
		#myDeadlockStat AS myStat
	GROUP BY
		[myStat].[HashValue]
	ORDER BY
		Occurane DESC
	--=====================================Extract Block Parties
	CREATE TABLE #myBlockStat (RecordId BIGINT PRIMARY KEY, BlockFactors XML,HashValue INT, Duration BIGINT, [event_data] XML)
	INSERT INTO [#myBlockStat] ([RecordId], [BlockFactors], [HashValue],[Duration],[event_data])
	SELECT
		[myBlockCombination].[RecordId],
		[myBlockCombination].[BlockFactors],
		BINARY_CHECKSUM(CAST([myBlockCombination].[BlockFactors] AS NVARCHAR(MAX))) AS HashValue,
		[myBlockCombination].[Duration],
		[myBlockCombination].[event_data]
	FROM
		(
		SELECT 
			[myXefile].[RecordId],
			CAST(CONCAT(CAST([myXefile].[event_data].query('event/data/value/blocked-process-report/blocked-process/process/inputbuf') AS NVARCHAR(MAX)), CAST([myXefile].[event_data].query('event/data/value/blocked-process-report/blocking-process/process/inputbuf') AS NVARCHAR(MAX))) AS XML) AS BlockFactors,
			[myXefile].[event_data].value('(/event/data[@name="duration"]/value)[1]','bigint') AS Duration,
			[myXefile].[event_data]
		FROM
			[#myXeTable] AS myXefile
		WHERE
			[myXefile].[LogDateTime] BETWEEN @FromDate AND @ToDate
			AND [myXefile].[CategoryName]=N'blocked_process_report'
			AND [myXefile].[event_data].exist('/event[@name="blocked_process_report"]/data[@name="blocked_process"]/value')=1 
			--/blocked-process-report/blocked-process/process/inputbuf
		) AS myBlockCombination

	SELECT 
		[myStat].[HashValue] AS [Id],
		CAST(MAX(CAST([myStat].[BlockFactors] AS NVARCHAR(MAX))) AS XML) AS [BlockFactors],
		COUNT(1) AS Occurane,
		SUM([myStat].[Duration])/1000 AS TotalDuration_ms,
		AVG([myStat].[Duration])/1000 AS AverageDuration_ms,
		CAST(MAX(CAST([myStat].[event_data] AS NVARCHAR(MAX))) AS XML) AS SampleXmlData
	FROM 
		#myBlockStat AS myStat
	GROUP BY
		[myStat].[HashValue]
	ORDER BY
		TotalDuration_ms DESC,
		Occurane DESC
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_deadlock_block', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-04-09', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_deadlock_block', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2020-04-09', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_deadlock_block', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_deadlock_block', NULL, NULL
GO
