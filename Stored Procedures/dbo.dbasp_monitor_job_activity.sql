SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<zahra saffarpour>
-- Create date: <06/04/2020>
-- Version:		<3.0.1.0>
-- Description:	<>
-- Input Parameters:			
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_monitor_job_activity]
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO monitor.[JobActivity](JobID,JobName,RunRequestedDate)
	SELECT myJobActivity.job_id, myJobView. name AS JobName, myJobActivity.run_requested_date
	FROM msdb.dbo.sysjobs_view AS myJobView WITH (READPAST)
	INNER JOIN msdb.dbo.sysjobactivity AS myJobActivity WITH(READPAST) ON myJobView.job_id = myJobActivity.job_id
	INNER JOIN monitor.JobAlert AS myJobAlert WITH(READPAST) ON myJobView.name = myJobAlert.JobName COLLATE SQL_Latin1_General_CP1256_CI_AS
	WHERE myJobActivity.run_Requested_date IS NOT NULL  
		AND myJobActivity.stop_execution_date IS NULL  
		AND myJobActivity.start_execution_date < DATEADD(MINUTE,-1*myJobAlert.SendAlertAfterMinute,GETDATE())
		AND myJobActivity.session_id = (SELECT MAX(session_id) FROM msdb.dbo.sysjobactivity WHERE job_id = myJobView.job_id )
		AND NOT EXISTS (SELECT 1 FROM monitor.JobActivity AS myTemp 
						  WHERE myJobActivity.job_id = myTemp.JobID 
							AND myJobActivity.run_requested_date = myTemp.RunRequestedDate)
END
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_activity', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-06-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_activity', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_activity', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_activity', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_activity', NULL, NULL
GO
