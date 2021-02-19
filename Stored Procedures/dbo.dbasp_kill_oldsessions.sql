SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <9/6/2016>
-- Version:		<3.1.0.0>
-- Description:	<Killing all configured long running sessions>
-- Input Parameters:
--	@DatabaseNames:		'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@DurationThresholdMinutes int=60:	specify ideal time in minutes for example for killing sessions that ideal for 60 minutes set this parameter to 60
--	@ExceptActiveSessions: 1 for Exclude active sessions from killing process and 0 to kill also long running active sessions
--	@ExceptJobSessions: 1 for Exclude SQL Server Agent Job sessions from killing process and 0 to kill also long running job sessions
--	@ExceptSSMSSessions: 1 for Exclude SQL Server Management Studio sessions from killing process and 0 to kill also this kind of sessions
--	@ExceptSysadmins  1 for Exclude SQL Server sysadmin sessions from killing process and 0 to kill also this kind of sessions
--	@ExceptedLogins: Used for excepting sessions run with specefied logins, for example: 'sa,admin,x,y' or Null
--	@ExceptedHostnames:  Used for excepting sessions run from specefied hostnames or Null
--	@PrintOnly:	0 or 1
-- =============================================

CREATE PROC [dbo].[dbasp_kill_oldsessions] (
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@DurationThresholdMinutes INT=60,
	@ExceptActiveSessions BIT=1,
	@ExceptJobSessions BIT=1,
	@ExceptSSMSSessions BIT=1,
	@ExceptSysadmins BIT=1,
	@ExceptedLogins NVARCHAR(MAX)=NULL,
	@ExceptedHostnames NVARCHAR(MAX)=NULL,
	@PrintOnly BIT=1
) AS
BEGIN
	SET NOCOUNT ON
	
	DECLARE @myCurrentTime datetime;
	DECLARE @myKilledCounter int = 0
	DECLARE @mySQLScript NVARCHAR(MAX)

	SET @myCurrentTime=GETDATE()
	SET @mySQLScript = CAST(N'' AS NVARCHAR(MAX))

	SELECT
		@myKilledCounter=@myKilledCounter+1,
		@mySQLScript=@mySQLScript + N'KILL ' + CAST(mySession.[session_id] AS NVARCHAR(10)) + N';'
	FROM
		sys.dm_exec_sessions as mySession
		INNER JOIN master.sys.sysprocesses as mySessionInfo on mySession.session_id=mySessionInfo.spid
	WHERE
		mySession.session_id>50
		AND mySession.is_user_process=1
		AND CASE @ExceptActiveSessions
				WHEN 0 THEN 1
				WHEN 1 THEN 
					CASE WHEN mySession.[status]='sleeping' THEN 1 ELSE 0 END
				END=1						-- Result of 1 means Include and 0 means Exclude
		AND CASE @ExceptJobSessions
				WHEN 0 THEN 1
				WHEN 1 THEN 
					CASE WHEN mySession.[program_name] LIKE 'SQLAgent%' OR mySession.[program_name] LIKE 'SQL Server Data Collector%' OR mySession.[program_name] LIKE 'SSIS%' OR DB_NAME([mySession].[database_id]) = 'SSISDB' THEN 0 ELSE 1 END
				END=1						-- Result of 1 means Include and 0 means Exclude
		AND CASE @ExceptSSMSSessions
				WHEN 0 THEN 1
				WHEN 1 THEN 
					CASE WHEN mySession.[program_name] LIKE 'Microsoft SQL Server Management Studio%' THEN 0 ELSE 1 END
				END=1						-- Result of 1 means Include and 0 means Exclude
		AND CASE @ExceptSysadmins
				WHEN 0 THEN 1
				WHEN 1 THEN
					CASE WHEN mySession.login_name IN (SELECT mySysAdminLoginList.[loginname] as LoginName FROM master.dbo.syslogins as mySysAdminLoginList WHERE mySysAdminLoginList.[sysadmin]=1) THEN 0 ELSE 1 END	--Except sysadmin users
				END=1
		AND mySession.login_name collate SQL_Latin1_General_CP1_CI_AS NOT IN (SELECT myLoginList.Parameter collate SQL_Latin1_General_CP1_CI_AS as LoginName FROM [dbo].[dbafn_split](N',',@ExceptedLogins) as myLoginList WHERE myLoginList.Parameter IS NOT NULL)
		AND mySession.login_name collate SQL_Latin1_General_CP1_CI_AS NOT IN (N'NT AUTHORITY\SYSTEM' collate SQL_Latin1_General_CP1_CI_AS)	--This account is added because of WSFC resource dll connection that made by this user
		AND DATEDIFF(minute,(CASE WHEN mySession.last_request_end_time>=mySession.last_request_start_time THEN mySession.last_request_end_time ELSE mySession.last_request_start_time END),@myCurrentTime)>=@DurationThresholdMinutes
		AND mySessionInfo.[dbid] IN (Select DB_ID([Name]) FROM [dbo].[dbafn_database_list](@DatabaseNames,1,0,0,0,0))
		AND mySession.host_name collate SQL_Latin1_General_CP1_CI_AS NOT IN (SELECT myHostNameList.Parameter collate SQL_Latin1_General_CP1_CI_AS as HostName FROM [dbo].[dbafn_split](N',',@ExceptedHostnames) as myHostNameList WHERE myHostNameList.Parameter IS NOT NULL)

	BEGIN TRY
		EXEC [dbo].[dbasp_print_text] @mySQLScript
		IF @PrintOnly=0
			EXECUTE sp_executesql @mySQLScript
	END TRY
	BEGIN CATCH
		DECLARE @CustomMessage nvarchar(255)
		SET @CustomMessage='Killing session error'
		EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
	END CATCH

	Print 'Total killed sessions are : ' + CAST(@myKilledCounter as nvarchar)
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_oldsessions', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2016-06-09', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_oldsessions', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-07-17', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_oldsessions', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.1.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_oldsessions', NULL, NULL
GO
