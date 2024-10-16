USE [msdb]
GO

/****** Object:  Job [SqlDeep_FullBackup]    Script Date: 3/1/2021 8:48:11 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SqlDeep Jobs]    Script Date: 3/1/2021 8:48:11 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SqlDeep Jobs' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SqlDeep Jobs'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SqlDeep_FullBackup', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Take full backup', 
		@category_name=N'SqlDeep Jobs', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Take full backup]    Script Date: 3/1/2021 8:48:11 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Take full backup', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @DatabaseNames nvarchar(max)=''<ALL_DATABASES>''
DECLARE @LocalDestinationPath nvarchar(max)
DECLARE @BackupExtension nvarchar(3)=''bak''
DECLARE @BackupType nvarchar(4)=''FULL''
DECLARE @RetainDays int=7
DECLARE @SplitThresholdSizeGB bigint=80
DECLARE @DiffOrLogThresholdSizeGB bigint=0
DECLARE @BackupFileNamingType nvarchar(50)=''DATE''
DECLARE @BackupCertificateName sysname=NULL
DECLARE @PrintOnly bit=0

SELECT @LocalDestinationPath=CAST(value as nvarchar(max)) from [SqlDeep].[sys].[extended_properties] WHERE class=0 and name=N''_BackupLocation''

EXECUTE [dbo].[dbasp_maintenance_take_backup] 
   @DatabaseNames
  ,@LocalDestinationPath
  ,@BackupExtension
  ,@BackupType
  ,@RetainDays
  ,@SplitThresholdSizeGB
  ,@DiffOrLogThresholdSizeGB
  ,@BackupFileNamingType
  ,@BackupCertificateName
  ,@PrintOnly', 
		@database_name=N'SqlDeep', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Delete old backups]    Script Date: 3/1/2021 8:48:11 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Delete old backups', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @FolderPath nvarchar(max)
DECLARE @FileExtension nvarchar(3)
DECLARE @OlderThan datetime

SELECT @FolderPath=CAST(value as nvarchar(max)) from [SqlDeep].[sys].[extended_properties] WHERE class=0 and name=N''_BackupLocation''
SET @FileExtension=''bak''
SET @OlderThan=cast( convert(date, DATEADD(DAY,-8,getdate()),121) as datetime)

EXECUTE [dbo].[dbasp_maintenance_delete_folderfiles] 
   @FolderPath
  ,@FileExtension
  ,@OlderThan', 
		@database_name=N'SqlDeep', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'SqlDeep.FullBackup', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200725, 
		@active_end_date=99991231, 
		@active_start_time=10000, 
		@active_end_time=235959, 
		@schedule_uid=N'7cd8a054-4d48-4702-9c64-8e2dec52ca64'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

