SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <5/31/2014>
-- Version:		<3.0.0.0>
-- Description:	<Counting number of currently waiting tasks>
-- =============================================
CREATE PROCEDURE [trace].[WaitingTasks]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @WitedTasks as int;
    
	SET @WitedTasks=ISNULL((
						--Select 
						--	Count(*)
						--FROM 
						--	sys.dm_os_waiting_tasks as myTask
						--	inner join sys.dm_exec_sessions as mySessions on mySessions.session_id=myTask.session_id
						--WHERE
						--	mySessions.is_user_process=1
						select COUNT(*) from master.sys.sysprocesses as myProcess where myProcess.spid > 50 and myProcess.status not in ('running','sleeping')
						),0)
	
	exec sp_user_counter1 @WitedTasks;
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'trace', 'PROCEDURE', N'WaitingTasks', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-05-31', 'SCHEMA', N'trace', 'PROCEDURE', N'WaitingTasks', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'trace', 'PROCEDURE', N'WaitingTasks', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'trace', 'PROCEDURE', N'WaitingTasks', NULL, NULL
GO
