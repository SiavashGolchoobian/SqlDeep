CREATE EVENT SESSION [SqlDeep_Capture_PageSplit] ON SERVER 
ADD EVENT sqlserver.page_split(
    ACTION(sqlserver.database_name,sqlserver.sql_text)
    WHERE ([sqlserver].[database_name]=N'yourdatabase'))
ADD TARGET package0.event_file(SET filename=N'U:\Databases\SqlDeep_Capture_PageSplit.xel',max_file_size=(5120))
WITH (STARTUP_STATE=ON)