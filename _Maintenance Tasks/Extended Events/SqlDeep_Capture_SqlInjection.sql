--https://www.red-gate.com/hub/product-learning/sql-monitor/detect-sql-injection-attacks-using-extended-events-sql-monitor
--This event used to detect SQL Injection attacks
CREATE EVENT SESSION [SqlDeep_Capture_SqlInjection] ON SERVER 
    ADD EVENT sqlserver.error_reported --the event we are interested in
      (ACTION --the general global fields ('actions') we want to receive
      (sqlserver.client_app_name, sqlserver.client_connection_id, sqlserver.[database_name],
      sqlserver.nt_username, sqlserver.sql_text, sqlserver.username)
       WHERE  --the filters that we want to use so and to get just the relevant errors
         error_number=(102) OR error_number=(105) OR error_number=(205) OR (error_number=(207) OR
       error_number=(208) OR error_number=(245) OR error_number=(2812) OR error_number=(18456) 
         OR sqlserver.like_i_sql_unicode_string([message],N'%permission%') 
         OR sqlserver.like_i_sql_unicode_string([message],N'%denied%')
       )
     )
ADD TARGET package0.event_file(SET filename=N'U:\Databases\SqlDeep_Capture_SqlInjection.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_NODE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

ALTER EVENT SESSION [SqlDeep_Capture_SqlInjection] ON SERVER STATE = START;
GO