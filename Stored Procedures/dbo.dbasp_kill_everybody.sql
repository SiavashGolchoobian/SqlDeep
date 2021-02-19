SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <09/02/2019>
-- Version:		<3.0.0.0>
-- Description:	<Killing all user sessions except caller session>
-- Input Parameters:
--	@PrintOnly:				0 or 1
-- =============================================
CREATE PROC [dbo].[dbasp_kill_everybody] (@PrintOnly BIT=1)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @myCurrentSessions INT
	DECLARE @mySQLScript NVARCHAR(MAX)
	
	--Add current user session id to excepted session
	
	SET @myCurrentSessions=@@SPID
	SET @mySQLScript = CAST(N'' AS NVARCHAR(MAX))

	--Find session id's to kill
	SELECT 
		@mySQLScript=@mySQLScript + N'KILL ' + CAST(mySession.[session_id] AS NVARCHAR(10)) + N';'
	FROM 
		sys.dm_exec_sessions AS mySession
	WHERE
		[mySession].[is_user_process]=1				--Kill only user sesions
		AND mySession.[session_id] <> @myCurrentSessions
	
	--============Killing founded sessions
	PRINT @mySQLScript
	IF @PrintOnly=0
		EXECUTE sp_executesql @mySQLScript
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_everybody', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-09-02', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_everybody', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-09-02', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_everybody', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_everybody', NULL, NULL
GO
