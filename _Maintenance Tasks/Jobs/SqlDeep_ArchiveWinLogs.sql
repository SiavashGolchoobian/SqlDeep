USE [msdb]
GO

/****** Object:  Job [SqlDeep_ArchiveWinLogs]    Script Date: 11/18/2023 14:40:09 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Multi-Server)]]    Script Date: 11/18/2023 14:40:09 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Multi-Server)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'MULTI-SERVER', @name=N'[Uncategorized (Multi-Server)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SqlDeep_ArchiveWinLogs', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Multi-Server)]', 
		@owner_login_name=N'sqldeepsa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ArchiveAndRemoveWinLogs]    Script Date: 11/18/2023 14:40:09 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ArchiveAndRemoveWinLogs', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'$myLogPathTemplate = "C:\Windows\System32\winevt\logs\Archive-Application-*.evtx"
$myZipPathTemplate = "U:\Databases\Audit\ApplicationLog_{myDate}.zip"
$myChunkSize=5
$myLogPath=$myLogPathTemplate
$myZipPath=$myZipPathTemplate

$mySelectedFiles = Get-Item -Path $myLogPath | Sort-Object -Property LastWriteTime | Select-Object -SkipLast 2
$myGroupedFiles = $mySelectedFiles | Group-Object -Property {$_.LastWriteTime.ToString("yyyyMMdd")}
ForEach ($myGroup in $myGroupedFiles) {
    $myGroupCountOfFiles=[math]::Ceiling($myGroup.Count/$myChunkSize)
    For ($myCounter=1; $myCounter -le $myGroupCountOfFiles; $myCounter+=1) {
        try{
            $myCurrentZipPath = $myZipPath.Replace(''{myDate}'',$myGroup.Name)
            Write-Host ($myCurrentZipPath + " " + $myCounter.ToString() + "of" + $myGroupCountOfFiles.ToString() + " started.")
            $myGroupChunk = $myGroup.Group | Select-Object -Skip (($myCounter-1)*$myChunkSize) -First $myChunkSize
            $myGroupChunk | Compress-Archive -DestinationPath $myCurrentZipPath -CompressionLevel Optimal -Update
            $myGroupChunk | Remove-Item 
        }catch{
            Write-Host ($_.ToString())
        }
    }
}', 
		@database_name=N'master', 
		@output_file_name=N'U:\Install\SqlDeep_ArchiveWinLogs.txt', 
		@flags=34, 
		@proxy_name=N'Proxy_for_OS'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [RemoveDepricatedArchives]    Script Date: 11/18/2023 14:40:09 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'RemoveDepricatedArchives', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'$myZipPath = "U:\Databases\Audit\ApplicationLog_*.zip"
$myRetainDays=4

$mySelectedFiles = Get-Item -Path $myZipPath | Sort-Object -Property LastWriteTime | Select-Object -SkipLast $myRetainDays
$mySelectedFiles | Remove-Item', 
		@database_name=N'master', 
		@flags=0, 
		@proxy_name=N'Proxy_for_OS'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'CollectorSchedule_Every_15min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20220113, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'f2df01f8-dda3-455b-b555-f5ff3b37a951'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-C1-DLV11\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-BK-DBV02\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-C1-DLV12\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-C1-DLV13\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-C1-DLV14\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-C1-DLV15\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-C1-DLV16\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-C1-DLV17\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-C1-DLV18\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-C5-DLV01'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-DW-DLV01\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-DW-DTV01\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-EL-DLV01\NODE'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'DB-SH-DLV01\SHAREPOINT'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

