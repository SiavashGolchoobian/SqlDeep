SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Golchoobian>
-- Create date: <5/9/2023>
-- Version:		<3.0.0.0>
-- Description:	<Log Wait Stats priodically>
-- Input Parameters:
--	@LogRetentionDays:				Any integer number, representing Retantion days of log records
-- Original Script: http://www.sqlskills.com/blogs/paul/wait-statistics-or-please-tell-me-where-it-hurts/
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_waitstat_monitor]
	@LogRetentionDays INT=5
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myLongDurationSecond INT
	DECLARE @myCurrentTime AS DATETIME
	DECLARE @myLogRetentionDays INT
	DECLARE @mySqlServer2014SP2Version DECIMAL(10,5);
	DECLARE @mySqlServer2014SP2BuildVersion NVARCHAR(20);
	DECLARE @mySqlVersion DECIMAL(10,5);
	DECLARE @mySqlBuildVersion NVARCHAR(20);

	SET @mySqlBuildVersion = CAST(SERVERPROPERTY('productversion') AS NVARCHAR(20))
	SET @mySqlVersion = CAST(LEFT(@mySqlBuildVersion,CHARINDEX('.', @mySqlBuildVersion)) AS DECIMAL(10,5))
	SET @mySqlServer2014SP2BuildVersion = '12.0.5000.0'		-- SQL Server 2014 SP2
	SET @mySqlServer2014SP2Version = 12.0					-- SQL Server 2014 SP2
	SET @myLogRetentionDays=@LogRetentionDays
	SET @myCurrentTime=GETDATE()

	-------------------------Create Table if not exists
	IF NOT EXISTS (SELECT 1 FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_NAME]='ActivityLogHistory')
	BEGIN
		CREATE TABLE [trace].[WaitStatsHistory](
			[RecordId] bigint identity primary key,
			[WaitType] [nvarchar](60) NOT NULL,
			[Wait_Sec] [decimal](14, 2) NULL,
			[Resource_Sec] [decimal](14, 2) NULL,
			[Signal_Sec] [decimal](14, 2) NULL,
			[WaitCount] [bigint] NOT NULL,
			[Percentage] [decimal](4, 2) NULL,
			[AvgWait_Sec] [decimal](14, 4) NULL,
			[AvgRes_Sec] [decimal](14, 4) NULL,
			[AvgSig_Sec] [decimal](14, 4) NULL,
			[LogTime] [datetime] NOT NULL,
		) ON [Data_OLTP]
	END;
	-------------------------Fill monitoring table
	WITH [Waits] AS (
		SELECT
			[wait_type],
			[wait_time_ms] / 1000.0								 AS [WaitSec],
			([wait_time_ms] - [signal_wait_time_ms]) / 1000.0	 AS [ResourceSec],
			[signal_wait_time_ms] / 1000.0						 AS [SignalSec],
			[waiting_tasks_count]								 AS [WaitCount],
			100.0 * [wait_time_ms] / SUM([wait_time_ms]) OVER () AS [Percentage]
		FROM
			[sys].[dm_os_wait_stats]
		WHERE [wait_type] NOT IN (
			N'BROKER_EVENTHANDLER',             N'BROKER_RECEIVE_WAITFOR',
			N'BROKER_TASK_STOP',                N'BROKER_TO_FLUSH',
			N'BROKER_TRANSMITTER',              N'CHECKPOINT_QUEUE',
			N'CHKPT',                           N'CLR_AUTO_EVENT',
			N'CLR_MANUAL_EVENT',                N'CLR_SEMAPHORE',
			N'DBMIRROR_DBM_EVENT',              N'DBMIRROR_EVENTS_QUEUE',
			N'DBMIRROR_WORKER_QUEUE',           N'DBMIRRORING_CMD',
			N'DIRTY_PAGE_POLL',                 N'DISPATCHER_QUEUE_SEMAPHORE',
			N'EXECSYNC',                        N'FSAGENT',
			N'FT_IFTS_SCHEDULER_IDLE_WAIT',     N'FT_IFTSHC_MUTEX',
			N'HADR_CLUSAPI_CALL',               N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
			N'HADR_LOGCAPTURE_WAIT',            N'HADR_NOTIFICATION_DEQUEUE',
			N'HADR_TIMER_TASK',                 N'HADR_WORK_QUEUE',
			N'KSOURCE_WAKEUP',                  N'LAZYWRITER_SLEEP',
			N'LOGMGR_QUEUE',                    N'ONDEMAND_TASK_QUEUE',
			N'PWAIT_ALL_COMPONENTS_INITIALIZED',
			N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
			N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
			N'REQUEST_FOR_DEADLOCK_SEARCH',     N'RESOURCE_QUEUE',
			N'SERVER_IDLE_CHECK',               N'SLEEP_BPOOL_FLUSH',
			N'SLEEP_DBSTARTUP',                 N'SLEEP_DCOMSTARTUP',
			N'SLEEP_MASTERDBREADY',             N'SLEEP_MASTERMDREADY',
			N'SLEEP_MASTERUPGRADED',            N'SLEEP_MSDBSTARTUP',
			N'SLEEP_SYSTEMTASK',                N'SLEEP_TASK',
			N'SLEEP_TEMPDBSTARTUP',             N'SNI_HTTP_ACCEPT',
			N'SP_SERVER_DIAGNOSTICS_SLEEP',     N'SQLTRACE_BUFFER_FLUSH',
			N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
			N'SQLTRACE_WAIT_ENTRIES',           N'WAIT_FOR_RESULTS',
			N'WAITFOR',                         N'WAITFOR_TASKSHUTDOWN',
			N'WAIT_XTP_HOST_WAIT',              N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
			N'WAIT_XTP_CKPT_CLOSE',             N'XE_DISPATCHER_JOIN',
			N'XE_DISPATCHER_WAIT',              N'XE_TIMER_EVENT',
			N'SOS_WORK_DISPATCHER')
	)
	INSERT INTO [trace].[WaitStatsHistory] ([WaitType],[Wait_Sec],[Resource_Sec],[Signal_Sec],[WaitCount],[Percentage],[AvgWait_Sec],[AvgRes_Sec],[AvgSig_Sec],[LogTime])
	SELECT
		[W1].[wait_type]											  AS [WaitType],
		CAST([W1].[WaitSec] AS DECIMAL(14, 2))						  AS [Wait_Sec],
		CAST([W1].[ResourceSec] AS DECIMAL(14, 2))					  AS [Resource_Sec],
		CAST([W1].[SignalSec] AS DECIMAL(14, 2))					  AS [Signal_Sec],
		[W1].[WaitCount]											  AS [WaitCount],
		CAST([W1].[Percentage] AS DECIMAL(4, 2))					  AS [Percentage],
		CAST(([W1].[WaitSec] / [W1].[WaitCount]) AS DECIMAL(14, 4))	  AS [AvgWait_Sec],
		CAST(([W1].[ResourceSec] / [W1].[WaitCount]) AS DECIMAL(14, 4)) AS [AvgRes_Sec],
		CAST(([W1].[SignalSec] / [W1].[WaitCount]) AS DECIMAL(14, 4))   AS [AvgSig_Sec],
		@myCurrentTime AS [LogTime]
	FROM
		[Waits]			   AS [W1]
	WHERE
		[W1].[WaitCount]<>0
	GROUP BY
		[W1].[wait_type],
		[W1].[WaitSec],
		[W1].[ResourceSec],
		[W1].[SignalSec],
		[W1].[WaitCount],
		[W1].[Percentage]
	ORDER BY [W1].[WaitSec] DESC
	-------------------------Purging Expired Recors from monitoring table
	SET @myLogRetentionDays=-1*@myLogRetentionDays
	DELETE FROM [trace].[WaitStatsHistory] WHERE [LogTime] < DATEADD(DAY,@myLogRetentionDays,@myCurrentTime)
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_waitstat_monitor', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2023-05-09', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_waitstat_monitor', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2023-05-09', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_waitstat_monitor', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_waitstat_monitor', NULL, NULL
GO
