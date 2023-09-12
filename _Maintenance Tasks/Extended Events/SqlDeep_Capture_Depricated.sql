--Investigating deprecated commands
CREATE EVENT SESSION [SqlDeep_Capture_Depricated] ON SERVER 
ADD EVENT sqlserver.deprecation_announcement(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.nt_username,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.deprecation_final_support(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.nt_username,sqlserver.session_id,sqlserver.sql_text))
ADD TARGET package0.event_file(SET filename=N'U:\Databases\SqlDeep_Capture_Depricated.xel')
WITH (MAX_MEMORY=1024 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_NODE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

ALTER EVENT SESSION [SqlDeep_Capture_Depricated] ON SERVER STATE = START;
GO
