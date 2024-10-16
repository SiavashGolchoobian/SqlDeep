SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <7/15/2014>
-- Version:		<3.0.0.0>
-- Description:	<Update Primary Backup Catalog>
-- =============================================
CREATE PROCEDURE [maintenance].[Update_BackupCatalogs_Primary]
	(@BackupRequestRef int,@DestinationPath nvarchar(255),@BackupDate datetime,@ExpiredDate date,@FileDate datetime, @FileSize as varchar(100))
AS
BEGIN
	SET NOCOUNT ON;

 MERGE [maintenance].[BackupCatalogs_Primary] AS myTarget 
 USING	(SELECT  
			@BackupRequestRef AS BackupRequestRef,
			@DestinationPath AS DestinationPath,
			@BackupDate AS BackupDate,
			@ExpiredDate AS ExpiredDate,
			@FileDate AS FileDate,
			@FileSize AS FileSize
		) AS mySource 
 ON (myTarget.BackupRequestRef=mySource.BackupRequestRef AND myTarget.DestinationPath=mySource.DestinationPath) 
 WHEN MATCHED THEN 
	UPDATE SET BackupDate=@BackupDate , ExpiredDate=@ExpiredDate , FileSize=@FileSize , FileDate=@FileDate , LogDate=GETDATE()
 WHEN NOT MATCHED THEN 
	INSERT (BackupRequestRef, 
			DestinationPath, 
			BackupDate, 
			ExpiredDate,
			FileSize,
			FileDate
			) 
	VALUES ( 
			@BackupRequestRef,
			@DestinationPath,
			@BackupDate,
			@ExpiredDate,
			@FileSize,
			@FileDate
			);
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'PROCEDURE', N'Update_BackupCatalogs_Primary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-15', 'SCHEMA', N'maintenance', 'PROCEDURE', N'Update_BackupCatalogs_Primary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'PROCEDURE', N'Update_BackupCatalogs_Primary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'PROCEDURE', N'Update_BackupCatalogs_Primary', NULL, NULL
GO
