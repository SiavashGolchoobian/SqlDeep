------------------------------------- STEP 01:Create Powershell required credential
USE [master]
GO
CREATE CREDENTIAL [SqlDeepPowerShell_Credential] WITH IDENTITY = N'SqlDeep\psuser', SECRET = N'P@$$W0rd'
GO
------------------------------------- STEP 02:Create Powershell requires proxy
USE [msdb]
GO
EXEC msdb.dbo.sp_add_proxy @proxy_name=N'SqlDeepPowerShell_Proxy',@credential_name=N'SqlDeepPowerShell_Credential', @enabled=1
GO
EXEC msdb.dbo.sp_grant_proxy_to_subsystem @proxy_name=N'SqlDeepPowerShell_Proxy', @subsystem_id=3
GO
EXEC msdb.dbo.sp_grant_proxy_to_subsystem @proxy_name=N'SqlDeepPowerShell_Proxy', @subsystem_id=12
GO
------------------------------------- STEP 03:Create a Credential for SqlDeepRepo Linked Server usage and assigne it's role
USE [master]
GO
CREATE LOGIN [AppCred_SqlDeepRepo] WITH PASSWORD=N'P@$$W0rd', DEFAULT_DATABASE=[SqlDeep], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=ON, CHECK_POLICY=ON
GO

USE [SqlDeep]
GO
CREATE USER [AppCred_SqlDeepRepo] FOR LOGIN [AppCred_SqlDeepRepo]
GO
ALTER ROLE [role_sqldeep_repo] ADD MEMBER [AppCred_SqlDeepRepo]
GO

------------------------------------- STEP 04:Create a Linked Server on all MSX and TSX servers
USE [master]
GO
EXEC master.dbo.sp_addlinkedserver @server = N'SqlDeepRepo', @srvproduct=N'', @provider=N'SQLNCLI', @datasrc=N'DB-MN-DLV01.SQLDEEP.LOCAL\NODE,49149', @provstr=N'Encrypt=yes;', @catalog=N'SqlDeep'
 EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'SqlDeepRepo',@useself=N'False',@locallogin=N'SQLDEEP\SQL_AgentGMSA$',@rmtuser=N'AppCred_SqlDeepRepo',@rmtpassword='P@$$W0rd'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'collation compatible', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'data access', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'dist', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'pub', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'rpc', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'rpc out', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'sub', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'connect timeout', @optvalue=N'0'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'collation name', @optvalue=null
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'lazy schema validation', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'query timeout', @optvalue=N'0'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'use remote collation', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'SqlDeepRepo', @optname=N'remote proc transaction promotion', @optvalue=N'true'
GO
------------------------------------- STEP 05:Create a Job on ALL TSX and MSX servers to update their local repo with master repo via Link Server
USE [msdb]
GO
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SqlDeep' AND category_class=1)
BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SqlDeep'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Local_SqlDeep_ScriptRepositoryUpdate', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Update SqlDeep Command Repository', 
		@category_name=N'SqlDeep', 
		@owner_login_name=N'sqldeepsa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'UpdateRepository', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
DECLARE @LinkedServerName nvarchar(128)=''SqlDeepRepo''
DECLARE @Tags nvarchar(4000)=''TSX,MSX''

EXEC [repository].[dbasp_download_from_publisher] @LinkedServerName,@Tags', 
		@database_name=N'SqlDeep', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'SqlDeep.ScriptRepositoryUpdate', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240507, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'd30c8d98-d7b6-4bb0-8e00-aef3c6e7e791'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO