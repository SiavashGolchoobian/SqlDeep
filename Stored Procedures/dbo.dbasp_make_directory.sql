SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <9/25/2013>
-- Version:		<3.0.0.0>
-- Description:	<Check for existing directory path in local device and make it if not exsites>
-- Input Parameters:
--	@DirectoryPath:	'...'
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_make_directory] 
	@DirectoryPath nvarchar(4000)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @folder_exists INT
	DECLARE @file_results TABLE (
								file_exists int,
								file_is_a_directory int,
								parent_directory_exists int
								)
         
	INSERT INTO @file_results (file_exists, file_is_a_directory, parent_directory_exists) EXEC master.dbo.xp_fileexist @DirectoryPath
	SELECT @folder_exists = file_is_a_directory FROM @file_results

	--script to create directory
	IF @folder_exists = 0
		BEGIN
			BEGIN TRY
				print 'Directory is not exists, creating new one'
				EXECUTE master.dbo.xp_create_subdir @DirectoryPath
				print @DirectoryPath +  'created on' + @@servername
			END TRY
			BEGIN CATCH
				DECLARE @CustomMessage nvarchar(255)
				SET @CustomMessage='Creating folder error on ' + @DirectoryPath
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
			END CATCH
		END
		ELSE
			PRINT @DirectoryPath + 'Directory already exists'
END



GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_make_directory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2013-09-25', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_make_directory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_make_directory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_make_directory', NULL, NULL
GO
