SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <7/15/2014>
-- Version:		<3.0.0.0>
-- Description:	<Update Secondary Backup Catalog>
-- =============================================
CREATE PROCEDURE [maintenance].[Update_BackupCatalogs_Secondary]
	(@PrimaryRef int,@ScenarioName nvarchar(255),@ScenarioRuleRef int,@DestinationPath nvarchar(255),@ExpiredDate date, @FileDate datetime, @FileSize as varchar(100))
AS
BEGIN
	SET NOCOUNT ON;

 MERGE [maintenance].[BackupCatalogs_Secondary] AS myTarget 
 USING	(SELECT  
			@PrimaryRef AS PrimaryRef,
			@ScenarioName AS ScenarioName,
			@ScenarioRuleRef AS ScenarioRuleRef,
			@DestinationPath AS DestinationPath,
			@ExpiredDate AS ExpiredDate,
			@FileDate AS FileDate,
			@FileSize AS FileSize
		) AS mySource 
 ON (myTarget.DestinationPath=mySource.DestinationPath AND myTarget.PrimaryRef=mySource.PrimaryRef)
 WHEN MATCHED THEN 
	UPDATE SET ScenarioName=@ScenarioName, ScenarioRuleRef=@ScenarioRuleRef,
			   ExpiredDate=@ExpiredDate , FileSize=@FileSize , FileDate=@FileDate , LogDate=GETDATE() 
 WHEN NOT MATCHED THEN 
	INSERT (PrimaryRef, 
			ScenarioName,
			ScenarioRuleRef,
			DestinationPath, 
			ExpiredDate,
			FileSize,
			FileDate
			) 
	VALUES ( 
			@PrimaryRef,
			@ScenarioName,
			@ScenarioRuleRef,
			@DestinationPath,
			@ExpiredDate,
			@FileSize,
			@FileDate
			);
END



GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'PROCEDURE', N'Update_BackupCatalogs_Secondary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-15', 'SCHEMA', N'maintenance', 'PROCEDURE', N'Update_BackupCatalogs_Secondary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'PROCEDURE', N'Update_BackupCatalogs_Secondary', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'PROCEDURE', N'Update_BackupCatalogs_Secondary', NULL, NULL
GO
