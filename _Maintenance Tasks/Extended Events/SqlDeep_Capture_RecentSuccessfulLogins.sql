CREATE EVENT SESSION [SqlDeep_Capture_RecentSuccessfulLogins] ON SERVER 
ADD EVENT sqlserver.login(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.session_server_principal_name))
ADD TARGET package0.event_file(SET filename=N'U:\Databases\Audit\SqlDeep_Capture_RecentSuccessfulLogins.xel',max_file_size=(256),max_rollover_files=(1))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO
ALTER EVENT SESSION [SqlDeep_Capture_RecentSuccessfulLogins] ON SERVER STATE = START;
GO

---------------Query Result:
SELECT
	[event_xml].[value]('(./action[@name="session_server_principal_name"]/value)[1]', 'nvarchar(255)') AS [LoginName],
	[event_xml].[value]('(./data[@name="database_id"]/value)[1]', 'int') AS [database_id],
	[event_xml].[value]('(./data[@name="database_name"]/value)[1]', 'sysname') AS [database_name],
	[event_xml].[value]('(./action[@name="client_hostname"]/value)[1]', 'nvarchar(255)') AS [client_hostname],
	[event_xml].[value]('(./action[@name="client_app_name"]/value)[1]', 'nvarchar(max)') AS [client_app_name],
	[event_xml].[value]('@timestamp', 'datetimeoffset') AS [timestamp]
FROM
	(
	SELECT 
		CAST([event_data] AS xml) AS XmlData,
		* 
	FROM 
		sys.fn_xe_file_target_read_file('U:\Databases\Audit\SqlDeep_Capture_RecentSuccessfulLogins*.xel', null, null, NULL)
	) AS myData
	CROSS APPLY [XmlData].[nodes]('//event') AS [n]([event_xml])