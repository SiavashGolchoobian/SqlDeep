SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Zahra Saffarpour>
-- Create date: <05/09/2019>
-- Version:		<3.0.0.0>
-- Description:	<send notification>
-- Input Parameters:
--	@Message:				
--	@EmailSubject:			
--	@RecievePhone:			
--	@RecieveEmail:	
--	@NotificationKey : 
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_send_notification]
(
	@Message NVARCHAR(4000),
	@EmailSubject NVARCHAR(4000),
	@EmailMessage NVARCHAR(MAX),
	@RecievePhone NVARCHAR(4000),
	@RecieveEmail NVARCHAR(4000),
	@RecieveCC NVARCHAR(4000),
	@RecieveBCC  NVARCHAR(4000),
	@ConfigKey VARCHAR(50) = 'NotificationKey'
)
AS
BEGIN
	SET NOCOUNT ON;
    DECLARE @myAppName NVARCHAR(256);
    DECLARE @myClientIP NVARCHAR(15);
    DECLARE @myErrorMessage NVARCHAR(255);
    DECLARE @myHostname NVARCHAR(128);
    DECLARE @myNotificationConfigId INT;
    DECLARE @myNewLine nvarchar(10);
    DECLARE @myIsPrerequisitesPassed BIT;
	DECLARE @myServerName NVARCHAR(128);
    DECLARE @mySessionId INT;
    DECLARE @myUsername NVARCHAR(128);
    
    --=====Parameters Initialization
	SET @myAppName = CAST(APP_NAME() AS NVARCHAR(256));
	SET @myErrorMessage=N'';
	SET @myHostname = CAST(HOST_NAME() AS NVARCHAR(128));
	SET @myNewLine=CHAR(13)+CHAR(10);
	SET @myIsPrerequisitesPassed=1;
	SET @myServerName = CAST(@@SERVERNAME AS NVARCHAR(128));
	SET @mySessionId = CAST(@@SPID AS INT);
	SET @myUsername = CAST(SUSER_SNAME() AS NVARCHAR(128));

    SELECT @myClientIP = client_net_address
	FROM sys.dm_exec_connections
	WHERE Session_id = @@SPID
    
    SELECT @myNotificationConfigId = RecordId 
    FROM dbo.NotificationConfig
    WHERE ConfigKey = @ConfigKey
	
    --=====Prerequisites Control
    IF @myNotificationConfigId IS NULL
    BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myErrorMessage=@myErrorMessage + N'@ConfigKey is empty or invalid.' + @myNewLine
    END
    IF (@RecievePhone IS NULL AND @RecieveEmail IS NULL)
    BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myErrorMessage=@myErrorMessage + N'@RecievePhone AND @RecieveEmail is empty.' + @myNewLine
    END

    IF (@RecievePhone IS NOT NULL AND @Message IS NULL)
    BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myErrorMessage=@myErrorMessage + N'@Message is empty.' + @myNewLine
    END

    IF (@RecieveEmail IS NOT NULL AND @EmailMessage IS NULL)
    BEGIN
		SET @myIsPrerequisitesPassed=0
		SET @myErrorMessage=@myErrorMessage + N'@EmailMessage is empty.' + @myNewLine
    END
    
    --=====Process Request
    IF(@myIsPrerequisitesPassed = 1)
	BEGIN		
        INSERT INTO Notifications ([ServerName],[SessionId],[AppName],[Username],[Hostname],[ClientIP],[Message],[EmailSubject],[RecievePhone],[RecieveEmail],
                                   [CheckValue],[EmailMessage],[RecieveCC],[RecieveBCC],[NotificationConfigId])
		VALUES (@myServerName, @mySessionId,@myAppName,@myUsername,@myHostname,@myClientIP,@Message,@EmailSubject,@RecievePhone,@RecieveEmail,
				BINARY_CHECKSUM(@myServerName,@mySessionId,@myAppName,@myUsername,@myHostname,@Message,@EmailSubject,@RecievePhone,@RecieveEmail),
				@EmailMessage,@RecieveCC,@RecieveBCC,@myNotificationConfigId)
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_send_notification', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-05-09', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_send_notification', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-31', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_send_notification', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_send_notification', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_send_notification', NULL, NULL
GO
