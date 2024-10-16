SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <7/15/2014>
-- Version:		<3.0.0.0>
-- Description:	<Mark Primary Backup Catalog Record as Deleted>
-- =============================================
CREATE PROCEDURE [maintenance].[MarkDeleted_BackupCatalogs_Primary]
	(@PrimaryID int)
	--(@DestinationPath nvarchar(255),@BackupRequestRef int)
AS
BEGIN
	SET NOCOUNT ON;

UPDATE [maintenance].[BackupCatalogs_Primary] SET 
	Deleted=1, 
	LogDate=GetDate()  
WHERE	PrimaryID=@PrimaryID
--WHERE BackupRequestRef=@BackupRequestRef AND DestinationPath=@DestinationPath
END



GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'PROCEDURE', N'MarkDeleted_BackupCatalogs_Primary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-15', 'SCHEMA', N'maintenance', 'PROCEDURE', N'MarkDeleted_BackupCatalogs_Primary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'PROCEDURE', N'MarkDeleted_BackupCatalogs_Primary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'PROCEDURE', N'MarkDeleted_BackupCatalogs_Primary', NULL, NULL
GO
