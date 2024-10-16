USE [msdb]
GO

/****** Object:  Alert [SqlDeep_Alert_OpenedTransaction]    Script Date: 2/28/2021 9:36:21 AM ******/
EXEC msdb.dbo.sp_add_alert @name=N'SqlDeep_Alert_OpenedTransaction', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'Transactions|Longest Transaction Running Time||>|600', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

