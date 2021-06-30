SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <30/6/2021>
-- Version:		<3.0.0.0>
-- Description:	<Enable or Disable Database Mail>
-- Input Parameters:
--	@Enabled:	Database mail status
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_database_mail]
	(@Enabled BIT = 0)
AS
BEGIN
	IF EXISTS (SELECT 1 FROM [sys].[configurations] WHERE [NAME] = 'Database Mail XPs' AND [VALUE] <> @Enabled)
	BEGIN
		PRINT 'Set Database Mail XPs'
		EXEC sp_configure 'show advanced options', 1;  
		RECONFIGURE
		IF @Enabled=1
			EXEC sp_configure 'Database Mail XPs', 1;  
		IF @Enabled=0
			EXEC sp_configure 'Database Mail XPs', 0;  
	  RECONFIGURE  
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_database_mail', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2021-06-30', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_database_mail', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-06-30', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_database_mail', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_database_mail', NULL, NULL
GO
