SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <4/5/2018>
-- Version:		<3.0.0.0>
-- Description:	<Cycle Error Log file>
-- Input Parameters:
--	@RecyclingThereshold_MB:	Error log file size threshold for recycling in MB
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_cycle_error_log]
	@RecyclingThereshold_MB INT=10
AS
BEGIN
	DECLARE @myCurrentFileSize_Byte INT

	CREATE TABLE #ServerErrorLog (ArchiveNo INT, CreateedDate DateTime, ErrorLogFileSize_Byte INT);
	INSERT INTO #ServerErrorLog EXEC xp_enumerrorlogs;
	SELECT @myCurrentFileSize_Byte=[ErrorLogFileSize_Byte] FROM [#ServerErrorLog] WHERE [ArchiveNo]=0
	DROP TABLE #ServerErrorLog;

	IF ISNULL(@myCurrentFileSize_Byte,0)>=(@RecyclingThereshold_MB*1024*1024)
	BEGIN
		EXEC sp_cycle_errorlog
		PRINT 'Error Log file recycled'
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_cycle_error_log', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2018-04-05', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_cycle_error_log', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-04-05', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_cycle_error_log', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_cycle_error_log', NULL, NULL
GO
