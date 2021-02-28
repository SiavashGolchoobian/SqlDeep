USE [msdb]
GO

/****** Object:  Alert [SqlDeep_Alert_Deadlocks]    Script Date: 2/28/2021 9:35:42 AM ******/
EXEC msdb.dbo.sp_add_alert @name=N'SqlDeep_Alert_Deadlocks', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@wmi_namespace=N'\\.\root\Microsoft\SqlServer\ServerEvents\NODE', 
		@wmi_query=N'SELECT * FROM DEADLOCK_GRAPH', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

