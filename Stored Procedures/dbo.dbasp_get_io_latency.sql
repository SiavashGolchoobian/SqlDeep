SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =================================================================================
-- Author:		Based on Paul S. Randal, SQLskills.com with some changes by Siavash Golchoobian
-- Create date: <08/02/2021>
-- Version:		<3.0.0.0>
-- Description:
--                 This procedure finds the name and paths for the top N data or log files 
--                 on the Server with the most high value of average total IO latency. 
-- Input Parameters:
--	@CaptureStatEnabled		Bit value, Capture the current state of IO
--	@ShowLastReport			Show the latest report of IO latency according to Captured data
-- ==================================================================================
CREATE PROCEDURE [dbo].[dbasp_get_io_latency] (@CaptureStatEnabled BIT=1,@ShowLastReport BIT=0)
AS
BEGIN
   SET NOCOUNT ON
 
	DECLARE @myCaptureStat BIT;
	DECLARE @myShowLastReport BIT;
	DECLARE @myLogTime AS DATETIME;
	DECLARE @myLastSnapshotId BIGINT;
	DECLARE @myPreviousSnapshotId BIGINT;
	DECLARE @myLastSnapshotIdLogTime DATETIME;
	DECLARE @myPreviousSnapshotIdLogTime DATETIME;
	DECLARE @myReportDuration BIGINT;

	SET @myCaptureStat=@CaptureStatEnabled;
	SET @myShowLastReport=@ShowLastReport;
	SET @myLogTime = GETDATE();

	IF @myCaptureStat=1
	BEGIN
		INSERT INTO [trace].[VfLogHistory]
		(
			[SnapshotId],
			[database_id],
			[file_id],
			[num_of_reads],
			[io_stall_read_ms],
			[num_of_writes],
			[io_stall_write_ms],
			[io_stall],
			[num_of_bytes_read],
			[num_of_bytes_written],
			[file_handle],
			[LogTime]
		)
		SELECT 
			[dbo].[dbafn_datetime2int](@myLogTime,14) AS [SnapshotId],
			[database_id],
			[file_id],
			[num_of_reads],
			[io_stall_read_ms],
			[num_of_writes],
			[io_stall_write_ms],
			[io_stall],
			[num_of_bytes_read],
			[num_of_bytes_written],
			[file_handle],
			@myLogTime AS [LogTime]
		FROM [sys].[dm_io_virtual_file_stats](NULL, NULL)
	END

	IF @myShowLastReport=1
	BEGIN
		SELECT @myLastSnapshotId=MAX([mySource].[SnapshotId]), @myPreviousSnapshotId=MIN([mySource].[SnapshotId]), @myLastSnapshotIdLogTime=MAX([mySource].[LogTime]), @myPreviousSnapshotIdLogTime=MIN([mySource].[LogTime]) FROM (SELECT TOP 2 [SnapshotId],MAX([LogTime]) AS LogTime FROM [trace].[VfLogHistory] GROUP BY [SnapshotId] ORDER BY [SnapshotId] DESC) AS mySource
		SET @myReportDuration=DATEDIFF(SECOND,@myPreviousSnapshotIdLogTime,@myLastSnapshotIdLogTime)
		IF @myLastSnapshotId>@myPreviousSnapshotId
		BEGIN
			;WITH [myDiffLatencies] AS
			(SELECT
			-- Files that weren't in the first snapshot
					[ts2].[database_id],
					[ts2].[file_id],
					[ts2].[num_of_reads],
					[ts2].[io_stall_read_ms],
					[ts2].[num_of_writes],
					[ts2].[io_stall_write_ms],
					[ts2].[io_stall],
					[ts2].[num_of_bytes_read],
					[ts2].[num_of_bytes_written]
				FROM (SELECT * FROM [trace].[VfLogHistory] WHERE [SnapshotId]=@myLastSnapshotId) AS [ts2]
				LEFT OUTER JOIN (SELECT * FROM [trace].[VfLogHistory] WHERE [SnapshotId]=@myPreviousSnapshotId) AS [ts1] ON [ts2].[file_handle] = [ts1].[file_handle]
				WHERE [ts1].[file_handle] IS NULL
			UNION
			SELECT
			-- Diff of latencies in both snapshots
					[ts2].[database_id],
					[ts2].[file_id],
					[ts2].[num_of_reads] - [ts1].[num_of_reads] AS [num_of_reads],
					[ts2].[io_stall_read_ms] - [ts1].[io_stall_read_ms] AS [io_stall_read_ms],
					[ts2].[num_of_writes] - [ts1].[num_of_writes] AS [num_of_writes],
					[ts2].[io_stall_write_ms] - [ts1].[io_stall_write_ms] AS [io_stall_write_ms],
					[ts2].[io_stall] - [ts1].[io_stall] AS [io_stall],
					[ts2].[num_of_bytes_read] - [ts1].[num_of_bytes_read] AS [num_of_bytes_read],
					[ts2].[num_of_bytes_written] - [ts1].[num_of_bytes_written] AS [num_of_bytes_written]
				FROM (SELECT * FROM [trace].[VfLogHistory] WHERE [SnapshotId]=@myLastSnapshotId) AS [ts2]
				LEFT OUTER JOIN (SELECT * FROM [trace].[VfLogHistory] WHERE [SnapshotId]=@myPreviousSnapshotId) AS [ts1] ON [ts2].[file_handle] = [ts1].[file_handle]
				WHERE [ts1].[file_handle] IS NOT NULL
			)

			SELECT
				@myReportDuration AS [StatDuration(sec)],
				DB_NAME([vfs].[database_id]) AS [DB],
				LEFT ([mf].[physical_name], 2) AS [Drive],
				[mf].[type_desc],
				[num_of_reads] AS [Reads],
				[num_of_writes] AS [Writes],
				[ReadLatency(ms)] =
					CASE WHEN [num_of_reads] = 0
						THEN 0 ELSE ([io_stall_read_ms] / [num_of_reads]) END,
				[WriteLatency(ms)] =
					CASE WHEN [num_of_writes] = 0
						THEN 0 ELSE ([io_stall_write_ms] / [num_of_writes]) END,
				 [Latency(ms)] =
					 CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
						 THEN 0 ELSE ([io_stall] / ([num_of_reads] + [num_of_writes])) END,
				[AvgBPerRead] =
					CASE WHEN [num_of_reads] = 0
						THEN 0 ELSE ([num_of_bytes_read] / [num_of_reads]) END,
				[AvgBPerWrite] =
					CASE WHEN [num_of_writes] = 0
						THEN 0 ELSE ([num_of_bytes_written] / [num_of_writes]) END,
				 [AvgBPerTransfer] =
					 CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
						 THEN 0 ELSE
							 (([num_of_bytes_read] + [num_of_bytes_written]) /
							 ([num_of_reads] + [num_of_writes])) END,
				[mf].[physical_name]
			FROM [myDiffLatencies] AS [vfs]
			JOIN [sys].[master_files] AS [mf] ON [vfs].[database_id] = [mf].[database_id] AND [vfs].[file_id] = [mf].[file_id]
			-- ORDER BY [ReadLatency(ms)] DESC
			ORDER BY [WriteLatency(ms)] DESC;
		END
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_io_latency', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2021-08-02', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_io_latency', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-08-02', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_io_latency', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_io_latency', NULL, NULL
GO
