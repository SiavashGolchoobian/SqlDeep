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
CREATE PROCEDURE [dbo].[dbasp_monitor_job_activity_send_alert]
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor CURSOR;

	DECLARE @myJobId INT;
	DECLARE @myJobAlertSendSMS VARCHAR(MAX);
	DECLARE @myMessage VARCHAR(4000);
	DECLARE @myEmailMessage VARCHAR(MAX);

	DECLARE @JobActivityID INT;
	DECLARE @myJobName NVARCHAR(100);
	DECLARE @ServerName NVARCHAR(128);
	DECLARE @myJobAlertSendEmail VARCHAR(MAX);
	DECLARE @NewLine VARCHAR(10)
	DECLARE @myDate DATETIME
	DECLARE @myExecutePersianDateTime NVARCHAR(20)

	SET @NewLine = CHAR(10) + CHAR(13)
	SET @myDate = GETDATE()
	SET @myExecutePersianDateTime = dbo.dbafn_miladi2shamsi(@myDate,'/') + ' '+ CAST(DATEPART(HOUR,@myDate) AS VARCHAR(2)) + ':'+ CAST(DATEPART(MINUTE,@myDate) AS VARCHAR(2))

	SET @myCursor = CURSOR FOR 
			SELECT myJobActivity.JobActivityID,myJobActivity.JobName, myJobAlert.SendEmail,myJobAlert.SendSMS
			FROM monitor.JobActivity as myJobActivity WITH(READPAST)
			INNER JOIN monitor.JobAlert AS myJobAlert WITH(READPAST) ON myJobAlert.JobName = myJobActivity.JobName
			WHERE myJobActivity.IsProcessed = 0 
			AND myJobAlert.IsEnabled = 1 
			AND myJobAlert.SendEmail IS NOT NULL
	OPEN @myCursor
	FETCH NEXT FROM @myCursor INTO @JobActivityID, @myJobName, @myJobAlertSendEmail, @myJobAlertSendSMS
	WHILE @@FETCH_STATUS=0
	BEGIN
		SET @ServerName = ISNULL(@@SERVERNAME, CAST(SERVERPROPERTY('ServerName') AS VARCHAR(MAX)));
		SET @myMessage = N'اجرای جاب' + N' '+  @myJobName + N' ' 
		SET @myMessage = @myMessage + N'بر روی سرور' + N' '
		SET @myMessage = @myMessage + REPLACE(REPLACE(@ServerName ,@@SERVICENAME ,''),'\','') +  N' ' 
		SET @myMessage = @myMessage + N'بیش از زمان درنظر گرفته شده است، به طول انجامیده است. ' 
		SET @myMessage = @myMessage + @NewLine + @myExecutePersianDateTime 

		SET @myEmailMessage = 
		'<body dir=rtl>
			<div class=WordSection1>
				<p class=MsoNormal dir=RTL style=''text-align:right;direction:rtl;unicode-bidi:embed''>
					<b><span style=''font-size:12.0pt''>همکار گرامی</span></b>
					</br>
					<b><span style=''font-size:12.0pt''>با سلام و عرض ادب</span></b>
				</p>
				<p class=MsoNormal dir=RTL style=''margin-right:.5in;text-align:right;direction:rtl;unicode-bidi:embed''>
					<span style=''font-size:12.0pt''>' + @myMessage + '</span>
				</p>
			</div>
		</body>
		';

		EXECUTE [dbo].[dbasp_send_notification] 
				@Message = @myMessage
				,@EmailSubject = @myJobName
				,@EmailMessage = @myEmailMessage
				,@RecievePhone = @myJobAlertSendSMS
				,@RecieveEmail = @myJobAlertSendEmail
				,@RecieveCC = NULL
				,@RecieveBCC = NULL
				,@ConfigKey = 'JobFailureKey';

		UPDATE myJobActivity
		SET IsProcessed = 1
		FROM monitor.JobActivity AS myJobActivity
		WHERE JobActivityID = @JobActivityID

		FETCH NEXT FROM @myCursor INTO @JobActivityID, @myJobName, @myJobAlertSendEmail, @myJobAlertSendSMS
	END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_activity_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-06-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_activity_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_activity_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_activity_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_job_activity_send_alert', NULL, NULL
GO
