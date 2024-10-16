SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE view [maintenance].[View_ExpiredFiles]
as
SELECT TOP 100 PERCENT
	CatalogName,
	--ID,
	ISNULL(cn_type,'LOCAL') AS cn_type,
	ISNULL(cn_host,'') AS cn_host,
	ISNULL(cn_port,0) AS cn_port,
	ISNULL(cn_sshhostkey,'') AS cn_sshhostkey,
	ISNULL(cn_username,'') AS cn_username,
	ISNULL(cn_password,'') AS cn_password,
	DestinationPath,
	ID
FROM
	(
	SELECT
		Cast('Secondary' as nvarchar(50)) as CatalogName,
		mySecondaryCatalog.SecondaryID as ID,
		CAST(myConnection.[Type] as nvarchar(50)) as cn_type,
		myConnection.Host as cn_host,
		myConnection.Port as cn_port,
		myConnection.SshHostKey as cn_sshhostkey,
		myConnection.UserName as cn_username,
		myConnection.Password as cn_password,
		mySecondaryCatalog.DestinationPath
	FROM
		[maintenance].[BackupCatalogs_Secondary] as mySecondaryCatalog
		INNER JOIN [maintenance].[TimeBaseScenarioRules] as myTimeBaseScenarioRules on mySecondaryCatalog.ScenarioName=myTimeBaseScenarioRules.ScenarioName AND mySecondaryCatalog.ScenarioRuleRef=myTimeBaseScenarioRules.RuleID
		CROSS APPLY [maintenance].[connection_translator] (myTimeBaseScenarioRules.DestConnectionString) as myConnection
	WHERE
		mySecondaryCatalog.Deleted=0
		and DATEADD(day,1,mySecondaryCatalog.ExpiredDate) <= CAST(getdate() as DATE)
	UNION
	SELECT
		CAST('Primary' as nvarchar(50)) as CatalogName,
		myPrimaryCatalog.PrimaryID as ID,
		CAST('LOCAL' as nvarchar(50)) as cn_type,
		NULL as cn_host,
		NULL as cn_port,
		NULL as cn_sshhostkey,
		NULL as cn_username,
		NULL as cn_password,
		myPrimaryCatalog.DestinationPath
	FROM
		[maintenance].[BackupCatalogs_Primary] as myPrimaryCatalog
	WHERE
		myPrimaryCatalog.Deleted=0
		and DATEADD(day,1,myPrimaryCatalog.ExpiredDate) <= CAST(getdate() as DATE)
	) AS myList
Order by 
	CatalogName,
	cn_type,
	cn_host,
	myList.DestinationPath desc


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'VIEW', N'View_ExpiredFiles', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-22', 'SCHEMA', N'maintenance', 'VIEW', N'View_ExpiredFiles', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'VIEW', N'View_ExpiredFiles', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'VIEW', N'View_ExpiredFiles', NULL, NULL
GO
