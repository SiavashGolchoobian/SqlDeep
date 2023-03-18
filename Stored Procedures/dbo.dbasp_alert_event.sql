SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[dbasp_alert_event]
@AlertType VARCHAR (50)=NULL, @AlertText XML=NULL, @LogAlertToTable BIT=1, @LogAlertToSqlLog BIT=1, @PrintAlertToConsole BIT=1, @ReturnAlertAsResultset BIT=0, @EmailAlert BIT=0, @MailList VARCHAR (255)=NULL
AS
BEGIN
    DECLARE @myAlertTime AS DATETIME;
    DECLARE @myNewLine AS NVARCHAR (10);
    SET @myAlertTime = GETDATE();
    SET @myNewLine = CHAR(13) + CHAR(10);
    SET @AlertType = ISNULL(@AlertType, N'UNKNOWN');
    SET @AlertText = ISNULL(@AlertText, CAST (N'<UNKNOWN/>' AS XML));
    SET @AlertText = CAST (N'<instance_name>' + CAST (@@SERVERNAME AS NVARCHAR (255)) + N'</instance_name>' + @myNewLine + CAST (@AlertText AS NVARCHAR (MAX)) AS XML);
    IF @LogAlertToTable = 1
        BEGIN
            INSERT  INTO [trace].[Events] ([AlertTime], [AlertType], [AlertText])
            VALUES                       (@myAlertTime, @AlertType, @AlertText);
        END
    IF @LogAlertToSqlLog = 1
        BEGIN
            DECLARE @myErrorMessage AS NVARCHAR (4000);
            DECLARE @myErrorState AS INT;
            SET @myErrorMessage = @AlertType + N' on ' + CAST (@myAlertTime AS NVARCHAR (50)) + @myNewLine + +CAST (@AlertText AS NVARCHAR (3600));
            SET @myErrorState = 1;
            RAISERROR (@myErrorMessage, 11, @myErrorState)
                WITH LOG;
        END
    IF @PrintAlertToConsole = 1
        BEGIN
            DECLARE @PrintMessage AS NVARCHAR (4000);
            SET @PrintMessage = '------------' + @myNewLine + 'Alert Type: ' + @AlertType + @myNewLine + 'Alert Text: ' + CAST (@AlertText AS NVARCHAR (3600)) + @myNewLine + 'Alert Time: ' + CAST (@myAlertTime AS NVARCHAR (50));
            PRINT @PrintMessage;
        END
    IF @ReturnAlertAsResultset = 1
        BEGIN
            SELECT @AlertType AS AlertType,
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
            DECLARE @EmailMessage AS NVARCHAR (MAX);
            SET @EmailMessage = 'Alert Type: ' + @AlertType + @myNewLine + 'Alert Text: ' + CAST (@AlertText AS NVARCHAR (MAX)) + @myNewLine + 'Alert Time: ' + CAST (@myAlertTime AS NVARCHAR (50));
            EXECUTE msdb.dbo.[sp_send_dbmail] @recipients = @MailList, @subject = @AlertType, @body = @EmailMessage;
        END
END

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_alert_event', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-03-13', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_alert_event', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-13', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_alert_event', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_alert_event', NULL, NULL
GO
