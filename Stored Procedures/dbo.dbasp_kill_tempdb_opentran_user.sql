SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/21/2015>
-- Version:		<3.0.0.0>
-- Description:	<Killing sessions with opened transaction from DBName on tempdb that comes from specified sp>
-- Input Parameters:
--	@DBName:				'...' //Any database name who hosting bad object that make open transaction on tempdb
--	@SchemaName:			'...' //schema name of bad object that make open transaction on tempdb
--	@ObjectName:			'...' //bad object name that make open transaction on tempdb
--	@DurationThresholdSec	If Transaction duration is over than this parameter it is candidate for killing
-- =============================================
CREATE PROC [dbo].[dbasp_kill_tempdb_opentran_user] (
	@DBName sysname, 
	@SchemaName nvarchar(255), 
	@ObjectName nvarchar(255),
	@DurationThresholdSec INT
	)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @SQLString nvarchar(255)
	DECLARE @ParmDefinition nvarchar(500)
	DECLARE @ParamValue nvarchar(255)
	DECLARE @KillString nvarchar(255)
	DECLARE @mySPID INT
    DECLARE @mySPID_Pre int
	DECLARE @myObjectName nvarchar(255);
	DECLARE @mySPID_StartTime DATETIME;

	SET @SQLString = N'dbcc opentran(@dbname) with tableresults'
	SET @ParmDefinition = N'@dbname nvarchar(10)'
	SET @ParamValue = N'tempdb'

	WHILE 1=1
	BEGIN
		CREATE TABLE #OpenTran ([tempdb] nvarchar(255),[OPENTRAN] nvarchar(255))
		INSERT INTO #OpenTran EXECUTE sp_executesql @SQLString, @ParmDefinition, @dbname = @ParamValue;
		SELECT @mySPID=ISNULL(mySource.[OPENTRAN],0) from #OpenTran as mySource WHERE mySource.[tempdb]='OLDACT_SPID'
		SELECT @mySPID_StartTime=CAST(mySource.[OPENTRAN] AS DATETIME) from #OpenTran as mySource WHERE mySource.[tempdb]='OLDACT_STARTTIME'
		SET @mySPID_StartTime=ISNULL(@mySPID_StartTime,GETDATE())
		DROP Table #OpenTran

		--Stop Killing operation if there is no additional Opened Transaction or New founded transaction is equal to Previous transaction or Opened transaction duration is less than @DurationThresholdSec
		IF @mySPID IS NOT NULL AND @mySPID!=ISNULL(@mySPID_Pre,-1) AND DATEDIFF(SECOND,@mySPID_StartTime,GETDATE())>=@DurationThresholdSec
		BEGIN
			SET @mySPID_Pre=@mySPID
		END
		ELSE
		BEGIN
			BREAK
		END
		
		CREATE TABLE #INPUTBUFFER (eventtype nvarchar(30), parameters INT, eventinfo nvarchar(255))
		INSERT INTO #INPUTBUFFER(EventType, Parameters, EventInfo) EXECUTE ('dbcc inputbuffer (' + @mySPID + ') with no_infomsgs')
		SELECT Top 1 @myObjectName = EventInfo From #INPUTBUFFER
		Drop Table #INPUTBUFFER

		IF @myObjectName LIKE @DBName + '.' + @SchemaName + '.' + @ObjectName + ';%'
		BEGIN
			SET @KillString = N'Kill ' + CAST (@mySPID as nvarchar(4))
			Print @KillString
			--==========Start of Killing Session
			BEGIN TRY
				Exec (@KillString)
			END TRY
			BEGIN CATCH
				DECLARE @CustomMessage nvarchar(255)
				SET @CustomMessage='Kill session error for SPID ' + CAST(@mySPID as nvarchar)
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
			END CATCH
			--==========End of Killing Session
		END
		ELSE
		BEGIN
			Print 'Does not find any session with spedified criteria to kill, current opentran cause object is: ' + @myObjectName
		END
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_tempdb_opentran_user', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_tempdb_opentran_user', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-04-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_tempdb_opentran_user', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.1', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_kill_tempdb_opentran_user', NULL, NULL
GO
