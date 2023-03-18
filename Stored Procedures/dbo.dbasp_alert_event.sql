-- Stored Procedure

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <03/13/2017>
-- Version:		<3.0.0.0>
-- Description:	<Send or Save messages as alerts>
-- Input Parameters:
--	@AlertType:				'...'	//Any custom message as subject or category
--	@AlertText				'...'	//Any custom xml message as detail description
--	@LogAlertToTable		0 or 1	//1 to Log message in trace.Events table or 0 to skip it
--	@LogAlertToSqlLog:		0 or 1	//1 to Raise an error on SQL log or 0 to skip it
--	@PrintAlertToConsole:	0 or 1	//1 to Print output result or 0 to skip it
--	@ReturnAlertAsResultset:0 or 1	//1 to Return output result grid or 0 to skip it
--	@EmailAlert:			0 or 1	//1 to Email alert to @MailList or 0 to skip it
--	@MailList:				'...'	//mail list with semicolon seperated list for @EmailAlert true condition
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_alert_event] (
	@AlertType VARCHAR(50)=Null,
	@AlertText XML=Null,
	@LogAlertToTable BIT=1,
	@LogAlertToSqlLog BIT=1,
	@PrintAlertToConsole BIT=1,
	@ReturnAlertAsResultset BIT=0,
	@EmailAlert BIT=0,
	@MailList VARCHAR(255)=NULL
	)
AS
BEGIN
	DECLARE @myAlertTime DATETIME;
	DECLARE @myNewLine nvarchar(10);
	SET @myAlertTime=GETDATE()
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @AlertType=ISNULL(@AlertType,N'UNKNOWN')
	SET @AlertText=ISNULL(@AlertText,CAST(N'<UNKNOWN/>' AS XML))
	SET @AlertText=CAST(N'<instance_name>' + CAST(@@SERVERNAME AS NVARCHAR(255)) + N'</instance_name>' + @myNewLine + CAST(@AlertText AS NVARCHAR(MAX)) AS XML)
	--==============================================
	--====================Log to table
	--==============================================
	IF @LogAlertToTable=1
	BEGIN
		INSERT INTO [trace].[Events]([AlertTime],[AlertType],[AlertText])
		VALUES (@myAlertTime,@AlertType,@AlertText)
	END
	--==============================================
	--====================Log to SQL Server log
	--==============================================
	IF @LogAlertToSqlLog=1
	BEGIN
		DECLARE @myErrorMessage nvarchar(4000)
		DECLARE @myErrorState int
		SET @myErrorMessage=@AlertType + N' on ' + CAST(@myAlertTime AS NVARCHAR(50)) + @myNewLine+ + CAST(@AlertText AS NVARCHAR(3600))
		SET @myErrorState=1

		RAISERROR (
			@myErrorMessage, -- Message text.
			11 ,--@ErrorSeverity, -- Severity.
			@myErrorState -- State.
			) WITH LOG;
	END
	--==============================================
	--====================Print to console
	--==============================================
	IF @PrintAlertToConsole=1
	BEGIN
		DECLARE @PrintMessage nvarchar(4000)
		SET @PrintMessage =
			'------------' + @myNewLine+
			'Alert Type: ' + @AlertType + @myNewLine+
			'Alert Text: ' + CAST(@AlertText AS NVARCHAR(3600)) + @myNewLine+
			'Alert Time: ' + CAST(@myAlertTime AS NVARCHAR(50))
		Print @PrintMessage
	END
	--==============================================
	--====================Return Alert As Resultset
	--==============================================
	IF @ReturnAlertAsResultset=1
	BEGIN
		SELECT
			@AlertType AS AlertType,
			@AlertText AS AlerText,
			@myAlertTime AS AkerTime;
	END

	IF @EmailAlert = 1
       AND @MailList IS NOT NULL
       AND EXISTS (SELECT 1
                   FROM   [master].[sys].[configurations]
                   WHERE  [name] = 'Database Mail XPs'
                          AND CAST ([value_in_use] AS INT) = 1)
	BEGIN
		DECLARE @EmailMessage NVARCHAR(MAX)
		SET @EmailMessage =
			'Alert Type: ' + @AlertType + @myNewLine+
			'Alert Text: ' + CAST(@AlertText AS NVARCHAR(MAX)) + @myNewLine+
			'Alert Time: ' + CAST(@myAlertTime AS NVARCHAR(50))

		EXEC msdb.dbo.[sp_send_dbmail] 
			@recipients = @MailList,
			@subject = @AlertType,
			@body = @EmailMessage
	END
END

GO
-- Extended Properties

EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_alert_event', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-03-13', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_alert_event', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-13', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_alert_event', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_alert_event', NULL, NULL
GO