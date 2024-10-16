USE [msdb]
GO

EXEC msdb.dbo.sp_add_alert @name=N'SqlDeep_Alert_WaitingTasks', 
		@message_id=0, 
		@severity=0, 
		@enabled=0, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'User Settable|Query|User counter 1|>|15', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

