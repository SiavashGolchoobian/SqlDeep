SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Fatemeh Moniri
-- Create date: 2024-08-11
-- @AcceptedLatencyHour Setting the unsynchronized houre
-- Description:	Show Disaster Result for Eventlog Database
-- =============================================

CREATE PROCEDURE [repository].[dbasp_get_disaster_events_alert] (@AcceptedLatencyHour INT) AS
BEGIN
	DECLARE @myCounter INT;
	DECLARE @myDate AS DATETIME;
	DECLARE @myMinDate AS DATE;
	DECLARE @myPattern NVARCHAR(8)
	--DECLARE @myAcceptedLatencyHour INT = -2;
	SET @myDate = GETDATE();
	SET @myCounter = 0;
	SET @myMinDate = GETDATE();
	SET @myPattern = '%' + N'_'+CAST(FORMAT(@myDate,'yyyy','fa') AS NVARCHAR(4))+N'_'+ '%'

	CREATE TABLE #myErrorLogInfo
	(
		[Id] INT IDENTITY PRIMARY KEY NOT NULL,
		[LogDate] VARCHAR(100),
		[Processinfo] VARCHAR(200),
		[Text] VARCHAR(MAX)
	);

	WHILE CAST(@myDate AS DATE) = @myMinDate
	BEGIN
		INSERT INTO #myErrorLogInfo (LogDate,Processinfo,[Text])
		EXEC sys.xp_readerrorlog @myCounter;
		SELECT @myMinDate = MIN(CAST([LogDate] AS DATE))
		FROM #myErrorLogInfo;
		SET @myCounter = @myCounter + 1;
	END;

	
DELETE  FROM #myErrorLogInfo  WHERE  [Processinfo] NOT LIKE N'Backup' OR [text] NOT LIKE 'Log was restored.%';

	SELECT
		@@SERVERNAME As [EventSource], 'DisasterLatencies'AS [Module], @myDate AS [EventTimeStamp], 'WRN' AS [Serverity] , CONCAT('Number of unsynced databases are: ',COUNT(1))  AS [Description],
		CASE WHEN ISNULL(COUNT(1),0)>0  THEN  1 
		ELSE 0
		END AS [IsSMS]
	FROM
	(
		SELECT [myDatabases].[name] AS [DatabaseName],
			   [myLogResult].[RestorDate],
			   [myLogResult].[RestorAddress],
			   [myLogResult].[LogDate]
		FROM [sys].[databases] AS myDatabases
			LEFT OUTER JOIN
			(
				SELECT [myResult].[DatabaseName],
					   [myResult].[RestorDate],
					   [myResult].[RestorAddress],
					   [myResult].[LogDate]
				FROM
				(
					SELECT [myErrorLogData].[DatabaseName],
						   [myErrorLogData].[RestorAddress],
						   [myErrorLogData].[RestorDate],
						   [myErrorLogData].[LogDate],
						   ROW_NUMBER() OVER (PARTITION BY [myErrorLogData].[DatabaseName]
											  ORDER BY [myErrorLogData].[LogDate] DESC
											 ) AS RowNumber
					FROM
					(
						SELECT [myError].Id,
							   CAST([myError].[LogDate] AS SMALLDATETIME) AS [LogDate],
							   LTRIM(RTRIM(SUBSTRING(
												 [myError].[Text],
												 PATINDEX('%:%', [myError].[Text]) + 1,
												 ((PATINDEX('%,%', [myError].[Text]) - PATINDEX('%:%', [myError].[Text])
												   - 1
												  )
												 )
											 )
								   )) AS [DatabaseName],
							   SUBSTRING(
											[myError].[Text],
											PATINDEX('%{%', [myError].[Text]),
											((PATINDEX('%}%', [myError].[Text]) - PATINDEX('%{%', [myError].[Text])))
										) AS [RestorAddress],
								SUBSTRING([myError].[Text] ,PATINDEX(@myPattern,[myError].[TEXT])+1,(10)) As [RestorDate]
						FROM #myErrorLogInfo AS myError
						WHERE [myError].[LogDate]
							  BETWEEN DATEADD(DAY, -2, @myDate) AND @myDate
					) AS myErrorLogData
					WHERE LEN([myErrorLogData].[DatabaseName]) <> 0
				) AS myResult
				WHERE [myResult].[RowNumber] = 1
			) AS myLogResult
				ON myDatabases.[name] = [myLogResult].[DatabaseName]
		WHERE [myDatabases].[database_id] > 4
			  AND [myDatabases].[name] NOT IN ( 'SqlDeep' )
			  AND
			  (
				  [myLogResult].[LogDate] < DATEADD(HOUR, @AcceptedLatencyHour, @myDate)
				  OR [myLogResult].[LogDate] IS NULL
			  )
	) AS myFilterResult;
	
	DROP TABLE #myErrorLogInfo
END
GO
GRANT EXECUTE ON  [repository].[dbasp_get_disaster_events_alert] TO [role_disaster]
GO
EXEC sp_addextendedproperty N'Author', N'Fatemeh Moniri', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_get_disaster_events_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2024-08-11', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_get_disaster_events_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2024-08-11', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_get_disaster_events_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'1.0.0.0', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_get_disaster_events_alert', NULL, NULL
GO
