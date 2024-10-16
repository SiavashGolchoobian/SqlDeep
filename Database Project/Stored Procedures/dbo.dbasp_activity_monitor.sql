SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <5/26/2017>
-- Version:		<3.0.0.3>
-- Description:	<Log informations about sessions that not in SLEEPING mode and duration over than @GrabTransactionsOver_Second after Request [start_time]>
-- Input Parameters:
--	@GrabTransactionsOver_Second:	Any integer number, representing Seconds between Current time and Request Start time
--	@LogRetentionDays:				Any integer number, representing Retantion days of log records
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_activity_monitor]
	@GrabTransactionsOver_Second INT=10,
	@LogRetentionDays INT=5
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myLongDurationSecond INT
	DECLARE @myCurrentTime AS DATETIME
	DECLARE @myLogRetentionDays INT
	DECLARE @mySqlServer2014SP2Version DECIMAL(10,5);
	DECLARE @mySqlServer2014SP2BuildVersion NVARCHAR(20);
	DECLARE @myIsSql2014SP2BuggyVersion BIT;
	DECLARE @mySqlVersion DECIMAL(10,5);
	DECLARE @mySqlBuildVersion NVARCHAR(20);

	SET @mySqlBuildVersion = CAST(SERVERPROPERTY('productversion') AS NVARCHAR(20))
	SET @mySqlVersion = CAST(LEFT(@mySqlBuildVersion,CHARINDEX('.', @mySqlBuildVersion)) AS DECIMAL(10,5))
	SET @mySqlServer2014SP2BuildVersion = '12.0.5000.0'		-- SQL Server 2014 SP2
	SET @mySqlServer2014SP2Version = 12.0					-- SQL Server 2014 SP2
	SET @myIsSql2014SP2BuggyVersion = 0
	SET @myLongDurationSecond=@GrabTransactionsOver_Second
	SET @myLogRetentionDays=@LogRetentionDays
	SET @myCurrentTime=GETDATE()

	-------------------------Check for buggy version of SQL Server 2014 SP2 or over
	IF NOT EXISTS (SELECT 1 FROM [master].[sys].[all_objects] WHERE [name]=N'dm_exec_input_buffer' AND [type]=N'IF')
		SET @myIsSql2014SP2BuggyVersion = 1

	-------------------------Create Table if not exists
	IF NOT EXISTS (SELECT 1 FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_NAME]='ActivityLogHistory')
	BEGIN
		CREATE TABLE [trace].[ActivityLogHistory](
		[RecordId] BIGINT IDENTITY NOT NULL PRIMARY KEY,
		[session_id] [SMALLINT] NULL,
		[RequestStartTime] [DATETIME] NOT NULL,
		[RequestStatus] [NVARCHAR](30) NULL,
		[command] [NVARCHAR](32) NULL,
		[DBname] [NVARCHAR](128) NULL,
		[wait_resource] [NVARCHAR](256) NULL,
		[cpu_time_ms] [INT] NULL,
		[total_elapsed_time] [INT] NULL,
		[reads_KB] [BIGINT] NULL,
		[writes_KB] [BIGINT] NULL,
		[logical_reads_KB] [BIGINT] NULL,
		[memory_usage_KB] [INT] NULL,
		[memory_request_time] [DATETIME] NULL,
		[memory_grant_time] [DATETIME] NULL,
		[requested_memory_kb] [BIGINT] NULL,
		[min_required_memory_kb] [BIGINT] NULL,
		[granted_memory_kb] [BIGINT] NULL,
		[used_memory_kb] [BIGINT] NULL,
		[max_used_memory_kb] [BIGINT] NULL,
		[oreder_of_query_in_wait_memory_queue] [INT] NULL,
		[memory_wait_time_ms] [BIGINT] NULL,
		[use_small_memory] [BIT] NULL,
		[dop] [SMALLINT] NULL,
		[query_cost] [FLOAT] NULL,
		[login_time] [DATETIME] NOT NULL,
		[host_name] [NVARCHAR](128) NULL,
		[program_name] [NVARCHAR](128) NULL,
		[client_interface_name] [NVARCHAR](32) NULL,
		[login_name] [NVARCHAR](128) NOT NULL,
		[SessionStatus] [NVARCHAR](30) NOT NULL,
		[objectid] [INT] NULL,
		[CurrentSessionStatement] [NVARCHAR](MAX) NULL,
		[CurrentRequestStatement] [NVARCHAR](MAX) NULL,
		[CurrentRequestSectionStatement] [NVARCHAR](MAX) NULL,
		[CurrentRequestPlan] [XML] NULL,
		[CurrentRequestSectionPlan] [XML] NULL,
		[wait_duration_ms] [BIGINT] NULL,
		[wait_type] [NVARCHAR](60) NULL,
		[resource_address] [VARBINARY](8) NULL,
		[blocking_session_id] [SMALLINT] NULL,
		[resource_description] [NVARCHAR](3072) NULL,
		[HeadBlocker] [BIT] NULL,
		[client_net_address NVARCHAR(50) NULL,
		[LogTime] [DATETIME] NULL DEFAULT (GETDATE())
		) ON [Data_OLTP] TEXTIMAGE_ON [Data_OLTP]   --[PRIMARY] TEXTIMAGE_ON [PRIMARY]
		CREATE NONCLUSTERED INDEX NCIX_RequestStartTime ON [trace].[ActivityLogHistory] ([RequestStartTime]) WITH (PAD_INDEX=ON,FILLFACTOR=90,SORT_IN_TEMPDB=ON,DATA_COMPRESSION=PAGE) ON [Index_All]
	END

	-------------------------Fill monitoring table
	IF @mySqlVersion >= @mySqlServer2014SP2Version AND @mySqlBuildVersion >= @mySqlServer2014SP2BuildVersion AND @myIsSql2014SP2BuggyVersion = 0
	BEGIN	--For SQL Servers Equal and Above 2014 SP2
		INSERT INTO [trace].[ActivityLogHistory]
			([session_id],
			 [RequestStartTime],
			 [RequestStatus],
			 [command],
			 [DBname],
			 [wait_resource],
			 [cpu_time_ms],
			 [total_elapsed_time],
			 [reads_KB],
			 [writes_KB],
			 [logical_reads_KB],
			 [memory_usage_KB],
			 [memory_request_time],
			 [memory_grant_time],
			 [requested_memory_kb],
			 [min_required_memory_kb],
			 [granted_memory_kb],
			 [used_memory_kb],
			 [max_used_memory_kb],
			 [oreder_of_query_in_wait_memory_queue],
			 [memory_wait_time_ms],
			 [use_small_memory],
			 [dop],
			 [query_cost],
			 [login_time],
			 [host_name],
			 [program_name],
			 [client_interface_name],
			 [login_name],
			 [SessionStatus],
			 [objectid],
			 [CurrentSessionStatement],
			 [CurrentRequestStatement],
			 [CurrentRequestSectionStatement],
			 [CurrentRequestPlan],
			 [CurrentRequestSectionPlan],
			 [wait_duration_ms],
			 [wait_type],
			 [resource_address],
			 [blocking_session_id],
			 [resource_description],
			 [HeadBlocker],
			 [client_net_address],
			 [LogTime])
		SELECT
			[mySession].[session_id],
			[myRequest].[start_time] AS RequestStartTime,
			[myRequest].[status] AS RequestStatus,
			[myRequest].[command],
			DB_NAME([myRequest].[database_id]) AS DBname,
			--[myRequest].[wait_type],
			--[myRequest].[wait_time],
			[myRequest].[wait_resource],
			[myRequest].[cpu_time] AS [cpu_time_ms],
			[myRequest].[total_elapsed_time],
			[myRequest].[reads] * 8 AS [reads_KB],
			[myRequest].[writes] * 8 AS [writes_KB],
			[myRequest].[logical_reads] * 8 AS [logical_reads_KB],
			[mySession].[memory_usage] * 8 AS [memory_usage_KB],
			[myMemory].[request_time] AS [memory_request_time],
			[myMemory].[grant_time] AS [memory_grant_time],
			[myMemory].[requested_memory_kb],
			[myMemory].[required_memory_kb] AS [min_required_memory_kb],
			[myMemory].[granted_memory_kb],
			[myMemory].[used_memory_kb],
			[myMemory].[max_used_memory_kb],
			[myMemory].[wait_order] AS [oreder_of_query_in_wait_memory_queue],
			[myMemory].[wait_time_ms] AS [memory_wait_time_ms],
			[myMemory].[is_small] AS [use_small_memory],
			[myMemory].[dop],
			[myMemory].[query_cost],
			[mySession].[login_time],
			[mySession].[host_name],
			[mySession].[program_name],
			[mySession].[client_interface_name],
			[mySession].[login_name],
			[mySession].[status] AS SessionStatus,
			[myPlan].[objectid],
			[myBuffer].[event_info] AS CurrentSessionStatement,	----SQL2014SP2 above
			[mySQL].[text] AS CurrentRequestStatement,
			SUBSTRING(
						[mySQL].[text],
						([myRequest].[statement_start_offset]/2)+1,
						(
							(CASE [myRequest].[statement_end_offset]
								WHEN -1 THEN DATALENGTH([mySQL].[text])
								ELSE [myRequest].[statement_end_offset]
							 END - [myRequest].[statement_start_offset]
							 )/2) + 1
					) AS CurrentRequestSectionStatement,
			[myPlan].[query_plan] AS CurrentRequestPlan,
			CONVERT(XML,[myCurrentExecutionPartOfStatementPlan].[query_plan]) AS CurrentRequestSectionPlan,
			[myWaitingTasks].[wait_duration_ms],
			[myWaitingTasks].[wait_type],
			[myWaitingTasks].[resource_address],
			[myWaitingTasks].[blocking_session_id],
			[myWaitingTasks].[resource_description],
			CASE
				-- session has an active request, is blocked, but is blocking others or session is idle but has an open tran and is blocking others
				WHEN myHeadOfBlockRequest.session_id IS NOT NULL AND ([myRequest].blocking_session_id = 0 OR [myRequest].session_id IS NULL) THEN CAST(1 AS BIT)
				-- session is either not blocking someone, or is blocking someone but is blocked by another party
				ELSE NULL
			END AS [HeadBlocker],
			[myConnections].[client_net_address],
			GETDATE()
		FROM
			sys.[dm_exec_sessions] AS mySession
			INNER JOIN sys.[dm_exec_connections] AS myConnections ON mySession.session_id = myConnections.session_id
			LEFT OUTER JOIN sys.[dm_exec_requests] AS myRequest ON myRequest.[session_id]=[mySession].[session_id]
			LEFT OUTER JOIN sys.[dm_os_waiting_tasks] AS myWaitingTasks ON [mySession].[session_id]=[myWaitingTasks].[session_id]
			LEFT OUTER JOIN sys.[dm_exec_requests] AS myHeadOfBlockRequest ON [mySession].[session_id]=[myHeadOfBlockRequest].[blocking_session_id]
			LEFT OUTER JOIN sys.[dm_exec_query_memory_grants] AS myMemory ON [myMemory].[session_id] = [myRequest].[session_id] AND [myMemory].[request_id] = [myRequest].[request_id]
			CROSS APPLY sys.[dm_exec_query_plan]([myRequest].[plan_handle]) AS myPlan
			CROSS APPLY SYS.[dm_exec_sql_text]([myRequest].[sql_handle]) AS mySQL
			OUTER APPLY sys.[dm_exec_text_query_plan]([myRequest].[plan_handle], [myRequest].[statement_start_offset], [myRequest].[statement_end_offset]) AS myCurrentExecutionPartOfStatementPlan
			OUTER APPLY sys.dm_exec_input_buffer(mySession.session_id, [myRequest].[request_id]) AS myBuffer	--SQL2014SP2 above
		WHERE
			[mySession].[is_user_process]=1
			AND [mySession].[status] != 'sleeping'
			AND DATEDIFF(SECOND,myRequest.[start_time],@myCurrentTime)>=@myLongDurationSecond
	END
	ELSE
	BEGIN	--For SQL Servers Below 2014 SP2
		INSERT INTO [trace].[ActivityLogHistory]
			([session_id],
			 [RequestStartTime],
			 [RequestStatus],
			 [command],
			 [DBname],
			 [wait_resource],
			 [cpu_time_ms],
			 [total_elapsed_time],
			 [reads_KB],
			 [writes_KB],
			 [logical_reads_KB],
			 [memory_usage_KB],
			 [memory_request_time],
			 [memory_grant_time],
			 [requested_memory_kb],
			 [min_required_memory_kb],
			 [granted_memory_kb],
			 [used_memory_kb],
			 [max_used_memory_kb],
			 [oreder_of_query_in_wait_memory_queue],
			 [memory_wait_time_ms],
			 [use_small_memory],
			 [dop],
			 [query_cost],
			 [login_time],
			 [host_name],
			 [program_name],
			 [client_interface_name],
			 [login_name],
			 [SessionStatus],
			 [objectid],
			 [CurrentSessionStatement],
			 [CurrentRequestStatement],
			 [CurrentRequestSectionStatement],
			 [CurrentRequestPlan],
			 [CurrentRequestSectionPlan],
			 [wait_duration_ms],
			 [wait_type],
			 [resource_address],
			 [blocking_session_id],
			 [resource_description],
			 [HeadBlocker],
			 [client_net_address],
			 [LogTime])
		SELECT
			[mySession].[session_id],
			[myRequest].[start_time] AS RequestStartTime,
			[myRequest].[status] AS RequestStatus,
			[myRequest].[command],
			DB_NAME([myRequest].[database_id]) AS DBname,
			--[myRequest].[wait_type],
			--[myRequest].[wait_time],
			[myRequest].[wait_resource],
			[myRequest].[cpu_time] AS [cpu_time_ms],
			[myRequest].[total_elapsed_time],
			[myRequest].[reads] * 8 AS [reads_KB],
			[myRequest].[writes] * 8 AS [writes_KB],
			[myRequest].[logical_reads] * 8 AS [logical_reads_KB],
			[mySession].[memory_usage] * 8 AS [memory_usage_KB],
			[myMemory].[request_time] AS [memory_request_time],
			[myMemory].[grant_time] AS [memory_grant_time],
			[myMemory].[requested_memory_kb],
			[myMemory].[required_memory_kb] AS [min_required_memory_kb],
			[myMemory].[granted_memory_kb],
			[myMemory].[used_memory_kb],
			[myMemory].[max_used_memory_kb],
			[myMemory].[wait_order] AS [oreder_of_query_in_wait_memory_queue],
			[myMemory].[wait_time_ms] AS [memory_wait_time_ms],
			[myMemory].[is_small] AS [use_small_memory],
			[myMemory].[dop],
			[myMemory].[query_cost],
			[mySession].[login_time],
			[mySession].[host_name],
			[mySession].[program_name],
			[mySession].[client_interface_name],
			[mySession].[login_name],
			[mySession].[status] AS SessionStatus,
			[myPlan].[objectid],
			NULL AS CurrentSessionStatement,	----SQL2014SP2 above
			[mySQL].[text] AS CurrentRequestStatement,
			SUBSTRING(
						[mySQL].[text],
						([myRequest].[statement_start_offset]/2)+1,
						(
							(CASE [myRequest].[statement_end_offset]
								WHEN -1 THEN DATALENGTH([mySQL].[text])
								ELSE [myRequest].[statement_end_offset]
							 END - [myRequest].[statement_start_offset]
							 )/2) + 1
					) AS CurrentRequestSectionStatement,
			[myPlan].[query_plan] AS CurrentRequestPlan,
			CONVERT(XML,[myCurrentExecutionPartOfStatementPlan].[query_plan]) AS CurrentRequestSectionPlan,
			[myWaitingTasks].[wait_duration_ms],
			[myWaitingTasks].[wait_type],
			[myWaitingTasks].[resource_address],
			[myWaitingTasks].[blocking_session_id],
			[myWaitingTasks].[resource_description],
			CASE
				-- session has an active request, is blocked, but is blocking others or session is idle but has an open tran and is blocking others
				WHEN myHeadOfBlockRequest.session_id IS NOT NULL AND ([myRequest].blocking_session_id = 0 OR [myRequest].session_id IS NULL) THEN CAST(1 AS BIT)
				-- session is either not blocking someone, or is blocking someone but is blocked by another party
				ELSE NULL
			END AS [HeadBlocker],
			[myConnections].[client_net_address],
			GETDATE()
		FROM
			sys.[dm_exec_sessions] AS mySession
			INNER JOIN sys.[dm_exec_connections] AS myConnections ON mySession.session_id = myConnections.session_id
			LEFT OUTER JOIN sys.[dm_exec_requests] AS myRequest ON myRequest.[session_id]=[mySession].[session_id]
			LEFT OUTER JOIN sys.[dm_os_waiting_tasks] AS myWaitingTasks ON [mySession].[session_id]=[myWaitingTasks].[session_id]
			LEFT OUTER JOIN sys.[dm_exec_requests] AS myHeadOfBlockRequest ON [mySession].[session_id]=[myHeadOfBlockRequest].[blocking_session_id]
			LEFT OUTER JOIN sys.[dm_exec_query_memory_grants] AS myMemory ON [myMemory].[session_id] = [myRequest].[session_id] AND [myMemory].[request_id] = [myRequest].[request_id]
			CROSS APPLY sys.[dm_exec_query_plan]([myRequest].[plan_handle]) AS myPlan
			CROSS APPLY SYS.[dm_exec_sql_text]([myRequest].[sql_handle]) AS mySQL
			OUTER APPLY sys.[dm_exec_text_query_plan]([myRequest].[plan_handle], [myRequest].[statement_start_offset], [myRequest].[statement_end_offset]) AS myCurrentExecutionPartOfStatementPlan
		WHERE
			[mySession].[is_user_process]=1
			AND [mySession].[status] != 'sleeping'
			AND DATEDIFF(SECOND,myRequest.[start_time],@myCurrentTime)>=@myLongDurationSecond
	END

	-------------------------Purging Expired Recors from monitoring table
	SET @myLogRetentionDays=-1*@myLogRetentionDays
	DELETE FROM [trace].[ActivityLogHistory] WHERE [RequestStartTime] < DATEADD(DAY,@myLogRetentionDays,@myCurrentTime)
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_activity_monitor] TO [role_perfmon_collector]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_activity_monitor', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-05-13', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_activity_monitor', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-05-26', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_activity_monitor', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.2', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_activity_monitor', NULL, NULL
GO
