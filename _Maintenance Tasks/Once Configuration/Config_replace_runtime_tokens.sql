USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1, 
		@alert_replace_runtime_tokens=1, 
		@use_databasemail=1
GO
