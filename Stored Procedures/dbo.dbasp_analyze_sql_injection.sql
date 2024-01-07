SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <01/07/2024>
-- Version:		<3.0.0.0>
-- Description:	<Return sql injection tryes>
-- Input Parameters:
--	@XeFilePath:	Filepath of XE file(s) in exact full name or wildcard file names, default path is system log directory
--	@FromDate		xe data processing start point in time, default value is Yesterday 00:00:00
--	@ToDate:		xe data processing end point in time, default value is Today 23:59:59
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_analyze_sql_injection](@XeFilePath NVARCHAR(256)=NULL,@FromDate DATETIME=NULL,@ToDate DATETIME=NULL) AS
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

	PRINT CONCAT(N'SQL Injection report from ', @FromDate, N' To ', @ToDate,N' based on ',@XeFilePath, CASE WHEN (@serverVersion < @sqlServer2017Version) THEN N', but SQL version is under MSSQL 2017 and you can not use date filters.' ELSE N'' END)
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
	--Compare Daily Report
	DECLARE @myToday DATE
	SET @myToday=CAST(GETDATE() AS DATE)
	SELECT
		*
	FROM
		(
		SELECT
			myData.ErrorNumber,
			myData.Message,
			myData.DatabaseName,
			myData.ClientAppName,
			(-1*DATEDIFF(DAY,CAST(myData.LogDateTime AS DATE),@myToday)) AS DaysAgo,
			Count(1) AS Occurance
		FROM
			(
			SELECT
				[myXefile].[LogDateTime],
				[xed].[event_data].[value]('(data[@name="error_number"]/value)[1]', 'nvarchar(50)') AS [ErrorNumber],
				[xed].[event_data].[value]('(data[@name="message"]/value)[1]', 'nvarchar(255)') AS [Message],
				[xed].[event_data].[value]('(action[@name="database_name"]/value)[1]', 'nvarchar(255)') AS [DatabaseName],
				[xed].[event_data].[value]('(action[@name="client_app_name"]/value)[1]', 'nvarchar(255)') AS [ClientAppName]
			FROM
				[#myXeTable] AS myXefile
				CROSS APPLY myXefile.[event_data].nodes('/event') AS [xed]([event_data])
			WHERE
				[myXefile].[LogDateTime] BETWEEN @FromDate AND @ToDate
			) AS myData
		GROUP BY
			myData.ErrorNumber,
			myData.Message,
			myData.DatabaseName,
			myData.ClientAppName,
			(-1*DATEDIFF(DAY,CAST(myData.LogDateTime AS DATE),@myToday))
		) AS myRawReport
	PIVOT (
		MAX([Occurance])
		FOR DaysAgo IN ([0],[-1],[-2],[-3],[-4],[-5],[-6],[-7])
	) AS myPivot

	--Detail Report
	SELECT
		--CONVERT(
		--		   DATETIME2,
		--		   SWITCHOFFSET(
		--						   CONVERT(DATETIMEOFFSET, myXefile.[event_data].[value]('(@timestamp)[1]', 'datetime2')),
		--						   DATENAME(TZOFFSET, SYSDATETIMEOFFSET())
		--					   )
		--	   )																			AS [datetime_local]
		[myXefile].[LogDateTime],
		[xed].[event_data].[value]('(data[@name="error_number"]/value)[1]', 'nvarchar(50)') AS [ErrorNumber],
		[xed].[event_data].[value]('(data[@name="category"]/text)[1]', 'nvarchar(50)') AS [Serverity],
		[xed].[event_data].[value]('(data[@name="message"]/value)[1]', 'nvarchar(255)') AS [Message],
		[xed].[event_data].[value]('(action[@name="username"]/value)[1]', 'nvarchar(255)') AS [Username],
		[xed].[event_data].[value]('(action[@name="database_name"]/value)[1]', 'nvarchar(255)') AS [DatabaseName],
		[xed].[event_data].[value]('(action[@name="client_app_name"]/value)[1]', 'nvarchar(255)') AS [ClientAppName],
		[xed].[event_data].[query]('.') AS FullContent
	FROM
		[#myXeTable] AS myXefile
		CROSS APPLY myXefile.[event_data].nodes('/event') AS [xed]([event_data])
	WHERE
		[myXefile].[LogDateTime] BETWEEN @FromDate AND @ToDate
	ORDER BY
		[myXefile].[LogDateTime] DESC
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_sql_injection', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2024-01-07', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_sql_injection', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2024-01-07', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_sql_injection', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_analyze_sql_injection', NULL, NULL
GO
