SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Siavash Golchoobian>
-- Create date: <6/20/2017>
-- Version:		<3.0.0.0>
-- Description:	<Execute list of commands via job in parallel>
-- Input Parameters:
--	@BatchId:				unique number for specifying batch commands in TaskList([trace].[Execute_SQLByJob])
--	@SQLCommandsTable:		Table of Commands
--	@DegreeOfPrallelism:	number of parallel execution of tasks
--	@RetryAttemptsOnFailure:number of retry after failure
--	@JobPrefixName:			prefix name of jobs to generate
--	@PrintOnly:				0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_execute_multiple_sql]
	@BatchId INT,
	@SQLCommandsTable [dbo].SQLCommandsTableType READONLY,
	@DegreeOfPrallelism INT,
	@RetryAttemptsOnFailure INT=1,
	@JobPrefixName sysname = N'multiple_exec_',
	@PrintOnly BIT=1
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myJobNo INT;
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myExecuteCommand NVARCHAR(MAX)
	DECLARE @myMonitorCommand NVARCHAR(MAX)
	DECLARE @myDropCommand NVARCHAR(MAX)
		
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myExecuteCommand=CAST(N'' AS NVARCHAR(MAX))
	SET @myMonitorCommand=CAST(N'' AS NVARCHAR(MAX))
	SET @myDropCommand=CAST(N'' AS NVARCHAR(MAX))
	
	IF NOT EXISTS (SELECT 1 FROM sys.[all_objects] AS myTables INNER JOIN sys.[schemas] AS mySchema ON [mySchema].[schema_id] = [myTables].[schema_id] WHERE [mySchema].[name]='trace' AND [myTables].[name]='Tasks')
	BEGIN
		CREATE TABLE [trace].[Tasks](
			[TaskId] [BIGINT] NOT NULL IDENTITY,
			[BatchId] [INT] NOT NULL,
			[SQLStatementId] [BIGINT] NULL,
			[SQLStatementValue] [NVARCHAR](MAX) NULL,
			[StartTime] [DATETIME] NULL,
			[EndTime] [DATETIME] NULL,
			[ProcessStatus] [VARCHAR](50) NOT NULL CHECK ([ProcessStatus]='QUEUED' OR [ProcessStatus]='RUNNING' OR [ProcessStatus]='SUCCESS' OR [ProcessStatus]='FAIL'),
			[ErrorMessage] [NVARCHAR](MAX) NULL,
			[TryCount] INT NOT NULL,
			[MaxTryCount] INT NOT NULL DEFAULT (1),
			[Executor] NVARCHAR(MAX) NULL,
			CONSTRAINT [PK_Tasks] PRIMARY KEY CLUSTERED ([TaskId] ASC)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [Data_OLTP]
		) ON [Data_OLTP] TEXTIMAGE_ON [Data_OLTP]
	END

	--Clear Task List
	DELETE FROM [trace].[Tasks] WHERE [BatchId]=@BatchId

	--Insert new tasks to TaskList
	INSERT INTO [trace].[Tasks]([BatchId],[SQLStatementId],[SQLStatementValue],[ProcessStatus],[TryCount],[MaxTryCount])
	SELECT @BatchId, myCommandTable.[Id],myCommandTable.[SQLStatement],'QUEUED',0,@RetryAttemptsOnFailure FROM @SQLCommandsTable AS myCommandTable ORDER BY [myCommandTable].[Id]

	--Create Related Jobs
	DECLARE @myJobId UNIQUEIDENTIFIER
	DECLARE @myJobName sysname
	DECLARE @myJobOwner sysname
	DECLARE @myServerName sysname
	DECLARE @myJobStep01 NVARCHAR(MAX)

	CREATE TABLE #JobList (JobNo INT,JobId UNIQUEIDENTIFIER,JobName sysname)
	SET @myJobNo=0
	SET @myJobOwner=SUSER_NAME()
	SET @myServerName=@@SERVERNAME

	WHILE @myJobNo < @DegreeOfPrallelism
	BEGIN
		SET @myJobId = NULL
		SET @myJobNo=@myJobNo+1
		SET @myJobName=@JobPrefixName + CAST(@BatchId AS NVARCHAR(50)) + N'_' + CAST(@myJobNo AS NVARCHAR(50))
		SET @myJobStep01=CAST(N'' AS NVARCHAR(MAX))
		SET @myJobStep01=@myJobStep01+
			@myNewLine+ N'DECLARE @myTaskId BIGINT'+
			@myNewLine+ N'DECLARE @myJobNo NVARCHAR(MAX)'+
			@myNewLine+ N'DECLARE @mySQLStatement NVARCHAR(MAX)'+
			@myNewLine+ N'SET QUOTED_IDENTIFIER ON'+
			@myNewLine+ N'SET @myJobNo=N'''+ CAST(@myJobNo AS NVARCHAR(MAX)) + N''''+
			@myNewLine+ N'WHILE EXISTS (SELECT 1 FROM [SqlDeep].[trace].[Tasks] AS [myTasks] WHERE [myTasks].[BatchId]=' + CAST(@BatchId AS NVARCHAR(MAX)) + ' AND ([myTasks].[ProcessStatus]=''QUEUED'' OR ([myTasks].[ProcessStatus]=''FAIL'' AND [myTasks].[TryCount]<[myTasks].[MaxTryCount])))'+ 
			@myNewLine+ N'BEGIN'+
			@myNewLine+ N'--=======Make Continious loop'+
			@myNewLine+ N'	BEGIN TRANSACTION'+
			@myNewLine+ N'		--=======Pick a TaskId from TaskList'+
			@myNewLine+ N'		SET @myTaskId=(SELECT TOP 1 [myTasks].[TaskId] FROM [SqlDeep].[trace].[Tasks] AS myTasks WITH (UPDLOCK,READPAST) WHERE [myTasks].[BatchId]=' + CAST(@BatchId AS NVARCHAR(MAX)) + ' AND ([myTasks].[ProcessStatus]=''QUEUED'' OR ([myTasks].[ProcessStatus]=''FAIL'' AND [myTasks].[TryCount]<[myTasks].[MaxTryCount])) ORDER BY [myTasks].[TryCount],[myTasks].[TaskId])'+
			@myNewLine+ N'		IF @myTaskId IS NOT NULL'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'			--=======Update Task Status'+
			@myNewLine+ N'			UPDATE [SqlDeep].[trace].[Tasks] SET [ProcessStatus]=''RUNNING'', [StartTime]=GETDATE(),[TryCount]=ISNULL([TryCount],0)+1,[Executor]=ISNULL([Executor],N'''')+N'',''+@myJobNo WHERE [TaskId]=@myTaskId'+
			@myNewLine+ N'		END'+
			@myNewLine+ N'	COMMIT TRANSACTION'+
			@myNewLine+ N''+
			@myNewLine+ N'	IF @myTaskId IS NOT NULL'+
			@myNewLine+ N'		BEGIN'+
			@myNewLine+ N'		--=======Extract Task from TaskList'+
			@myNewLine+ N'		SELECT @mySQLStatement=[myTasks].[SQLStatementValue] FROM [SqlDeep].[trace].[Tasks] AS myTasks WHERE [myTasks].[TaskId]=@myTaskId'+
			@myNewLine+ N'		--=======Start of executing commands'+
			@myNewLine+ N'		BEGIN TRY'+
			@myNewLine+ N'			EXECUTE (@mySQLStatement);'+
			@myNewLine+ N'			UPDATE [SqlDeep].[trace].[Tasks] SET [ProcessStatus]=''SUCCESS'', [EndTime]=GETDATE() WHERE [TaskId]=@myTaskId'+
			@myNewLine+ N'		END TRY'+
			@myNewLine+ N'		BEGIN CATCH'+
			@myNewLine+ N'			UPDATE [SqlDeep].[trace].[Tasks] SET [ProcessStatus]=''FAIL'', [EndTime]=GETDATE(),[ErrorMessage]=ERROR_MESSAGE() WHERE [TaskId]=@myTaskId'+
			@myNewLine+ N'		END CATCH'+
			@myNewLine+ N'	END'+
			@myNewLine+ N'END'

		IF EXISTS (SELECT 1 FROM [msdb].dbo.[sysjobs] AS myJobs WHERE [myJobs].[name]=@myJobName)
			EXEC msdb.dbo.sp_delete_job @job_name=@myJobName, @delete_unused_schedule=1

		EXEC msdb.dbo.sp_add_job @job_name=@myJobName, @owner_login_name=@myJobOwner, @job_id = @myJobId OUTPUT
		EXEC msdb.dbo.sp_add_jobserver @job_name=@myJobName, @server_name=@myServerName
		EXEC msdb.dbo.sp_add_jobstep @job_name=@myJobName, @step_name=N'ExecuteStatement', @step_id=1, @on_success_action=1, @on_fail_action=2, @subsystem=N'TSQL', @command=@myJobStep01, @database_name=N'DBA'
		
		SET @myExecuteCommand=@myExecuteCommand+
			CAST(
			@myNewLine+ N'EXECUTE [msdb].dbo.[sp_start_job] @job_name = '''+ @myJobName + ''';'
			AS NVARCHAR(MAX))

		SET @myDropCommand=@myDropCommand+
			CAST(
			@myNewLine+N'IF EXISTS (SELECT 1 FROM [msdb].dbo.[sysjobs] AS myJobs WHERE [myJobs].[name]=''' + @myJobName + N''')'+
			@myNewLine+N'	EXEC msdb.dbo.sp_delete_job @job_name='''+ @myJobName + ''', @delete_unused_schedule=1'
			AS NVARCHAR(MAX))
	END

	--Print Jobs
		SET @myMonitorCommand=@myMonitorCommand + @myNewLine + N'SELECT * FROM [SqlDeep].[trace].[Tasks] AS [myTasks] WITH(NOLOCK) WHERE [myTasks].[BatchId]=' + CAST(@BatchId AS NVARCHAR(50)) + N' AND [myTasks].[ProcessStatus] IN (''QUEUED'',''SUCCESS'') ORDER BY [myTasks].[StartTime] DESC, [myTasks].[TaskId]'
		SET @myMonitorCommand=@myMonitorCommand + @myNewLine + N'SELECT * FROM [SqlDeep].[trace].[Tasks] AS [myTasks] WITH(NOLOCK) WHERE [myTasks].[BatchId]=' + CAST(@BatchId AS NVARCHAR(50)) + N' AND [myTasks].[ProcessStatus] NOT IN (''QUEUED'',''SUCCESS'') ORDER BY [myTasks].[StartTime] DESC, [myTasks].[TaskId]'
		EXEC dbo.[dbasp_print_text] @myExecuteCommand
		EXEC dbo.[dbasp_print_text] @myMonitorCommand
		EXEC dbo.[dbasp_print_text] @myDropCommand
		SELECT * FROM [SqlDeep].[trace].[Tasks] AS [myTasks] WITH(NOLOCK) WHERE [myTasks].[BatchId]=@BatchId AND [myTasks].[ProcessStatus] NOT IN ('QUEUE','SUCCESS') ORDER BY [myTasks].[StartTime] DESC, [myTasks].[TaskId]

	--Execute Jobs
	IF @PrintOnly=0
	BEGIN
		EXEC (@myExecuteCommand)
	END
END

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_execute_multiple_sql', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-06-20', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_execute_multiple_sql', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-06-24', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_execute_multiple_sql', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_execute_multiple_sql', NULL, NULL
GO
