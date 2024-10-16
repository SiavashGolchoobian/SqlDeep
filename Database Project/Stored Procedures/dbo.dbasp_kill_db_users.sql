SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <11/23/2016>
-- Version:		<3.1.0.0>
-- Description:	<Killing all non-systemic users of a specified non-systemic database except you>
-- Input Parameters:
--	@DatabaseNames:			'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@ExceptedSessions:		'spid1,spi2,...,spidN'
--	@ExceptedClientNames:	'192.168.1.2,192.168.1.3'
--	@ExceptedApplications:	'KasraVIPApp,GammaVIPApp'
--	@PrintOnly:				0 or 1
-- =============================================
CREATE PROC [dbo].[dbasp_kill_db_users] (
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@ExceptedSessions NVARCHAR(100)=Null,
	@ExceptedClientNames NVARCHAR(100)=Null,
	@ExceptedApplications NVARCHAR(100)=NULL,
	@PrintOnly BIT=1
	)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @myKilledCounter int = 0
	DECLARE @mySQLScript NVARCHAR(MAX)
	
	--Add current user session id to excepted session
	SET @ExceptedSessions=CAST(@@SPID as nvarchar) + ',' + ISNULL(@ExceptedSessions,'')
	SET @mySQLScript = CAST(N'' AS NVARCHAR(MAX))

	--Find first session id to kill
	SELECT 
		@myKilledCounter=@myKilledCounter+1,
		@mySQLScript=@mySQLScript + N'KILL ' + CAST(mySession.[session_id] AS NVARCHAR(10)) + N';'
	FROM 
		sys.dm_exec_sessions as mySession
		INNER JOIN master.sys.sysprocesses as mySessionInfo on mySession.session_id=mySessionInfo.spid
	WHERE
		[mySessionInfo].[dbid] IN (Select DB_ID([Name]) FROM [dbo].[dbafn_database_list](@DatabaseNames,1,0,1,0,0))
		AND [mySession].[is_user_process]=1				--Kill only user sesions
		AND [mySessionInfo].[status] <> 'rollback'		--Do not do any action on spid's with rollback status
		AND mySession.[session_id] NOT IN (SELECT CAST(Parameter as int) From dbo.dbafn_split(',',@ExceptedSessions) Where Parameter is not null)	--Ignore Specified Session ID's
		AND CAST([mySessionInfo].hostname COLLATE SQL_Latin1_General_CP1_CI_AS as NVARCHAR) NOT IN (SELECT CAST(Parameter COLLATE SQL_Latin1_General_CP1_CI_AS as NVARCHAR) AS Parameter From dbo.dbafn_split(',',@ExceptedClientNames) Where Parameter is not null)	--Ignore Specified Jost Name's
		AND CAST([mySessionInfo].[program_name] COLLATE SQL_Latin1_General_CP1_CI_AS AS NVARCHAR) NOT IN (SELECT CAST(Parameter COLLATE SQL_Latin1_General_CP1_CI_AS as NVARCHAR) AS Parameter From dbo.dbafn_split(',',@ExceptedApplications) Where Parameter is not null)	--Ignore Specified Applications
	
	--============Killing founded session
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

	IF @PrintOnly=0
		PRINT 'Total killed sessions are : ' + CAST(@myKilledCounter as nvarchar)
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_db_users', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2016-11-23', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_db_users', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-07-17', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_db_users', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.1.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_db_users', NULL, NULL
GO
