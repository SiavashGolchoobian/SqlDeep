CREATE EVENT SESSION [SqlDeep_Capture_RecentSuccessfulLogins] ON SERVER 
ADD EVENT sqlserver.login(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.session_server_principal_name))
ADD TARGET package0.event_file(SET filename=N'U:\Databases\Audit\SqlDeep_Capture_RecentSuccessfulLogins.xel',max_file_size=(256),max_rollover_files=(1))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO
ALTER EVENT SESSION [SqlDeep_Capture_RecentSuccessfulLogins] ON SERVER STATE = START;
GO