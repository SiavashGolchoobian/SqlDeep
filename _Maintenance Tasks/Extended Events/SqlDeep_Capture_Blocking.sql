--This event works off the blocked process threshold that you need to provide to the system configuration
EXEC sp_configure 'show advanced option', '1';
RECONFIGURE;
EXEC sp_configure 'blocked process threshold', 5;
RECONFIGURE;
GO

CREATE EVENT SESSION [SqlDeep_Capture_Blocking] ON SERVER 
ADD EVENT sqlserver.blocked_process_report
ADD TARGET package0.event_file(SET filename=N'U:\Databases\Audit\SqlDeep_Capture_Blocking.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=3 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_NODE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

ALTER EVENT SESSION [SqlDeep_Capture_Blocking] ON SERVER STATE = START;
GO