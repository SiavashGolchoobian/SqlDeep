SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =================================================================================
-- Author:		Siavash Golchoobian
-- Create date: <06/04/2024>
-- Version:		<3.0.0.0>
-- Description:
--                 This procedure finds the chain of sessions blocking @BlockedSessionId
-- Input Parameters:
--	@BlockedSessionId:		Smallint value, your blocked seesion id
-- ==================================================================================
CREATE PROCEDURE [dbo].[dbasp_get_blocked_session_chain] (
	@BlockedSessionId smallint)
AS
BEGIN
   SET NOCOUNT ON;
	With myChain AS (
	SELECT 
		myRequest.session_id,
		myRequest.blocking_session_id,
		'KILL ' + CAST(myRequest.blocking_session_id AS varchar(50)) AS KillCommand
	FROM 
		sys.dm_exec_requests AS myRequest
	WHERE
		myRequest.session_id=@BlockedSessionId
	UNION ALL
	SELECT 
		myRequest.session_id,
		myRequest.blocking_session_id,
		'KILL ' + CAST(myRequest.blocking_session_id AS varchar(50)) AS KillCommand
	FROM 
		sys.dm_exec_requests AS myRequest
		INNER JOIN myChain ON myRequest.session_id=myChain.blocking_session_id
	WHERE
		myRequest.blocking_session_id <> 0
	)
	SELECT session_id,blocking_session_id,KillCommand FROM myChain
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_blocked_session_chain', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2024-04-06', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_blocked_session_chain', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2024-04-06', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_blocked_session_chain', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_blocked_session_chain', NULL, NULL
GO
