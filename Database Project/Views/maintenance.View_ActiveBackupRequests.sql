SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE view [maintenance].[View_ActiveBackupRequests] as
SELECT TOP 100 PERCENT
	myBackupRequests.BackupRequestID,
	myBackupRequests.ServerName,
	myBackupRequests.InstanceName,
	myBackupRequests.DBName,
	myBackupRequests.BackupType,
	--[maintenance].[variable_replacement](myBackupRequests.DestVarFolderPath,GETDATE(),myBackupRequests.ServerName,myBackupRequests.InstanceName,myBackupRequests.DBName,myBackupRequests.BackupType,myBackupRequests.RetantionDays) as DestFolderPath,
	--[maintenance].[variable_replacement](myBackupRequests.DestVarFilename,GETDATE(),myBackupRequests.ServerName,myBackupRequests.InstanceName,myBackupRequests.DBName,myBackupRequests.BackupType,myBackupRequests.RetantionDays) as DestFilename,
	DestFolderPath_OverNetwork =
							CASE
								WHEN UPPER(myBackupRequests.ServerName)= UPPER(REPLACE(REPLACE(@@SERVERNAME,@@SERVICENAME,''),'\','')) THEN myBackupRequests.DestVarFolderPath
								ELSE
									CASE LEFT(myBackupRequests.DestVarFolderPath,2)
										WHEN '\\' THEN myBackupRequests.DestVarFolderPath
										ELSE '\\{%SERVER_NAME%}\' + REPLACE(myBackupRequests.DestVarFolderPath,':','$')
									END
								END,
	myBackupRequests.DestVarFolderPath as DestFolderPath,
	myBackupRequests.DestVarFilename as DestFilename,
	myBackupRequests.RetantionDays,
	myBackupRequests.CopyOnlyMode,
	myBackupRequests.ShrinkLogToSizeMB,
	myBackupRequests.TransferSeries
FROM
	[maintenance].[BackupRequests] as myBackupRequests
	INNER JOIN [maintenance].[Lookup_BackupTypes] as myLookup_BackupTypes on myBackupRequests.BackupType=myLookup_BackupTypes.BackupType
WHERE
	myBackupRequests.Enabled=1
Order by 
	ServerName,
	InstanceName,
	DBName








GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'VIEW', N'View_ActiveBackupRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-12', 'SCHEMA', N'maintenance', 'VIEW', N'View_ActiveBackupRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'VIEW', N'View_ActiveBackupRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'VIEW', N'View_ActiveBackupRequests', NULL, NULL
GO
