USE [msdb]
GO

/****** Object:  Job [SqlDeep_Reindex]    Script Date: 3/1/2021 8:49:14 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SqlDeep Jobs]    Script Date: 3/1/2021 8:49:14 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SqlDeep Jobs' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SqlDeep Jobs'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SqlDeep_Reindex', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Maintain indexes and statistics', 
		@category_name=N'SqlDeep Jobs', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Reindex]    Script Date: 3/1/2021 8:49:15 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Reindex', 
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
DECLARE @FillFactor nvarchar(10)=''AUTO''
DECLARE @ForceTo nvarchar(10)=''AUTO''
DECLARE @IndexesUsedInLastXdays int=0
DECLARE @HugeUntidyDetection bit=0
DECLARE @MinimumRowCountToProcess bigint=NULL
DECLARE @MaximumRowCountToProcess bigint=NULL
DECLARE @PrintOnly bit=0

EXECUTE [dbo].[dbasp_maintenance_reindex] 
   @DatabaseNames
  ,@FillFactor
  ,@ForceTo
  ,@IndexesUsedInLastXdays
  ,@HugeUntidyDetection
  ,@MinimumRowCountToProcess
  ,@MaximumRowCountToProcess
  ,@PrintOnly', 
		@database_name=N'SqlDeep', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Update Statistics]    Script Date: 3/1/2021 8:49:15 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Update Statistics', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @DatabaseNames nvarchar(max)=N''<ALL_DATABASES>''
DECLARE @FilterTables NVARCHAR(MAX) = N''<ALL_TABLES>''
DECLARE @IgnoreStatsUpdatedInLastXHours int=6
DECLARE @UnusedStatTresholdInDays int=365
DECLARE @PrintOnly bit=0

EXECUTE [dbo].[dbasp_maintenance_updatestatistics] 
   @DatabaseNames
  ,@FilterTables
  ,@IgnoreStatsUpdatedInLastXHours
  ,@UnusedStatTresholdInDays
  ,@PrintOnly', 
		@database_name=N'SqlDeep', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'SqlDeep.Reindex_05_10_00', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200807, 
		@active_end_date=99991231, 
		@active_start_time=51000, 
		@active_end_time=235959, 
		@schedule_uid=N'4f3f8e54-c94c-417b-ba9a-b3a5878bdd3c'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'SqlDeep.Reindex_22_05_00', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200807, 
		@active_end_date=99991231, 
		@active_start_time=220500, 
		@active_end_time=235959, 
		@schedule_uid=N'6abeb17b-06d8-419b-ac42-3183a3b75bcd'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

