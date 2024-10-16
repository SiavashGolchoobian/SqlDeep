SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/26/2015>
-- Version:		<3.0.0.0>
-- Description:	<delete expired backups from local disk>
-- Input Parameters:
--	@BackupExtension:	'xxx' //File extension of backup files
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_delete_expired_backups] 
	@BackupExtension varchar(3) = 'bak'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor
	DECLARE @ExpiredDate as Date
	DECLARE @CurrentFolderPath varchar(255)
	DECLARE @ReturnValue bit;

	SET @ReturnValue=CAST(0 as bit)	--0 is OK and 1 is Error
	SET @myCursor=CURSOR For
		SELECT	MAX(physical_device_name) AS mediaset_filelocation,
				Max(Backupset.expiration_date) as lastexpiration_date
		FROM	msdb.dbo.backupset AS Backupset 
				INNER JOIN msdb.dbo.backupmediaset AS Mediaset on Backupset.media_set_id=Mediaset.media_set_id 
				INNER JOIN msdb.dbo.backupmediafamily AS MediaFamily ON MediaFamily.media_set_id = Mediaset.media_set_id
		WHERE	NOT Mediaset.name IS NULL AND
				(CONVERT(VARCHAR(10), Backupset.expiration_date, 111) < CONVERT(VARCHAR(10), GETDATE(), 111))
		GROUP BY MediaFamily.media_family_id
		ORDER BY Max(Backupset.expiration_date) desc

	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @CurrentFolderPath,@ExpiredDate
			WHILE @@FETCH_STATUS=0
			BEGIN
				If (not @CurrentFolderPath is null)
					BEGIN
						IF [dbo].dbafn_file_existed(@CurrentFolderPath)=1
							BEGIN
								--=====Start of Removing File
								BEGIN TRY
									EXECUTE master.dbo.xp_delete_file 0,@CurrentFolderPath,@BackupExtension,@ExpiredDate,0
								END TRY
								BEGIN CATCH
									DECLARE @CustomMessage nvarchar(255)
									SET @CustomMessage='Delete expired backup error on ' + CAST(@CurrentFolderPath as nvarchar)
									EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
									SET @ReturnValue=CAST(1 as bit)	--0 is OK and 1 is Error
								END CATCH
								--=====End of Removing File
							END
					END
				FETCH NEXT FROM @myCursor INTO @CurrentFolderPath,@ExpiredDate
			END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
	
	Return @ReturnValue
	--EXEC msdb.dbo.sp_delete_backuphistory @oldest_date=@Backup_Start_Date
END

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_delete_expired_backups', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-26', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_delete_expired_backups', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-07-23', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_delete_expired_backups', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.1', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_delete_expired_backups', NULL, NULL
GO
