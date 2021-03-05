USE [msdb]
GO

/****** Object:  Job [SqlDeep_PolicyChecks]    Script Date: 3/1/2021 8:48:42 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SqlDeep Jobs]    Script Date: 3/1/2021 8:48:42 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SqlDeep Jobs' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SqlDeep Jobs'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SqlDeep_PolicyChecks', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'SqlDeep Jobs', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check TraceFlags]    Script Date: 3/1/2021 8:48:42 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check TraceFlags', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'# Note update this variable for a different policy name
$sourceOfPolicy = "."
$policyToEvaluate = "SqlDeep_CheckTraceFlags"

if (''$(ESCAPE_SQUOTE(INST))'' -eq ''MSSQLSERVER'') {$instname = ''\DEFAULT''} ELSE {$instname = ''''};

$policiesPSPath = ''SQLSERVER:\SQLPolicy\'' + $sourceOfPolicy

# Check if policy Automation is enabled
$policyManagement = Get-Item $policiesPSPath
$policyManagement.Refresh()

if( $policyManagement.Enabled -eq $False)
{
    throw ''Policy automation is not enabled on instance'' 
};

# Get specific policy and evaluate
$result = $policyManagement.Policies |  where { $_.Name -eq $policyToEvaluate}   | Invoke-PolicyEvaluation -AdHocPolicyEvaluationMode 1 -TargetServerName "$(ESCAPE_NONE(SRVR))$instname"

# if there were any failures throw
if( $result.Result -eq $False)
{
    throw ''There were one or more policy evaluation failures. Please check agent logs and policy evaluation histories'' 
};

# print evaluation results
$result
$result.ConnectionEvaluationHistories', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check Extended Properties]    Script Date: 3/1/2021 8:48:42 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check Extended Properties', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'# Note update this variable for a different policy name
$sourceOfPolicy = $env:computername + "\DEFAULT"
#$sourceOfPolicy = $env:computername + "\NODE"
#$sourceOfPolicy = "DBCentralServer01\DEFAULT"
$policyToEvaluate = "SqlDeep_CheckExtendedProperties"

if (''$(ESCAPE_SQUOTE(INST))'' -eq ''MSSQLSERVER'') {$instname = ''\DEFAULT''} ELSE {$instname = ''''};

$policiesPSPath = ''SQLSERVER:\SQLPolicy\'' + $sourceOfPolicy

# Check if policy Automation is enabled
$policyManagement = Get-Item $policiesPSPath
$policyManagement.Refresh()

if( $policyManagement.Enabled -eq $False)
{
    throw ''Policy automation is not enabled on instance'' 
};

# Get specific policy and evaluate
$result = $policyManagement.Policies |  where { $_.Name -eq $policyToEvaluate}   | Invoke-PolicyEvaluation -AdHocPolicyEvaluationMode 1 -TargetServerName "$(ESCAPE_NONE(SRVR))$instname"

# if there were any failures throw
if( $result.Result -eq $False)
{
    throw ''There were one or more policy evaluation failures. Please check agent logs and policy evaluation histories'' 
};

# print evaluation results
$result
$result.ConnectionEvaluationHistories', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check DataFile Size]    Script Date: 3/1/2021 8:48:42 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check DataFile Size', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'# Note update this variable for a different policy name
$sourceOfPolicy = $env:computername + "\DEFAULT"
#$sourceOfPolicy = $env:computername + "\NODE"
#$sourceOfPolicy = "DBCentralServer01\DEFAULT"
$policyToEvaluate = "SqlDeep_CheckDataFileSizing"

if (''$(ESCAPE_SQUOTE(INST))'' -eq ''MSSQLSERVER'') {$instname = ''\DEFAULT''} ELSE {$instname = ''''};

$policiesPSPath = ''SQLSERVER:\SQLPolicy\'' + $sourceOfPolicy

# Check if policy Automation is enabled
$policyManagement = Get-Item $policiesPSPath
$policyManagement.Refresh()

if( $policyManagement.Enabled -eq $False)
{
    throw ''Policy automation is not enabled on instance'' 
};

# Get specific policy and evaluate
$result = $policyManagement.Policies |  where { $_.Name -eq $policyToEvaluate}   | Invoke-PolicyEvaluation -AdHocPolicyEvaluationMode 1 -TargetServerName "$(ESCAPE_NONE(SRVR))$instname"

# if there were any failures throw
if( $result.Result -eq $False)
{
    throw ''There were one or more policy evaluation failures. Please check agent logs and policy evaluation histories'' 
};

# print evaluation results
$result
$result.ConnectionEvaluationHistories', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check Same File size]    Script Date: 3/1/2021 8:48:42 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check Same File size', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'# Note update this variable for a different policy name
$sourceOfPolicy = $env:computername + "\DEFAULT"
#$sourceOfPolicy = $env:computername + "\NODE"
#$sourceOfPolicy = "DBCentralServer01\DEFAULT"
$policyToEvaluate = "SqlDeep_CheckSameFileSize"

if (''$(ESCAPE_SQUOTE(INST))'' -eq ''MSSQLSERVER'') {$instname = ''\DEFAULT''} ELSE {$instname = ''''};

$policiesPSPath = ''SQLSERVER:\SQLPolicy\'' + $sourceOfPolicy

# Check if policy Automation is enabled
$policyManagement = Get-Item $policiesPSPath
$policyManagement.Refresh()

if( $policyManagement.Enabled -eq $False)
{
    throw ''Policy automation is not enabled on instance'' 
};

# Get specific policy and evaluate
$result = $policyManagement.Policies |  where { $_.Name -eq $policyToEvaluate}   | Invoke-PolicyEvaluation -AdHocPolicyEvaluationMode 1 -TargetServerName "$(ESCAPE_NONE(SRVR))$instname"

# if there were any failures throw
if( $result.Result -eq $False)
{
    throw ''There were one or more policy evaluation failures. Please check agent logs and policy evaluation histories'' 
};

# print evaluation results
$result
$result.ConnectionEvaluationHistories', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Everyday_02_15_00', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20171217, 
		@active_end_date=99991231, 
		@active_start_time=21500, 
		@active_end_time=235959, 
		@schedule_uid=N'ec0bd80f-f3d5-4afe-a108-41bb1cadb6f7'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

