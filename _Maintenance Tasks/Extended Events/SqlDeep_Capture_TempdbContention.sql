--Investigating the causes of Latch contention for queries that get held up for more 20 microseconds
CREATE EVENT SESSION [SqlDeep_Capture_TempdbContention] ON SERVER 
ADD EVENT sqlserver.latch_suspend_end
    (ACTION (sqlserver.client_app_name, sqlserver.client_hostname,sqlserver.database_id, sqlserver.session_nt_username,sqlserver.session_id, sqlserver.sql_text)
     WHERE (package0.greater_than_uint64(duration, (20)) AND database_id = (2))
    )
ADD TARGET package0.event_file(SET filename=N'U:\Databases\Audit\SqlDeep_Capture_TempdbContention.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=3 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_NODE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

ALTER EVENT SESSION [SqlDeep_Capture_TempdbContention] ON SERVER STATE = START;
GO

--References
--https://www.red-gate.com/hub/product-learning/sql-monitor/monitoring-tempdb-contention-using-extended-events-and-sql-monitor