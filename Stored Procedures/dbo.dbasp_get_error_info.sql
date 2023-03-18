SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[dbasp_get_error_info]
@CustomMessage NVARCHAR (256)=NULL, @PrintOutput BIT=1, @ResultsetOutput BIT=0, @RaiseError BIT=1, @EmailError BIT=0, @MailTo VARCHAR (255)=NULL
AS
BEGIN
    DECLARE @myNewLine AS NVARCHAR (10);
    SET @myNewLine = CHAR(13) + CHAR(10);
    IF @PrintOutput = 1
        BEGIN
            DECLARE @PrintMessage AS NVARCHAR (4000);
            SET @PrintMessage = '------------' + @myNewLine + 'ErrorNumber: ' + ISNULL(CAST (ERROR_NUMBER() AS NVARCHAR), '') + @myNewLine + 'ErrorSeverity: ' + ISNULL(CAST (ERROR_SEVERITY() AS NVARCHAR), '') + @myNewLine + 'ErrorState: ' + ISNULL(CAST (ERROR_STATE() AS NVARCHAR), '') + @myNewLine + 'ErrorProcedure: ' + ISNULL(CAST (ERROR_PROCEDURE() AS NVARCHAR), '') + @myNewLine + 'ErrorLine: ' + ISNULL(CAST (ERROR_LINE() AS NVARCHAR), '') + @myNewLine + 'ErrorMessage: ' + ISNULL(CAST (ERROR_MESSAGE() AS NVARCHAR), '') + @myNewLine + 'Information: ' + ISNULL(@CustomMessage, '');
            PRINT @PrintMessage;
        END
    IF @ResultsetOutput = 1
        BEGIN
            SELECT ERROR_NUMBER() AS ErrorNumber,
                   ERROR_SEVERITY() AS ErrorSeverity,
                   ERROR_STATE() AS ErrorState,
                   ERROR_PROCEDURE() AS ErrorProcedure,
                   ERROR_LINE() AS ErrorLine,
                   ERROR_MESSAGE() AS ErrorMessage,
                   @CustomMessage AS Information;
        END
    IF @RaiseError = 1
        BEGIN
            DECLARE @myErrorMessage AS NVARCHAR (4000);
            DECLARE @myErrorState AS INT;
            SET @myErrorMessage = N'CMS: ' + ERROR_MESSAGE() + @myNewLine + +'Information: ' + @CustomMessage;
            SET @myErrorState = ERROR_STATE();
            RAISERROR (@myErrorMessage, 11, @myErrorState)
                WITH LOG;
        END
    IF @EmailError = 1
       AND @MailTo IS NOT NULL
       AND EXISTS (SELECT 1
                   FROM   sys.configurations
                   WHERE  NAME = 'Database Mail XPs'
                          AND CAST ([value_in_use] AS INT) = 1)
        BEGIN
            DECLARE @EmailMessage AS NVARCHAR (4000);
            SET @EmailMessage = '------------' + @myNewLine + 'ErrorNumber: ' + ISNULL(CAST (ERROR_NUMBER() AS NVARCHAR), '') + @myNewLine + 'ErrorSeverity: ' + ISNULL(CAST (ERROR_SEVERITY() AS NVARCHAR), '') + @myNewLine + 'ErrorState: ' + ISNULL(CAST (ERROR_STATE() AS NVARCHAR), '') + @myNewLine + 'ErrorProcedure: ' + ISNULL(CAST (ERROR_PROCEDURE() AS NVARCHAR), '') + @myNewLine + 'ErrorLine: ' + ISNULL(CAST (ERROR_LINE() AS NVARCHAR), '') + @myNewLine + 'ErrorMessage: ' + ISNULL(CAST (ERROR_MESSAGE() AS NVARCHAR), '') + @myNewLine + 'Information: ' + ISNULL(@CustomMessage, '');
            EXECUTE msdb.dbo.[sp_send_dbmail] @recipients = @MailTo, @subject = @CustomMessage, @body = @EmailMessage;
        END
END

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_error_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_error_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_error_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_error_info', NULL, NULL
GO
