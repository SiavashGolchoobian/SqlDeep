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

CREATE PROCEDURE [dbo].[dbasp_monitor_job_failure_send_alert]
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor CURSOR;
	DECLARE @email_subject VARCHAR(MAX);
	DECLARE @email_body VARCHAR(MAX);
	DECLARE @job_failure_count INT;

	DECLARE @myJobId INT;
	DECLARE @myJobName NVARCHAR(100);
	DECLARE @myJobAlertSendEmail VARCHAR(MAX);
	DECLARE @myJobAlertSendSMS VARCHAR(MAX);
	DECLARE @ServerName NVARCHAR(128)
	DECLARE @myMessage VARCHAR(MAX);
	DECLARE @NewLine VARCHAR(10)
	DECLARE @myDate DATETIME
	DECLARE @myExecutePersianDateTime NVARCHAR(20)

	SET @NewLine = CHAR(10) + CHAR(13)
	SET @myDate = GETDATE()
	SET @myExecutePersianDateTime = dbo.dbafn_miladi2shamsi(@myDate,'/') + ' '+ CAST(DATEPART(HOUR,@myDate) AS VARCHAR(2)) + ':'+ CAST(DATEPART(MINUTE,@myDate) AS VARCHAR(2))
	SET @myCursor = CURSOR FOR 
					SELECT DISTINCT
							myJob.JobId,
							myJob.JobName,
							myAlert.SendEmail AS job_alert_send_email,
							myAlert.SendSMS AS job_alert_send_sms
					FROM monitor.JobFailure AS myJobFailure
					INNER JOIN monitor.Job AS myJob ON myJob.JobId = myJobFailure.JobId
					INNER JOIN monitor.JobAlert AS myAlert ON myAlert.JobName = myJob.JobName
					WHERE myJobFailure.IsEmailSent = 0
						AND (myAlert.SendEmail IS NOT NULL OR myAlert.SendSMS IS NOT NULL);
	OPEN @myCursor
	FETCH NEXT FROM @myCursor INTO @myJobId, @myJobName, @myJobAlertSendEmail, @myJobAlertSendSMS
	WHILE @@FETCH_STATUS=0
	BEGIN
		SET @ServerName = ISNULL(@@SERVERNAME, CAST(SERVERPROPERTY('ServerName') AS VARCHAR(MAX)));
		SET @myMessage = N'اجرای جاب' + N' '+ @myJobName + N' ' 
		SET @myMessage = @myMessage + N'بر روی سرور'  + N' ' 
		SET @myMessage = @myMessage + REPLACE(REPLACE(@ServerName ,@@SERVICENAME ,''),'\','') +  N' '  
		SET @myMessage = @myMessage + N'با خطا همراه بوده است'
		SET @myMessage = @myMessage + @NewLine + @myExecutePersianDateTime 

		SET @email_subject = 'Failed Job Alert: ' + @ServerName;
		SET @email_body = 'At least one failure has occurred on ' + @ServerName
		
		SELECT @job_failure_count = COUNT(*) 
		FROM monitor.JobFailure AS myJobFailure 
		WHERE myJobFailure.IsEmailSent = 0 
		AND myJobFailure.JobId = @myJobId ;

		SET @email_body = @email_body + ':
			<html><body><table border=1>
			<tr>
				<th colspan="6" bgcolor="#F29C89" align="left">Total Failed Jobs: ' + CAST(@job_failure_count AS VARCHAR(MAX)) + '</th>
			</tr>
			<tr>
				<th bgcolor="#F29C89">Job Name</th>
				<th bgcolor="#F29C89">Server Job Start Time</th>
				<th bgcolor="#F29C89">Server Job Failure Time</th>
				<th bgcolor="#F29C89">Failure Step Name</th>
				<th bgcolor="#F29C89">Job Failure Message</th>
				<th bgcolor="#F29C89">Job Step Failure Message</th>
			</tr>';
		SET @email_body = @email_body + 
							CAST((
									SELECT CAST(@myJobName AS VARCHAR(MAX)) AS 'td', '',
									   		CAST(myJobFailure.JobStartDatetime AS VARCHAR(MAX)) AS 'td', '',
									   		CAST(myJobFailure.JobFailureDatetime AS VARCHAR(MAX)) AS 'td', '',
									   		myJobFailure.JobFailureStepName AS 'td', '',
									   		myJobFailure.JobFailureMessage AS 'td', '',
									   		myJobFailure.JobFailureStepMessage AS 'td'
									FROM monitor.JobFailure AS myJobFailure
									WHERE myJobFailure.IsEmailSent = 0 
									AND myJobFailure.JobId = @myJobId 
									ORDER BY myJobFailure.JobFailureDatetime ASC
									FOR XML PATH('tr'), ELEMENTS
								) AS VARCHAR(MAX));

		SET @email_body = @email_body + '</table></body></html>';
		SET @email_body = REPLACE(@email_body, '<td>', '<td valign="top">');

		EXECUTE [dbo].[dbasp_send_notification] 
				@Message = @myMessage
				,@EmailSubject = @email_subject
				,@EmailMessage = @email_body
				,@RecievePhone = @myJobAlertSendSMS
				,@RecieveEmail = @myJobAlertSendEmail
				,@RecieveCC = NULL
				,@RecieveBCC = NULL
				,@ConfigKey = 'JobFailureKey';

		UPDATE myJobFailure
		SET IsEmailSent = 1
		FROM monitor.JobFailure AS myJobFailure
		WHERE myJobFailure.IsEmailSent = 0 
		AND myJobFailure.JobId = @myJobId

		FETCH NEXT FROM @myCursor INTO @myJobId, @myJobName, @myJobAlertSendEmail, @myJobAlertSendSMS
	END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_failure_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-05-17', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_failure_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_failure_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_failure_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_failure_send_alert', NULL, NULL
GO
