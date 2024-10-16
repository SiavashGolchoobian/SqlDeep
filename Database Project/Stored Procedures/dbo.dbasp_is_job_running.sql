SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian, based on modified version of msdb.dbo.sp_get_composite_job_info>
-- Create date: <3/5/2024>
-- Version:		<3.1.0.0>
-- Description:	<Return job running status>
-- Input Parameters:
--	@JobName:			Job name
--	@IsRunning:			SP return value: 0 or 1
-- =============================================
CREATE PROC [dbo].[dbasp_is_job_running] (
	@JobName sysname,
	@IsRunning bit OUTPUT
	)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @myAnswer BIT
	DECLARE @myJob_name sysname
	DECLARE @myJob_id UNIQUEIDENTIFIER
	DECLARE @myCan_see_all_running_jobs INT
	DECLARE @myJob_owner SYSNAME
	DECLARE @myXp_results TABLE (job_id                UNIQUEIDENTIFIER NOT NULL,
							last_run_date         INT              NOT NULL,
							last_run_time         INT              NOT NULL,
							next_run_date         INT              NOT NULL,
							next_run_time         INT              NOT NULL,
							next_run_schedule_id  INT              NOT NULL,
							requested_to_run      INT              NOT NULL, -- BOOL
							request_source        INT              NOT NULL,
							request_source_id     sysname          COLLATE database_default NULL,
							running               INT              NOT NULL, -- BOOL
							current_step          INT              NOT NULL,
							current_retry_attempt INT              NOT NULL,
							job_state             INT              NOT NULL)

	SET @myAnswer=0
	SET @myJob_name=@JobName
	SELECT @myJob_id=[job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name]=@myJob_name
	SELECT @myCan_see_all_running_jobs = ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0)
	IF (@myCan_see_all_running_jobs = 0)
	BEGIN
		SELECT @myCan_see_all_running_jobs = ISNULL(IS_MEMBER(N'SQLAgentReaderRole'), 0)
	END
		SELECT @myJob_owner = SUSER_SNAME()

	IF ((@@microsoftversion / 0x01000000) >= 8) -- SQL Server 8.0 or greater
		INSERT INTO @myXp_results
		EXECUTE [master].[dbo].[xp_sqlagent_enum_jobs] @myCan_see_all_running_jobs, @myJob_owner, @myJob_id
	ELSE
		INSERT INTO @myXp_results
		EXECUTE [master].[dbo].[xp_sqlagent_enum_jobs] @myCan_see_all_running_jobs, @myJob_owner

	SELECT @myAnswer=CAST(CASE [myResult].[running] WHEN 1 THEN 1 ELSE 0 END AS BIT) FROM @myXp_results AS myResult WHERE [myResult].[job_id]=@myJob_id
	SET @IsRunning=ISNULL(@myAnswer,0)
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_is_job_running', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2024-03-05', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_is_job_running', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2024-03-05', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_is_job_running', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.1.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_is_job_running', NULL, NULL
GO
