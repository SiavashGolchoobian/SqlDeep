USE [msdb]
GO

EXEC msdb.dbo.sp_add_alert @name=N'SqlDeep_Alert_AG_Role_Change', 
		@message_id=1480, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=60, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

