SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/21/2015>
-- Version:		<3.0.0.1>
-- Description:	<Show log events of sql server error log and sql agent log>
-- Input Parameters:
--	@logfile:		0,1,2,3,...,N //Is a log file archive number
--	@logfiletype:	'Sql Log' or 'Agent Log'
--	@FilterCondition:	'...' //Any string you searched for it throught log file (Ex: '[Text] LIKE ''%error%'' OR [Text] LIKE ''%fail%'' ')
--	@DateFrom:		'dd/mm/yyy hh:mm:ss' //Any valid datetime
--	@DateTo:		'dd/mm/yyy hh:mm:ss' //Any valid datetime
--	@SortOrder:		'asc' or 'desc'
-- =============================================SAMPLE
--USE [SqlDeep]
--GO
--declare @start datetime
--declare @end datetime
--set @start=dateadd(day,-1,getdate())
--set @end=getdate()
--exec [dbo].[dbasp_audit_readerrorlog] 0,'sql log','[Text] LIKE ''%error%'' OR [Text] LIKE ''%fail%''',@start,@end,'desc'
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_audit_readerrorlog] (
	@Logfile int=0,
	@Logfiletype nvarchar(20)=N'Sql Log',
	@FilterCondition nvarchar(255)=NULL,
	@DateFrom datetime=NULL,
	@DateTo datetime=NULL,
	@SortOrder nvarchar(4)=N'desc'
	)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @mylogfiletype int
	DECLARE @StartDate nvarchar(20)
	DECLARE @EndDate nvarchar(20)
	DECLARE @mySortOrder nvarchar(4)
	CREATE TABLE #myErrorLogInfo
	 (
		[Id] INT IDENTITY PRIMARY KEY NOT NULL,
		[LogDate]  varchar(100),
		[Processinfo] varchar(200),
		[Text]  varchar(Max)
	 )

	SET @StartDate=CASE WHEN @DateFrom IS NULL THEN NULL ELSE CAST(@DateFrom as nvarchar(20)) END
	SET @EndDate=CASE WHEN @DateFrom IS NULL THEN NULL ELSE CAST(@DateTo as nvarchar(20)) END
	SET @mylogfiletype=CASE UPPER(@Logfiletype)
							WHEN 'SQL LOG' THEN 1
							WHEN 'AGENT LOG' THEN 2
							ELSE NULL
						END
	SET @mySortOrder=CASE UPPER(@SortOrder)
							WHEN 'ASC' THEN N'asc'
							WHEN 'DESC' THEN N'desc'
							ELSE N'desc'
						END

	IF (NOT IS_SRVROLEMEMBER(N'securityadmin') = 1)
	BEGIN
		RAISERROR(15003,-1,-1, N'securityadmin')
		RETURN (1)
	END
   
	IF (@mylogfiletype IS NULL)
		INSERT INTO #myErrorLogInfo EXEC sys.xp_readerrorlog @Logfile
	ELSE
		--@SearchString1 , @SearchString2 should be nvarchar, otherwise it will raise error
		--INSERT INTO #myErrorLogInfo EXEC sys.xp_readerrorlog @Logfile,@mylogfiletype,@SearchString1,@SearchString2,@StartDate,@EndDate,@mySortOrder
		INSERT INTO #myErrorLogInfo EXEC sys.xp_readerrorlog @Logfile,@mylogfiletype,Null,Null,@StartDate,@EndDate,@mySortOrder

	IF @FilterCondition IS NOT NULL
	BEGIN
		DECLARE @mySqlStatement NVARCHAR(MAX)
		SET @mySqlStatement=CAST(N'' AS NVARCHAR(MAX))
		SET @mySqlStatement = @mySqlStatement + 'SELECT * FROM [#myErrorLogInfo] WHERE ' + CAST(@FilterCondition AS NVARCHAR(MAX))
		EXECUTE (@mySqlStatement)
	END
	ELSE
	BEGIN
		SELECT * FROM [#myErrorLogInfo]
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_audit_readerrorlog', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-21', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_audit_readerrorlog', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_audit_readerrorlog', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_audit_readerrorlog', NULL, NULL
GO
