SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <2/30/2014>
-- Version:		<3.0.0.0>
-- Description:	<Verify backup files existence in DBA backup catalog>
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_verifybackupcatalog]
--WITH EXECUTE AS 'sqldeep\dbadmin'
AS
BEGIN
	SELECT TOP 100 PERCENT
		myBackups.*
		,dbo.dbafn_file_existed(myBackups.DestinationPath) AS FileVerified
	FROM
		[maintenance].[BackupCatalogs_Primary] as myBackups
	WHERE
		myBackups.Deleted=0
	ORDER BY
		myBackups.LogDate Desc
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_verifybackupcatalog', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-02-30', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_verifybackupcatalog', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_verifybackupcatalog', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_verifybackupcatalog', NULL, NULL
GO
