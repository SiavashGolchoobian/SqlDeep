SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[dbasp_monitor_alwayson_data_loss_send_alert]
(
	@EstimateDataLossMinute INT,
	@NotificationPhone VARCHAR(128)
)
AS
BEGIN
	DECLARE @NewLine VARCHAR(10)
	DECLARE @myDate DATETIME
	DECLARE @myExecutePersianDateTime NVARCHAR(20)

	SET @NewLine = CHAR(10) + CHAR(13)
	SET @myDate = GETDATE()
	SET @myExecutePersianDateTime = dbo.dbafn_miladi2shamsi(@myDate,'/') + ' '+ CAST(DATEPART(HOUR,@myDate) AS VARCHAR(2)) + ':'+ CAST(DATEPART(MINUTE,@myDate) AS VARCHAR(2))

	DROP TABLE IF EXISTS #Monitoring
	;WITH AG_Stats
	AS 
	(
		SELECT myAvailabilityReplica.replica_server_name,
			   myHadrAvailabilityReplicaState.role_desc,
			   myHadrAvailabilityReplicaState.connected_state_desc,
			   DB_NAME(myHadrDatabaseReplica.database_id) [DBName],
			   myHadrDatabaseReplica.last_commit_time,
			   CASE myHadrAvailabilityReplicaState.connected_state WHEN 0 THEN 'Disconnected' WHEN 1 THEN 'Connected' ELSE '' END as ConnectionState
		FROM master.sys.dm_hadr_database_replica_states AS myHadrDatabaseReplica
		INNER JOIN master.sys.availability_replicas AS myAvailabilityReplica ON myHadrDatabaseReplica.replica_id = myAvailabilityReplica.replica_id
		INNER JOIN master.sys.dm_hadr_availability_replica_states AS myHadrAvailabilityReplicaState ON myAvailabilityReplica.group_id = myHadrAvailabilityReplicaState.group_id 
																									  AND myAvailabilityReplica.replica_id = myHadrAvailabilityReplicaState.replica_id
	), 
	Primary_CommitTime
	AS 
	(	SELECT replica_server_name, DBName, connected_state_desc, last_commit_time
		FROM AG_Stats
		WHERE role_desc = 'PRIMARY'
	),
	Secondary_CommitTime
	AS 
	(
		SELECT replica_server_name, DBName, connected_state_desc, last_commit_time
		FROM AG_Stats
		WHERE role_desc = 'SECONDARY'
	),
	Monitoring
	AS
	(
		SELECT myPrimary.replica_server_name AS [primary],
			   myPrimary.[DBName] AS [DatabaseName],
			   myPrimary.connected_state_desc AS primary_connected_state,
			   mySecondary.replica_server_name [secondary],
			   mySecondary.connected_state_desc AS secondary_connected_state,
			   myPrimary.last_commit_time AS primary_last_commit_time,
			   mySecondary.last_commit_time AS secondary_last_commit_time,
			   DATEDIFF(SECOND, mySecondary.last_commit_time, myPrimary.last_commit_time) AS Estimated_data_loss_second
		FROM Primary_CommitTime AS myPrimary
		LEFT JOIN Secondary_CommitTime AS mySecondary ON mySecondary.[DBName] = myPrimary.[DBName]
	)
	SELECT [primary],
		   DatabaseName,
		   primary_connected_state,
		   secondary,
		   secondary_connected_state,
		   primary_last_commit_time,
		   secondary_last_commit_time,
		   Estimated_data_loss_second,
		   CAST(CAST(DATEADD(SECOND, Estimated_data_loss_second, '00:00:00') AS TIME) AS VARCHAR(8)) AS Estimated_data_loss	   ,
		   'The data is not synchronized to the secondary replica since ' + CAST(CAST(DATEADD(SECOND, Estimated_data_loss_second, '00:00:00') AS TIME) AS VARCHAR(8)) 
			+'. Affected database(s): ' + DatabaseName + @NewLine + @myExecutePersianDateTime AS Message
	INTO #Monitoring
	FROM Monitoring
	WHERE Estimated_data_loss_second >= (@EstimateDataLossMinute*60)

	DECLARE @myMessage NVARCHAR(4000)

	DECLARE myCursor CURSOR FOR
		SELECT Message FROM #Monitoring
	OPEN myCursor
	FETCH NEXT FROM myCursor INTO @myMessage
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXECUTE [DBA].[dbo].[dbasp_send_notification] @Message = @myMessage
												,@EmailSubject = NULL
												,@EmailMessage = NULL
												,@RecievePhone = @NotificationPhone
												,@RecieveEmail = NULL
												,@RecieveCC = NULL
												,@RecieveBCC = NULL
												,@ConfigKey = 'JobFailureKey';
	FETCH NEXT FROM myCursor INTO @myMessage
	END
	CLOSE myCursor
	DEALLOCATE myCursor
END
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_alwayson_data_loss_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2021-02-20', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_alwayson_data_loss_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_alwayson_data_loss_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_alwayson_data_loss_send_alert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_monitor_alwayson_data_loss_send_alert', NULL, NULL
GO
