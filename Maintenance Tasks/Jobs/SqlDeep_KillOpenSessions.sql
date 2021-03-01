USE [msdb]
GO

/****** Object:  Job [SqlDeep_KillOpenSessions]    Script Date: 3/1/2021 8:48:19 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SqlDeep Jobs]    Script Date: 3/1/2021 8:48:19 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SqlDeep Jobs' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SqlDeep Jobs'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SqlDeep_KillOpenSessions', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Kill idle sessions', 
		@category_name=N'SqlDeep Jobs', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Kill old regular sessions]    Script Date: 3/1/2021 8:48:19 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Kill old regular sessions', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @DatabaseNames nvarchar(max)=''<ALL_DATABASES>''
DECLARE @DurationThresholdMinutes int=10
DECLARE @ExceptActiveSessions bit=1
DECLARE @ExceptJobSessions bit=1
DECLARE @ExceptSSMSSessions bit=1
DECLARE @ExceptSysadmins bit=1
DECLARE @ExceptedLogins nvarchar(max)=''sa''
DECLARE @ExceptedHostnames nvarchar(max)=NULL
DECLARE @PrintOnly bit=0

EXECUTE [dbo].[dbasp_kill_oldsessions] 
   @DatabaseNames
  ,@DurationThresholdMinutes
  ,@ExceptActiveSessions
  ,@ExceptJobSessions
  ,@ExceptSSMSSessions
  ,@ExceptSysadmins
  ,@ExceptedLogins
  ,@ExceptedHostnames
  ,@PrintOnly', 
		@database_name=N'SqlDeep', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Kill old sysadmin sessions]    Script Date: 3/1/2021 8:48:19 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Kill old sysadmin sessions', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @DatabaseNames nvarchar(max)=''<ALL_DATABASES>''
DECLARE @DurationThresholdMinutes int=120
DECLARE @ExceptActiveSessions bit=1
DECLARE @ExceptJobSessions bit=1
DECLARE @ExceptSSMSSessions bit=1
DECLARE @ExceptSysadmins bit=0
DECLARE @ExceptedLogins nvarchar(max)=NULL
DECLARE @ExceptedHostnames nvarchar(max)=NULL
DECLARE @PrintOnly bit=0

EXECUTE [dbo].[dbasp_kill_oldsessions] 
   @DatabaseNames
  ,@DurationThresholdMinutes
  ,@ExceptActiveSessions
  ,@ExceptJobSessions
  ,@ExceptSSMSSessions
  ,@ExceptSysadmins
  ,@ExceptedLogins
  ,@ExceptedHostnames
  ,@PrintOnly', 
		@database_name=N'SqlDeep', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'CollectorSchedule_Every_10min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20170822, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'dcdc8189-da0a-41ef-aa79-e39016f3bdfa'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

