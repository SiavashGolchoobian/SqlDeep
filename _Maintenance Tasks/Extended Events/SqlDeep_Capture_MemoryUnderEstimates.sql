--Investigating the plan with bad cardinality estimation resulting to under memeory estimation and finally tempdb spils
CREATE EVENT SESSION [SqlDeep_Capture_MemoryUnderEstimates] ON SERVER 
ADD EVENT sqlserver.exchange_spill(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text)),
ADD EVENT sqlserver.hash_warning(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text)),
ADD EVENT sqlserver.sort_warning(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text))
ADD TARGET package0.event_file(SET filename=N'U:\Databases\SqlDeep_Capture_MemoryUnderEstimates.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=3 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_NODE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

ALTER EVENT SESSION [SqlDeep_Capture_MemoryUnderEstimates] ON SERVER STATE = START;
GO