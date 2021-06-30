SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <4/5/2018>
-- Version:		<3.0.0.1>
-- Description:	<Cycle Error Log file and set minimum log file count and it's size>
-- Input Parameters:
--	@RecyclingThereshold_MB:	Error log file size threshold for recycling in MB
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_cycle_error_log]
	@RecyclingThereshold_MB INT=10
AS
BEGIN
	DECLARE @myCurrentFileSize_Byte INT
	DECLARE @RecyclingThereshold_KB INT

	SET @RecyclingThereshold_KB=@RecyclingThereshold_MB*1024
	CREATE TABLE #ServerErrorLog (ArchiveNo INT, CreateedDate DateTime, ErrorLogFileSize_Byte INT);
	INSERT INTO #ServerErrorLog EXEC xp_enumerrorlogs;
	SELECT @myCurrentFileSize_Byte=[ErrorLogFileSize_Byte] FROM [#ServerErrorLog] WHERE [ArchiveNo]=0
	DROP TABLE #ServerErrorLog;

	--Set Error Log files count and their maximum file size
	EXEC [master].[dbo].[xp_instance_regwrite] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'ErrorLogSizeInKb', REG_DWORD, @RecyclingThereshold_KB
	EXEC [master].[dbo].[xp_instance_regwrite] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', REG_DWORD, 12
	--Recycle Error Log file
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
EXEC sp_addextendedproperty N'Modified Date', N'2021-06-30', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_cycle_error_log', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.1', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_cycle_error_log', NULL, NULL
GO
