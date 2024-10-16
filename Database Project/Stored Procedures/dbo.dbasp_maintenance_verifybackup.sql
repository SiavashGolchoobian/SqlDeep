SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <02/12/2014>
-- Version:		<3.0.0.0>
-- Description:	<Verify backupset file>
-- Input Parameters:
--	@DatabaseName:	'...' //any valid database name
--	@BackupSetName:	'...'
--	@FileAddress:	'...'
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_verifybackup]
	-- Add the parameters for the stored procedure here
	@DatabaseName  nvarchar(512),
	@BackupSetName nvarchar(128),
	@FileAddress NVARCHAR(4000)
AS
BEGIN

	SET NOCOUNT ON;
	DECLARE @myPosition INT;
	
	SET @myPosition=0
	Select @myPosition=CAST(ISNULL(position,0) as int) from msdb.dbo.backupset where database_name=@DatabaseName AND name=@BackupSetName

	RESTORE VERIFYONLY FROM DISK = @FileAddress 
	WITH FILE = @myPosition
		, NOUNLOAD
		, NOREWIND
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_verifybackup', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-02-12', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_verifybackup', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_verifybackup', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_verifybackup', NULL, NULL
GO
