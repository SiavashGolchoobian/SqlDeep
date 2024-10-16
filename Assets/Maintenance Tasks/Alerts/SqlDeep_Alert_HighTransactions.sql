USE [msdb]
GO

/****** Object:  Alert [SqlDeep_Alert_HighTransactions]    Script Date: 2/28/2021 9:35:58 AM ******/
EXEC msdb.dbo.sp_add_alert @name=N'SqlDeep_Alert_HighTransactions', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=180, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'General Statistics|Transactions||>|40', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

