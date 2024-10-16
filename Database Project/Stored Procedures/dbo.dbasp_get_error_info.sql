-- Stored Procedure

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <01/21/2015>
-- Version:		<3.0.0.0>
-- Description:	<Return Occured Error>
-- Input Parameters:
--	@CustomMessage		'...'	//Any custom message
--	@PrintOutput:		0 or 1	//1 to Print output result or 0 to skip it
--	@ResultsetOutput:	0 or 1	//1 to Return output result grid or 0 to skip it
--	@RaiseError:		0 or 1	//1 to Raise an error or 0 to skip it
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_get_error_info] (
	@CustomMessage nvarchar(256)=Null,
	@PrintOutput bit=1,
	@ResultsetOutput bit=0,
	@RaiseError bit=1,
	@EmailError bit=0,
	@MailTo VARCHAR(255)=NULL
	)
AS
BEGIN
	DECLARE @myNewLine nvarchar(10);
	SET @myNewLine=CHAR(13)+CHAR(10)

	IF @PrintOutput=1
		BEGIN
			DECLARE @PrintMessage nvarchar(4000)
			SET @PrintMessage =
				'------------' + @myNewLine+
				'ErrorNumber: ' + ISNULL(CAST(ERROR_NUMBER() as nvarchar),'') + @myNewLine+
				'ErrorSeverity: ' + ISNULL(CAST(ERROR_SEVERITY() as nvarchar),'') + @myNewLine+
				'ErrorState: ' + ISNULL(CAST(ERROR_STATE() as nvarchar),'') + @myNewLine+
				'ErrorProcedure: ' + ISNULL(CAST(ERROR_PROCEDURE() as nvarchar),'') + @myNewLine+
				'ErrorLine: ' + ISNULL(CAST(ERROR_LINE() as nvarchar),'') + @myNewLine+
				'ErrorMessage: ' + ISNULL(CAST(ERROR_MESSAGE() as nvarchar),'')+ @myNewLine+
				'Information: ' + ISNULL(@CustomMessage,'')
			Print @PrintMessage
		END

	IF @ResultsetOutput=1
		BEGIN
			SELECT
				ERROR_NUMBER() AS ErrorNumber
				,ERROR_SEVERITY() AS ErrorSeverity
				,ERROR_STATE() AS ErrorState
				,ERROR_PROCEDURE() AS ErrorProcedure
				,ERROR_LINE() AS ErrorLine
				,ERROR_MESSAGE() AS ErrorMessage
				,@CustomMessage AS Information;
		END

	IF @RaiseError=1
		BEGIN
			DECLARE @myErrorMessage nvarchar(4000)
			DECLARE @myErrorState int
			SET @myErrorMessage=N'CMS: ' + ERROR_MESSAGE() + @myNewLine+ + 'Information: ' + @CustomMessage
			SET @myErrorState=ERROR_STATE()

			RAISERROR (
				@myErrorMessage, -- Message text.
				11 ,--@ErrorSeverity, -- Severity.
				@myErrorState -- State.
				) WITH LOG;
		END

	IF @EmailError=1 AND @MailTo IS NOT NULL AND EXISTS (SELECT 1 FROM sys.configurations WHERE NAME = 'Database Mail XPs' AND CAST ([value_in_use] AS INT) = 1)
		BEGIN
			DECLARE @EmailMessage nvarchar(4000)
			SET @EmailMessage =
				'------------' + @myNewLine+
				'ErrorNumber: ' + ISNULL(CAST(ERROR_NUMBER() as nvarchar),'') + @myNewLine+
				'ErrorSeverity: ' + ISNULL(CAST(ERROR_SEVERITY() as nvarchar),'') + @myNewLine+
				'ErrorState: ' + ISNULL(CAST(ERROR_STATE() as nvarchar),'') + @myNewLine+
				'ErrorProcedure: ' + ISNULL(CAST(ERROR_PROCEDURE() as nvarchar),'') + @myNewLine+
				'ErrorLine: ' + ISNULL(CAST(ERROR_LINE() as nvarchar),'') + @myNewLine+
				'ErrorMessage: ' + ISNULL(CAST(ERROR_MESSAGE() as nvarchar),'')+ @myNewLine+
				'Information: ' + ISNULL(@CustomMessage,'')

			EXEC msdb.dbo.[sp_send_dbmail] 
				@recipients = @MailTo,
				@subject = @CustomMessage,
				@body = @EmailMessage
		END
END

GO
-- Extended Properties

EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_error_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_error_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_error_info', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_error_info', NULL, NULL
GO