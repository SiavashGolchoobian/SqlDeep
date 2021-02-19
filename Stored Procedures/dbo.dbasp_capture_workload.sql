SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Golchoobian>
-- Create date: <18/7/2020>
-- Version:		<3.0.0.0>
-- Description:	<Capture replayable workload - this trace is based on TSQL_REPLAY template plus CPU, Duration, Reads, Writes, TextData and ObjectName columns for RPC:Completed and SQL:BatchCompleted events>
-- Input Parameters:
--	@DurationMinutes:	This parameter only used for TRACE CaptureType mode. Duration of workload capture from current time, if zero or null value passed it means non-stop capturing
--	@MaxFileSizeMB:		Specifies the maximum size of each file in megabytes (MB) a trace file can grow
--	@MaxFileCount:		Specifies the maximum number or trace files to be maintained 
--	@FilePath:			Specifies the location and file name to which the trace will be written (dont specify file extentsion .trc if your CaptureType is TRACE, but use .xel for XEL type). it can be either a local directory (such as N 'C:\MSSQL\Trace\tracefile') or a UNC to a share or path (N'\\Servername\Sharename\Directory\tracefile'). we recommend that you do not use underscore characters in the original trace file name
--	@ApplicationNameFilter: Set Application name for filtering workload according to this app name, if you pass null value all sessions will be captured
--	@DatabaseNameFilter: Set Database name for filtering workload according to this db name, if you pass null value all sessions will be captured
--	@CaptureType:		Coulld be one of the TRACE or XEL type, TRACE stand for Server Side Trace file and XEL stand for Extended Event Profiler type
--	@PrintOnly:			0 or 1
-- =============================================

CREATE PROCEDURE [dbo].[dbasp_capture_workload]
	@DurationMinutes INT = 60, 
	@MaxFileSizeMB BIGINT = 2048, 
	@MaxFileCount INT=5, 
	@FilePath NVARCHAR(245), 
	@ApplicationNameFilter NVARCHAR(255)=NULL,
	@DatabaseNameFilter NVARCHAR(255)=NULL,
	@CaptureType NVARCHAR(5)=N'TRACE',		--XEL
	@PrintOnly BIT=0
AS	
BEGIN
	SET NOCOUNT ON;
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myRandomGuid UNIQUEIDENTIFIER
	DECLARE @myXelCondition NVARCHAR(MAX)

	SET @myRandomGuid=NEWID()
	SET @DurationMinutes=ISNULL(@DurationMinutes,0)
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
	
	IF UPPER(@CaptureType)=N'TRACE'
	BEGIN
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
		@myNewLine+ N'DECLARE @myApplicationNameFilter NVARCHAR(255);'+
		@myNewLine+ N'DECLARE @myDatabaseNameFilter NVARCHAR(255);'+
		@myNewLine+ N''+
		@myNewLine+ N'SET @myFilePath=N'''+ CAST(@FilePath AS NVARCHAR(MAX)) + N''';'+
		@myNewLine+ N'SET @myMaxFileSizeMB='+ CAST(@MaxFileSizeMB AS NVARCHAR(MAX)) + N';'+
		@myNewLine+ N'SET @myDurationMinutes='+ CAST(@DurationMinutes AS NVARCHAR(MAX)) + N';'+
		@myNewLine+ N'SET @myStopDateTime = DATEADD(MINUTE,@myDurationMinutes,GETDATE());'+
		@myNewLine+ N'SET @myMaxFileCount='+ CAST(@MaxFileCount AS NVARCHAR(MAX)) + N';'+
		@myNewLine+ N'SET @myApplicationNameFilter=N'''+ CAST(ISNULL(@ApplicationNameFilter,N'') AS NVARCHAR(MAX)) + N''';'+
		@myNewLine+ N'SET @myDatabaseNameFilter=N'''+ CAST(ISNULL(@DatabaseNameFilter,N'') AS NVARCHAR(MAX)) + N''';'+
		@myNewLine+ N'SET @myTraceOption=CASE'+
		@myNewLine+ N'						WHEN @myMaxFileCount>1 THEN 2	--Rollover enabled'+
		@myNewLine+ N'						ELSE 0							--No Rollover'+
		@myNewLine+ N'					END;'+
		@myNewLine+ N'IF  @myDurationMinutes=0'+
		@myNewLine+ N'	SET @myStopDateTime = NULL'+
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
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 33, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 78, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 33, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 74, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 33, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 53, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 33, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 70, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 33, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 77, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 15, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 16, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 1, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 2, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 21, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 14, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 15, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 21, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 15, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 1, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 2, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 17, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 1, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 100, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 2, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 13, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 15, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 16, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 17, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 18, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 31, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 34, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 48, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 10, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 2, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 11, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 33, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 72, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 33, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 71, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 1, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 13, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 15, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 16, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 17, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 18, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 31, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 48, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 12, 60, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 1, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 9, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 3, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 11, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 6, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 7, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 8, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 10, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 12, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 14, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 26, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 35, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 49, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 51, @on;'+
		@myNewLine+ N'	exec sp_trace_setevent @myTraceID, 13, 60, @on;'+
		@myNewLine+ N'	'+
		@myNewLine+ N'	-- Set the Filters'+
		@myNewLine+ N'	DECLARE @intfilter INT;'+
		@myNewLine+ N'	DECLARE @bigintfilter BIGINT;'+
		@myNewLine+ N'	'+
		@myNewLine+ N'	IF LEN(@myDatabaseNameFilter)>0'+
		@myNewLine+ N'		EXEC sp_trace_setfilter @myTraceID, 35, 0, 6, @myDatabaseNameFilter;'+
		@myNewLine+ N'	IF LEN(@myApplicationNameFilter)>0'+
		@myNewLine+ N'		EXEC sp_trace_setfilter @myTraceID, 10, 0, 6, @myApplicationNameFilter;'+
		@myNewLine+ N'	exec sp_trace_setfilter @myTraceID, 10, 0, 7, N''SQL Server Profiler%'';'+
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
	END
	ELSE IF UPPER(@CaptureType)=N'XEL'
	BEGIN
		SET @myXelCondition = CAST (N'' AS NVARCHAR(MAX))
		SET @myXelCondition = @myXelCondition + CAST(CASE WHEN LEN(@ApplicationNameFilter)>0 OR LEN(@DatabaseNameFilter)>0 THEN @myNewLine+ N'	WHERE (' ELSE N'' END AS NVARCHAR(MAX))
		SET @myXelCondition = @myXelCondition + CAST(CASE WHEN LEN(@ApplicationNameFilter)>0 THEN @myNewLine+ N'	([sqlserver].[client_app_name]=N'''+ CAST(@ApplicationNameFilter AS NVARCHAR(MAX)) +''')' ELSE N'' END AS NVARCHAR(MAX))
		SET @myXelCondition = @myXelCondition + CAST(CASE WHEN LEN(@ApplicationNameFilter)>0 AND LEN(@DatabaseNameFilter)>0 THEN @myNewLine+ N'	AND ' ELSE N'' END AS NVARCHAR(MAX))
		SET @myXelCondition = @myXelCondition + CAST(CASE WHEN LEN(@DatabaseNameFilter)>0 THEN @myNewLine+ N'	([sqlserver].[database_name]=N'''+ CAST(@DatabaseNameFilter AS NVARCHAR(MAX)) +''')' ELSE N'' END AS NVARCHAR(MAX))
		SET @myXelCondition = @myXelCondition + CAST(CASE WHEN LEN(@ApplicationNameFilter)>0 OR LEN(@DatabaseNameFilter)>0 THEN @myNewLine+ N')' ELSE N'' END AS NVARCHAR(MAX))
		SET @mySQLScript=@mySQLScript+
		CAST(
		@myNewLine+ N'CREATE EVENT SESSION [WorkloadCaptureTrc'+ CAST(@myRandomGuid AS NVARCHAR(MAX)) +'] ON SERVER'+
		@myNewLine+ N'ADD EVENT sqlserver.assembly_load('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.attention('+
		@myNewLine+ N'	ACTION(package0.event_sequence,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.request_id,sqlserver.session_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.begin_tran_completed(SET collect_statement=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.begin_tran_starting(SET collect_statement=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.commit_tran_completed(SET collect_statement=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.commit_tran_starting(SET collect_statement=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.cursor_close('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.sql_text,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.cursor_execute('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.sql_text,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.cursor_implicit_conversion('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.sql_text,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.cursor_open('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.sql_text,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.cursor_prepare('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.sql_text,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.cursor_recompile('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.sql_text,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.cursor_unprepare('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.sql_text,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.database_file_size_change(SET collect_database_name=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.dtc_transaction('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.exec_prepared_sql('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.existing_connection(SET collect_database_name=(1),collect_options_text=(1)'+
		@myNewLine+ N'	ACTION(package0.event_sequence,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.client_pid,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.nt_username,sqlserver.request_id,sqlserver.server_instance_name,sqlserver.server_principal_name,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.session_resource_group_id,sqlserver.session_resource_pool_id,sqlserver.session_server_principal_name,sqlserver.username)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.login(SET collect_database_name=(1),collect_options_text=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.client_pid,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.request_id,sqlserver.server_instance_name,sqlserver.server_principal_name,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.session_resource_group_id,sqlserver.session_resource_pool_id,sqlserver.session_server_principal_name,sqlserver.transaction_id,sqlserver.username)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.logout('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.client_pid,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.request_id,sqlserver.server_instance_name,sqlserver.server_principal_name,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.session_resource_group_id,sqlserver.session_resource_pool_id,sqlserver.session_server_principal_name,sqlserver.transaction_id,sqlserver.username)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.prepare_sql('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.promote_tran_completed('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.promote_tran_starting('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.rollback_tran_completed(SET collect_statement=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.rollback_tran_starting(SET collect_statement=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.rpc_completed(SET collect_data_stream=(1),collect_output_parameters=(1),collect_statement=(0)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.rpc_starting(SET collect_data_stream=(1),collect_statement=(0)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.save_tran_completed(SET collect_statement=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.save_tran_starting(SET collect_statement=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.server_memory_change('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.sql_batch_completed(SET collect_batch_text=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.sql_batch_starting(SET collect_batch_text=(1)'+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.sql_transaction('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.trace_flag_changed('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + '),'+
		@myNewLine+ N'ADD EVENT sqlserver.unprepare_sql('+
		@myNewLine+ N'	ACTION(package0.collect_current_thread_id,package0.event_sequence,sqlos.cpu_id,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlos.worker_address,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.plan_handle,sqlserver.request_id,sqlserver.session_id,sqlserver.transaction_id)' + CAST(@myXelCondition AS NVARCHAR(MAX)) + ')'+
		@myNewLine+ N'ADD TARGET package0.event_file(SET filename=N''' + CAST(@FilePath AS NVARCHAR(MAX)) + ''',max_file_size=(' + CAST(@MaxFileSizeMB AS NVARCHAR(MAX )) + '),max_rollover_files=(' + CAST(@MaxFileCount AS NVARCHAR(MAX)) + '))'+
		@myNewLine+ N'WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON) ;'+
		@myNewLine+ N'ALTER EVENT SESSION [WorkloadCaptureTrc' + CAST(@myRandomGuid AS NVARCHAR(MAX)) + '] ON SERVER STATE = start ;'+
		@myNewLine+ N'Print ''Extended Event [WorkloadCaptureTrc' + CAST(@myRandomGuid AS NVARCHAR(MAX)) + '] was created and started, you can stop it by following command:'';'+
		@myNewLine+ N'Print ''	ALTER EVENT SESSION [WorkloadCaptureTrc' + CAST(@myRandomGuid AS NVARCHAR(MAX)) + '] ON SERVER STATE = STOP;'' ;'+
		@myNewLine+ N'Print ''Also you can convert .xel to .trc file by ReadTrace.exe located on DAE installation folder (C:\Program Files (x86)\Microsoft Corporation\Database Experimentation Assistant\Dependencies\X64) or deprecated RML utilities installtion folder (C:\Program Files (x86)\Microsoft Corporation\RMLUtils) via bellow command'' ;'+
		@myNewLine+ N'Print ''	readtrace.exe -S"server\instance,port" -d"tempdb" -U"sa" -P"P@$$w0rd" -I"' + CAST(@FilePath AS NVARCHAR(MAX)) + '" -O"X:\Output\DReplayTraceFolder" -a -MS'' ;'
		AS NVARCHAR(MAX))
	END

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
				SET @CustomMessage1='Workload capturing error.'
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
			END CATCH
			--=======End of executing commands
		END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_capture_workload', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-07-18', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_capture_workload', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2020-07-18', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_capture_workload', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_capture_workload', NULL, NULL
GO
