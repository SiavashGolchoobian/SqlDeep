SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <19/7/2020>
-- Version:		<3.0.0.0>
-- Description:	<Capture user activities - this trace is based on Security Audit -> Audit Schema Object Access Event>
-- Input Parameters:
--	@DurationMinutes:	Duration of workload capture from current time, if zero or null value passed it means non-stop capturing
--	@MaxFileSizeMB:		Specifies the maximum size of each file in megabytes (MB) a trace file can grow
--	@MaxFileCount:		Specifies the maximum number or trace files to be maintained 
--	@FilePath:			Specifies the location and file name to which the trace will be written (dont specify file extentsion .trc). it can be either a local directory (such as N 'C:\MSSQL\Trace\tracefile') or a UNC to a share or path (N'\\Servername\Sharename\Directory\tracefile'). we recommend that you do not use underscore characters in the original trace file name
--	@DatabaseNameNameFilter: Set Database name for filtering audit log according to this db name, if you pass null value all sessions will be captures
--	@PrintOnly:			0 or 1
-- =============================================

CREATE PROCEDURE [dbo].[dbasp_capture_audit]
	@DurationMinutes INT = NULL, 
	@MaxFileSizeMB BIGINT = 2048, 
	@MaxFileCount INT=2, 
	@FilePath NVARCHAR(245), 
	@DatabaseNameFilter NVARCHAR(255)=NULL,
	@PrintOnly BIT=0
AS	
BEGIN
	SET NOCOUNT ON;
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);

	SET @DurationMinutes=ISNULL(@DurationMinutes,0)
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
	SET @mySQLScript=@mySQLScript+
		CAST(
		@myNewLine+ N'DECLARE @myResult INT;'+
		@myNewLine+ N'DECLARE @myTraceID INT;'+
		@myNewLine+ N'DECLARE @myTraceOption INT;'+
		@myNewLine+ N'DECLARE @myFilePath NVARCHAR(245);'+
		@myNewLine+ N'DECLARE @myMaxFileSizeMB BIGINT;'+
		@myNewLine+ N'DECLARE @myDurationMinutes INT;'+
		@myNewLine+ N'DECLARE @myStopDateTime DATETIME;'+
		@myNewLine+ N'DECLARE @myMaxFileCount INT;'+
		@myNewLine+ N'DECLARE @myDatabaseNameFilter NVARCHAR(255);'+
		@myNewLine+ N''+
		@myNewLine+ N'SET @myFilePath=N'''+ CAST(@FilePath AS NVARCHAR(MAX)) + N''';'+
		@myNewLine+ N'SET @myMaxFileSizeMB='+ CAST(@MaxFileSizeMB AS NVARCHAR(MAX)) + N';'+
		@myNewLine+ N'SET @myDurationMinutes='+ CAST(@DurationMinutes AS NVARCHAR(MAX)) + N';'+
		@myNewLine+ N'SET @myStopDateTime = DATEADD(MINUTE,@myDurationMinutes,GETDATE());'+
		@myNewLine+ N'SET @myMaxFileCount='+ CAST(@MaxFileCount AS NVARCHAR(MAX)) + N';'+
		@myNewLine+ N'SET @myDatabaseNameFilter=N'''+ CAST(ISNULL(@DatabaseNameFilter,N'') AS NVARCHAR(MAX)) + N''';'+
		@myNewLine+ N'SET @myTraceOption=CASE'+
		@myNewLine+ N'						WHEN @myMaxFileCount>1 THEN 2	--Rollover enabled'+
		@myNewLine+ N'						ELSE 0							--No Rollover'+
		@myNewLine+ N'					END;'+
		@myNewLine+ N'IF  @myDurationMinutes=0'+
		@myNewLine+ N'	SET @myStopDateTime = NULL'+
		@myNewLine+ N''+
		@myNewLine+ N'IF @myMaxFileCount>1'+
		@myNewLine+ N'BEGIN'+
		@myNewLine+ N'	EXEC @myResult=sp_trace_create @traceid=@myTraceID output,@options=@myTraceOption,@tracefile=@myFilePath,@maxfilesize=@myMaxFileSizeMB,@stoptime=@myStopDateTime,@filecount=@myMaxFileCount;'+
		@myNewLine+ N'END'+
		@myNewLine+ N'ELSE'+
		@myNewLine+ N'BEGIN'+
		@myNewLine+ N'	EXEC @myResult=sp_trace_create @traceid=@myTraceID output,@options=@myTraceOption,@tracefile=@myFilePath,@maxfilesize=@myMaxFileSizeMB,@stoptime=@myStopDateTime;'+
		@myNewLine+ N'END'+
		@myNewLine+ N''+
		@myNewLine+ N'IF @myResult=0'+
		@myNewLine+ N'BEGIN'+
		@myNewLine+ N'	--Set the events'+
		@myNewLine+ N'	DECLARE @on bit;'+
		@myNewLine+ N'	SET @on = 1;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 1, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 2, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 4, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 19, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 23, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 28, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 29, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 34, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 37, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 40, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 41, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 50, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 114, 64, @on;'+
		@myNewLine+ N'	'+
		@myNewLine+ N'	-- Set the Filters'+
		@myNewLine+ N'	DECLARE @intfilter INT;'+
		@myNewLine+ N'	DECLARE @bigintfilter BIGINT;'+
		@myNewLine+ N'	'+
		@myNewLine+ N'	IF LEN(@myDatabaseNameFilter)>0'+
		@myNewLine+ N'		EXEC sp_trace_setfilter @myTraceID, 35, 0, 6, @myDatabaseNameFilter;'+
		@myNewLine+ N'	-- Set the trace status to start'+
		@myNewLine+ N'	exec sp_trace_setstatus @myTraceID, 1;'+
		@myNewLine+ N'	'+
		@myNewLine+ N'	-- display trace id for future references'+
		@myNewLine+ N'	PRINT ''TraceID is '' + CAST(@myTraceID AS NVARCHAR(50));'+
		@myNewLine+ N'	PRINT ''Use below script to manage trace before '' + CAST(@myStopDateTime AS NVARCHAR(50));'+
		@myNewLine+ N'	PRINT ''exec sp_trace_setstatus '' + CAST(@myTraceID AS NVARCHAR(50)) + '', @status = 0'';	--Use this command to Stoping trace.'+
		@myNewLine+ N'	PRINT ''exec sp_trace_setstatus '' + CAST(@myTraceID AS NVARCHAR(50)) + '', @status = 2'';	--Use this command to Deleting trace.'+
		@myNewLine+ N'	PRINT ''SELECT * FROM sys.[fn_trace_gettable](''''''+ @myFilePath + ''.trc'''',DEFAULT) AS myTrcFile'';	--Use this command to query from trace file'+
		@myNewLine+ N'END'+
		@myNewLine+ N'ELSE'+
		@myNewLine+ N'BEGIN '+
		@myNewLine+ N'	PRINT ''ErrorCode: '' + CAST(@myResult AS NVARCHAR(50));'+
		@myNewLine+ N'END'
		AS NVARCHAR(MAX))

		EXEC [dbo].[dbasp_print_text] @mySQLScript
		IF @PrintOnly=0
		BEGIN
			PRINT (@myNewLine + '--Excexution Report--');
			--=======Start of executing commands
			BEGIN TRY
				EXECUTE (@mySQLScript);
			END TRY
			BEGIN CATCH
				DECLARE @CustomMessage1 NVARCHAR(255)
				SET @CustomMessage1='Activity audit capturing error.'
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
			END CATCH
			--=======End of executing commands
		END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_capture_audit', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-07-18', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_capture_audit', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2020-07-18', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_capture_audit', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_capture_audit', NULL, NULL
GO
