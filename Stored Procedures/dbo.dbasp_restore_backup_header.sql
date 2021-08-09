SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[dbasp_restore_backup_header] 
(
	@Filename NVARCHAR(255)
)
AS
BEGIN
	DECLARE @mySQL NVARCHAR(MAX), @RecordId BIGINT
	SET @mySQL = CAST(N'' AS NVARCHAR(MAX))
	SET @mySQL = @mySQL + CAST('RESTORE HEADERONLY FROM DISK = N''' AS NVARCHAR(MAX)) + CAST(@filename AS NVARCHAR(MAX)) + CAST(N'''' AS NVARCHAR(MAX))

	INSERT INTO dbo.RestoreHeaderOnly (BackupName,BackupDescription,BackupType,ExpirationDate,Compressed,Position,DeviceType,UserName,ServerName,DatabaseName,DatabaseVersion,
		DatabaseCreationDate,BackupSize,FirstLSN,LastLSN,CheckpointLSN,DatabaseBackupLSN,BackupStartDate,BackupFinishDate,SortOrder,CodePage,UnicodeLocaleId,UnicodeComparisonStyle,
		CompatibilityLevel,SoftwareVendorId,SoftwareVersionMajor,SoftwareVersionMinor,SoftwareVersionBuild,MachineName,Flags,BindingID,RecoveryForkID,Collation,FamilyGUID,
		HasBulkLoggedData,IsSnapshot,IsReadOnly,IsSingleUser,HasBackupChecksums,IsDamaged,BeginsLogChain,HasIncompleteMetaData,IsForceOffline,IsCopyOnly,FirstRecoveryForkID,ForkPointLSN,
		RecoveryModel,DifferentialBaseLSN,DifferentialBaseGUID,BackupTypeDescription,BackupSetGUID,CompressedBackupSize,containment,KeyAlgorithm,EncryptorThumbprint,EncryptorType)
	EXECUTE sp_executesql @mySQL

	SET @RecordId = @@IDENTITY
	UPDATE dbo.RestoreHeaderOnly 
	SET
		FileFullName = @Filename
	WHERE 
		RecordId = @RecordId
END
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_restore_backup_header', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-12-10', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_restore_backup_header', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_restore_backup_header', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_restore_backup_header', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_restore_backup_header', NULL, NULL
GO
