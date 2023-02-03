--Investigating the long runing querires over 2 Sec
CREATE EVENT SESSION [SqlDeep_Capture_LongRunningQueries] ON SERVER 
ADD EVENT sqlserver.sql_statement_completed
    (ACTION (sqlserver.client_app_name, sqlserver.client_hostname,sqlserver.database_id, sqlserver.session_nt_username,sqlserver.session_id, sqlserver.sql_text,sqlserver.plan_handle)
     WHERE (
			duration > 2000000	--2000 milliseconds in microseconds
			AND sql_text NOT LIKE 'WAITFOR (RECEIVE message_body FROM WMIEventProviderNotificationQueue)%' /* Exclude WMI waits */
			)
    )
ADD TARGET package0.event_file(SET filename=N'U:\Databases\SqlDeep_Capture_LongRunningQueries.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=3 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_NODE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

ALTER EVENT SESSION [SqlDeep_Capture_LongRunningQueries] ON SERVER STATE = START;
GO

--References
--https://moderndba.com/2015/04/09/sql-server-slow-query-log-using-extended-events/