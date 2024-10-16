SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE view [maintenance].[View_ActiveFileBaseRequests]
as
SELECT TOP 100 PERCENT
	myPrimaryCatalog.PrimaryID as PrimaryRef,
	myFileBaseRequests.TransferSeries as TransferSeries,
	myFileBaseRequests.ScenarioName as ScenarioName,
	myTimeBaseScenarioRules.RuleID as ScenarioRuleRef,
	SourcePath_OverNetwork =
							CASE
								WHEN UPPER(myBackupRequests.ServerName)= UPPER(REPLACE(REPLACE(@@SERVERNAME,@@SERVICENAME,''),'\','')) THEN myPrimaryCatalog.DestinationPath
								ELSE
									CASE LEFT(myPrimaryCatalog.DestinationPath,2)
										WHEN '\\' THEN myPrimaryCatalog.DestinationPath
										ELSE '\\' + myBackupRequests.ServerName + '\' + REPLACE(myPrimaryCatalog.DestinationPath,':','$')
									END
								END,
	myPrimaryCatalog.DestinationPath as SourcePath,
	--myTimeBaseScenarioRules.DestConnectionString,
	[maintenance].[variable_replacement](myTimeBaseScenarioRules.RuleTrueCondition,myPrimaryCatalog.BackupDate,myBackupRequests.ServerName,myBackupRequests.InstanceName,myBackupRequests.DBName,myBackupRequests.BackupType,myBackupRequests.RetantionDays,myPrimaryCatalog.DestinationPath) as RuleTrueCondition,
	--DestFolderPath_OverNetwork = CASE LEFT(myTimeBaseScenarioRules.DestVarFolderPath,2)
	--							WHEN '\\' THEN [maintenance].[variable_replacement](myTimeBaseScenarioRules.DestVarFolderPath,myPrimaryCatalog.BackupDate,myBackupRequests.ServerName,myBackupRequests.InstanceName,myBackupRequests.DBName,myBackupRequests.BackupType,myBackupRequests.RetantionDays)
	--							ELSE [maintenance].[variable_replacement]('\\' + myBackupRequests.ServerName + '\' + REPLACE(myTimeBaseScenarioRules.DestVarFolderPath,':','$'),myPrimaryCatalog.BackupDate,myBackupRequests.ServerName,myBackupRequests.InstanceName,myBackupRequests.DBName,myBackupRequests.BackupType,myBackupRequests.RetantionDays)
	--						END,
	[maintenance].[variable_replacement](myTimeBaseScenarioRules.DestVarFolderPath,myPrimaryCatalog.BackupDate,myBackupRequests.ServerName,myBackupRequests.InstanceName,myBackupRequests.DBName,myBackupRequests.BackupType,myBackupRequests.RetantionDays,myPrimaryCatalog.DestinationPath) as DestFolderPath,
	[maintenance].[variable_replacement](myTimeBaseScenarioRules.DestVarFilename,myPrimaryCatalog.BackupDate,myBackupRequests.ServerName,myBackupRequests.InstanceName,myBackupRequests.DBName,myBackupRequests.BackupType,myBackupRequests.RetantionDays,myPrimaryCatalog.DestinationPath) as DestFilename,
	([maintenance].[variable_replacement](myTimeBaseScenarioRules.DestVarFolderPath,myPrimaryCatalog.BackupDate,myBackupRequests.ServerName,myBackupRequests.InstanceName,myBackupRequests.DBName,myBackupRequests.BackupType,myBackupRequests.RetantionDays,myPrimaryCatalog.DestinationPath)
		+ CASE UPPER(ISNULL(myConnection.[Type],'Local')) 
			WHEN UPPER('SCP') THEN '/' 
			WHEN UPPER('UNC') THEN '\' 
			WHEN UPPER('LOCAL') THEN '\' 
			ELSE '\' 
		  END 
		+ [maintenance].[variable_replacement](myTimeBaseScenarioRules.DestVarFilename,myPrimaryCatalog.BackupDate,myBackupRequests.ServerName,myBackupRequests.InstanceName,myBackupRequests.DBName,myBackupRequests.BackupType,myBackupRequests.RetantionDays,myPrimaryCatalog.DestinationPath)) as DestFilePath,
	DATEADD(DAY,Cast([maintenance].[variable_replacement](myTimeBaseScenarioRules.RetantionDays,myPrimaryCatalog.BackupDate,myBackupRequests.ServerName,myBackupRequests.InstanceName,myBackupRequests.DBName,myBackupRequests.BackupType,myBackupRequests.RetantionDays,myPrimaryCatalog.DestinationPath) as int),myPrimaryCatalog.BackupDate) as ExpiredDate,
	myTimeBaseScenarioRules.ExistenceCheck,
	ISNULL(myConnection.[Type],'LOCAL') as cn_type,
	ISNULL(myConnection.Host,'')  as cn_host,
	ISNULL(myConnection.Port,0)  as cn_port,
	ISNULL(myConnection.SshHostKey,'')  as cn_sshhostkey,
	ISNULL(myConnection.UserName,'')  as cn_username,
	ISNULL(myConnection.[Password],'')  as cn_password
FROM
	[maintenance].[BackupCatalogs_Primary] as myPrimaryCatalog
	INNER JOIN [maintenance].[FileBaseRequests] as myFileBaseRequests on myPrimaryCatalog.BackupRequestRef=myFileBaseRequests.BackupRequestRef
	INNER JOIN [maintenance].[BackupRequests] as myBackupRequests on myFileBaseRequests.BackupRequestRef=myBackupRequests.BackupRequestID
	INNER JOIN [maintenance].[TimeBaseScenarios] as myTimeBaseScenario on myFileBaseRequests.ScenarioName=myTimeBaseScenario.ScenarioName
	INNER JOIN [maintenance].[TimeBaseScenarioRules] as myTimeBaseScenarioRules on myTimeBaseScenario.ScenarioName=myTimeBaseScenarioRules.ScenarioName
	CROSS APPLY [maintenance].[connection_translator] (myTimeBaseScenarioRules.DestConnectionString) as myConnection
WHERE
	myFileBaseRequests.Enabled=1
	and myTimeBaseScenario.Enabled=1
	and myTimeBaseScenarioRules.Enabled=1
	and myPrimaryCatalog.Deleted=0
Order by 
	myBackupRequests.ServerName,
	myBackupRequests.InstanceName,
	myBackupRequests.DBName,
	myTimeBaseScenarioRules.ScenarioName,
	myTimeBaseScenarioRules.RuleID,
	myPrimaryCatalog.BackupDate desc
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'VIEW', N'View_ActiveFileBaseRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-12', 'SCHEMA', N'maintenance', 'VIEW', N'View_ActiveFileBaseRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'VIEW', N'View_ActiveFileBaseRequests', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'VIEW', N'View_ActiveFileBaseRequests', NULL, NULL
GO
