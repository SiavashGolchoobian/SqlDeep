SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<zahra saffarpour>
-- Create date: <05/17/2020>
-- Version:		<3.0.1.0>
-- Description:	<>
-- Input Parameters:			
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_monitor_job_failure]
	@minutes_to_monitor SMALLINT = 1440
AS
BEGIN
	SET NOCOUNT ON;
	-- First, collect list of SQL Server agent jobs and update ours as needed.
	INSERT INTO monitor.Job (JobIdGuid, JobName, JobCreateDatetime, JobLastModifiedDatetime, IsEnabled, IsDeleted, JobCategoryName)
	SELECT sysJob.job_id AS job_id_guid, sysJob.name AS job_name, sysJob.date_created AS job_create_datetime, sysJob.date_modified AS job_last_modified_datetime,
		   sysJob.enabled AS is_enabled, 0 AS is_deleted, ISNULL(myCategory.name, '') AS job_category_name
	FROM msdb.dbo.sysjobs as sysJob
	LEFT JOIN msdb.dbo.syscategories as myCategory ON myCategory.category_id = sysJob.category_id
	WHERE NOT EXISTS (SELECT 1 FROM monitor.Job AS myJob WHERE myJob.JobIdGuid = sysJob.job_id)
	
	-- Update our jobs data with any changes since the last update time.
	UPDATE myJob
	SET 
		JobName = sysJob.name,
		JobCreateDatetime = sysJob.date_created,
		JobLastModifiedDatetime = sysJob.date_modified,
		IsEnabled = sysJob.enabled,
		JobCategoryName = ISNULL(myCategory.name, '')
	FROM monitor.Job AS myJob
	INNER JOIN msdb.dbo.sysjobs as sysJob ON sysJob.job_id = myJob.JobIdGuid
	LEFT JOIN msdb.dbo.syscategories as myCategory ON myCategory.category_id = sysJob.category_id
	
	-- If a job was deleted, then mark it as no longer enabled.
	UPDATE myJob
	SET IsEnabled = 0,
		IsDeleted = 1
	FROM monitor.Job as myJob
	LEFT JOIN msdb.dbo.sysjobs as sysJob ON sysJob.Job_Id = myJob.JobIdGuid
	WHERE sysJob.Job_Id IS NULL

	CREATE TABLE #Jobfailure
	(
		job_id_guid UNIQUEIDENTIFIER NOT NULL,
		job_start_time DATETIME NOT NULL,
		job_failure_time DATETIME NOT NULL,
		failure_message NVARCHAR(MAX) NOT NULL,
		instance_id INT NOT NULL,
		job_failure_step_number INT NOT NULL,
		job_step_severity INT NOT NULL,
		retries_attempted INT NOT NULL,
		step_name SYSNAME NOT NULL,
		sql_message_id INT NOT NULL
	);
	--Find all recent job failures and log them in the target log table.    
	;WITH myCTE 
	AS 
	(
		SELECT job_id AS job_id_guid,
			   CAST(FORMAT(DATEADD(S,(run_time/10000)*60*60 +((run_time - (run_time/10000) * 10000)/100) * 60 + (run_time - (run_time/100) * 100) ,CONVERT(DATETIME,RTRIM(run_date),113)),'yyyy-MM-dd HH:mm:ss') as datetime) as job_start_datetime ,
			   (run_duration/10000)*60*60 +((run_duration - (run_duration/10000) * 10000)/100) * 60 + (run_duration - (run_duration/100) * 100) as duration_seconds ,
			   run_status,
			   CASE run_status
			   		WHEN 0 THEN 'Failure'
					WHEN 1 THEN 'Success'
					WHEN 2 THEN 'Retry'
					WHEN 3 THEN 'Canceled'
					ELSE 'Unknown'
			   END AS job_status,
			   message,
			   instance_id,
			   step_id AS job_failure_step_number,
			   sql_severity AS job_step_severity,
			   retries_attempted,
			   step_name,
			   sql_message_id
		FROM msdb.dbo.sysjobhistory as myJobHistory WITH (NOLOCK)
		WHERE run_status = 0
	)

	INSERT INTO #Jobfailure (job_id_guid,job_start_time,job_failure_time,failure_message,instance_id,job_failure_step_number,job_step_severity,retries_attempted,step_name,sql_message_id)
	SELECT job_id_guid, job_start_datetime AS job_start_time, DATEADD(SECOND, ISNULL(duration_seconds, 0), job_start_datetime) AS job_failure_time,
		ISNULL(message, '') AS failure_message, instance_id, job_failure_step_number, job_step_severity, retries_attempted, step_name, sql_message_id
	FROM myCTE 
	WHERE myCTE.job_start_datetime > DATEADD(MINUTE, -1 * @minutes_to_monitor, GETDATE());	
	-- Get jobs that failed due to failed steps.
	;WITH CTE_FAILURE_STEP 
	AS (
		SELECT ROW_NUMBER() OVER (PARTITION BY job_id_guid, job_failure_time ORDER BY job_failure_step_number DESC) AS RowNumber,
				job_id_guid,
				job_start_time,
				job_failure_time,
				failure_message,
				instance_id,
				job_failure_step_number,
				job_step_severity,
				retries_attempted,
				step_name,
				sql_message_id
		FROM #Jobfailure
		WHERE job_failure_step_number > 0
	)
	INSERT INTO monitor.JobFailure (JobId, InstanceId, JobStartDatetime, JobFailureDatetime, JobFailureStepNumber, JobFailureStepName, JobFailureMessage, JobFailureStepMessage, JobStepSeverity, JobStepMessageId, RetriesAttempted, IsEmailSent)
	SELECT 
		myJob.JobId,
		myStep.instance_id,
		myJobFailure.job_start_time,
		myStep.job_failure_time,
		myStep.job_failure_step_number,
		myStep.step_name AS job_failure_step_name,
		myJobFailure.failure_message AS Job_failure_message,
		myStep.failure_message AS step_failure_message,
		myStep.job_step_severity,
		myStep.sql_message_id AS job_step_message_id,
		myStep.retries_attempted,
		0 AS IsEmailSent
	FROM #Jobfailure AS myJobFailure
	INNER JOIN monitor.job AS myJob ON myJobFailure.job_id_guid = myJob.JobIdGuid
	INNER JOIN CTE_FAILURE_STEP AS myStep ON myJobFailure.job_id_guid = myStep.job_id_guid AND myJobFailure.job_failure_time = myStep.job_failure_time
	WHERE myStep.RowNumber = 1 AND myJobFailure.job_failure_step_number = 0
		AND myStep.instance_id NOT IN (SELECT InstanceId FROM monitor.JobFailure);
	
	-- Get jobs that failed without any failed steps.
	INSERT INTO monitor.JobFailure (JobId, InstanceId, JobStartDatetime, JobFailureDatetime, JobFailureStepNumber, JobFailureStepName, JobFailureMessage, JobFailureStepMessage, JobStepSeverity, JobStepMessageId, RetriesAttempted, IsEmailSent)
	SELECT 
		myJob.JobId,
		myJobFailure.instance_id,
		myJobFailure.job_start_time,
		myJobFailure.job_failure_time,
		job_failure_step_number AS job_failure_step_number,
		'' AS job_failure_step_name,
		myJobFailure.failure_message,
		'' AS job_step_failure_message,
		-1 AS job_step_severity,
		-1 AS job_step_message_id,
		0 AS retries_attempted,
		0 AS has_email_been_sent_to_operator
	FROM #Jobfailure AS myJobFailure
	LEFT JOIN monitor.job AS myJob ON myJobFailure.job_id_guid = myJob.JobIdGuid
	WHERE job_failure_step_number = 0 
		AND myJobFailure.instance_id NOT IN (SELECT instance_id FROM monitor.JobFailure)
		AND NOT EXISTS (SELECT 1 FROM #Jobfailure AS myJobStep WHERE myJobStep.job_failure_step_number > 0 AND myJobFailure.job_id_guid = myJobStep.job_id_guid AND myJobFailure.job_failure_time = myJobStep.job_failure_time);
	-- Get job steps that failed, but for jobs that succeeded.
	WITH CTE_FAILURE_STEP 
	AS 
	(
		SELECT
			ROW_NUMBER() OVER (PARTITION BY myFailure.job_id_guid, myFailure.job_failure_time ORDER BY myFailure.job_failure_step_number DESC) AS recent_step_rank,
			job_id_guid,
            job_start_time,
            job_failure_time,
            failure_message,
            instance_id,
            job_failure_step_number,
            job_step_severity,
            retries_attempted,
            step_name,
            sql_message_id
		FROM #Jobfailure AS myFailure
		WHERE job_failure_step_number >0
	)
	INSERT INTO monitor.JobFailure (JobId, InstanceId, JobStartDatetime, JobFailureDatetime, JobFailureStepNumber, JobFailureStepName, JobFailureMessage, JobFailureStepMessage, JobStepSeverity, JobStepMessageId, RetriesAttempted, IsEmailSent)
	SELECT
		myJob.JobId,
		myStep.instance_id,
		myStep.job_start_time,
		myStep.job_failure_time,
		myStep.job_failure_step_number,
		myStep.step_name AS job_failure_step_name,
		'' AS job_failure_message,
		myStep.failure_message,
		myStep.job_step_severity,
		myStep.sql_message_id AS job_step_message_id,
		myStep.retries_attempted,
		0 AS has_email_been_sent_to_operator
	FROM CTE_FAILURE_STEP AS myStep
	INNER JOIN monitor.job AS myJob ON myStep.job_id_guid = myJob.JobIdGuid
	WHERE myStep.recent_step_rank = 1
	AND myStep.instance_id NOT IN (SELECT instance_id FROM monitor.JobFailure)
	AND NOT EXISTS (SELECT 1 FROM #Jobfailure AS myJobFailure WHERE job_failure_step_number = 0 AND myJobFailure.job_id_guid = myStep.job_id_guid AND myJobFailure.job_failure_time = myStep.job_failure_time);
	
	DROP TABLE #Jobfailure
END
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_failure', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-05-17', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_failure', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_failure', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_failure', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_failure', NULL, NULL
GO
