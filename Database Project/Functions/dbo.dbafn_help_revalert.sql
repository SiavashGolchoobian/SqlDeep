SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Siavash Golchoobian>
-- Create date: <5/31/2017>
-- Version:		<3.0.0.0>
-- Description:	<Generate Create Script for Alerts>
-- =============================================
CREATE FUNCTION [dbo].[dbafn_help_revalert]
(
	@alert_name sysname
)
RETURNS NVARCHAR(4000)
AS
BEGIN

	DECLARE @myAnswer NVARCHAR(1024)
	DECLARE @myNewLine NVARCHAR(10)
	DECLARE @myTab NVARCHAR(10)
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myTab=CHAR(9)

	SELECT
		--myUntrimmedCommand.[AlertName],
		@myAnswer = ISNULL(@myAnswer,'') + 'IF NOT EXISTS (SELECT 1 FROM [msdb].[dbo].[sysalerts] AS myCurrentAlerts WHERE myCurrentAlerts.name=N''' + [myUntrimmedCommand].[AlertName] + ''') ' + @myNewLine + N'BEGIN' + @myNewLine + @myTab + LEFT(myUntrimmedCommand.[AlertCommand],LEN(myUntrimmedCommand.[AlertCommand])-3) + @myNewLine + N'END' + @myNewLine
	FROM
		(
		SELECT 
			[myAlerts].[name] AS AlertName,
			CASE WHEN [myAlerts].[performance_condition] IS NOT NULL THEN
				N'DECLARE @myPerformance_condition' + CAST([myAlerts].[id] AS NVARCHAR(10)) + N' NVARCHAR(512)' + @myNewLine +
				N'SET @myPerformance_condition' + CAST([myAlerts].[id] AS NVARCHAR(10)) + N' = ' + COALESCE(
																 --'N''' + STUFF([myAlerts].[performance_condition],PATINDEX(N'%MSSQL$'+@@SERVICENAME+'%',[myAlerts].[performance_condition]),LEN(N'MSSQL$'+@@SERVICENAME),N'MSSQL$'' + @@SERVICENAME + ''') + ''''
																 'N''' + REPLACE([myAlerts].[performance_condition],N'MSSQL$'+@@SERVICENAME+':',N'') + ''''
																,'N''' + [myAlerts].[performance_condition] + ''''
																, N'NULL' + ''''
															)
			ELSE N'' END + @myNewLine +
			CASE WHEN [myAlerts].[database_name] IS NOT NULL AND [myAlerts].[event_id] IS NOT NULL THEN
				N'DECLARE @myWmi_namespace' + CAST([myAlerts].[id] AS NVARCHAR(10)) + ' sysname' + @myNewLine +
				N'SET @myWmi_namespace' + CAST([myAlerts].[id] AS NVARCHAR(10)) + ' = ' + COALESCE(
																 'N''' + STUFF([myAlerts].[database_name],PATINDEX(N'%\'+@@SERVICENAME+'%',[myAlerts].[database_name]),LEN(N'\' + @@SERVICENAME),N'\'' + @@SERVICENAME + ''') + ''''
																,'N''' + [myAlerts].[database_name] + ''''
																, N'NULL' + ''''
															)
			ELSE N'' END + @myNewLine +
			N'EXEC msdb.dbo.sp_add_alert ' + @myNewLine +
				ISNULL('@name=N''' + [myAlerts].[name] + ''',' + @myNewLine ,'') +
				ISNULL('@message_id=' + CAST([myAlerts].[message_id] AS NVARCHAR) + ',' + @myNewLine ,'') +
				ISNULL('@severity=' + CAST([myAlerts].[severity] AS NVARCHAR) + ',' + @myNewLine ,'') +
				ISNULL('@enabled=' + CAST([myAlerts].[enabled] AS NVARCHAR) + ',' + @myNewLine ,'') +
				ISNULL('@delay_between_responses=' + CAST([myAlerts].[delay_between_responses] AS NVARCHAR) + ',' + @myNewLine ,'') +
				ISNULL('@notification_message=N''' + [myAlerts].[notification_message] + ''',' + @myNewLine ,'') +
				ISNULL('@include_event_description_in=' + CAST([myAlerts].[include_event_description] AS NVARCHAR) + ',' + @myNewLine ,'') +
				ISNULL('@database_name=N''' + CASE WHEN [myAlerts].[event_id] IS NULL THEN [myAlerts].[database_name] ELSE NULL END + ''',' + @myNewLine ,'') +
				ISNULL('@event_description_keyword=N''' + [myAlerts].[event_description_keyword] + ''',' + @myNewLine ,'') +
				ISNULL('@category_name=N''' + [myCategory].[name] + ''',' + @myNewLine ,'') +
				ISNULL('@job_name=N''' + [myJobs].[name] + ''',' + @myNewLine ,'') +
				--ISNULL('@performance_condition=N''' + CASE WHEN [myAlerts].[event_id] IS NULL THEN [myAlerts].[performance_condition] ELSE NULL END + ''',' + @myNewLine ,'') +
				ISNULL('@performance_condition=' + CASE WHEN [myAlerts].[event_id] IS NULL AND [myAlerts].[performance_condition] IS NOT NULL THEN N'@myPerformance_condition' + CAST([myAlerts].[id] AS NVARCHAR(10)) + ',' ELSE NULL END + @myNewLine ,'') +
				--ISNULL('@wmi_namespace=N''' + CASE WHEN [myAlerts].[event_id] IS NOT NULL THEN [myAlerts].[database_name] ELSE NULL END + ''',' + @myNewLine ,'') +
				ISNULL('@wmi_namespace=' + CASE WHEN [myAlerts].[event_id] IS NOT NULL THEN N'@myWmi_namespace' + CAST([myAlerts].[id] AS NVARCHAR(10)) + ',' ELSE NULL END + @myNewLine ,'') +
				ISNULL('@wmi_query=N''' + CASE WHEN [myAlerts].[event_id] IS NOT NULL THEN [myAlerts].[performance_condition] ELSE NULL END + ''',' + @myNewLine ,'') AS AlertCommand
		FROM 
			[msdb].[dbo].[sysalerts] AS myAlerts
			LEFT OUTER JOIN [msdb].[dbo].[syscategories] AS myCategory ON [myCategory].[category_id] = [myAlerts].[category_id]
			LEFT OUTER JOIN [msdb].[dbo].[sysjobs] AS myJobs ON [myJobs].[job_id] = [myAlerts].[job_id]
		WHERE
			[myAlerts].[name]=@alert_name OR @alert_name IS NULL
		) AS myUntrimmedCommand

RETURN @myAnswer
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_help_revalert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-05-31', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_help_revalert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-05-31', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_help_revalert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_help_revalert', NULL, NULL
GO
