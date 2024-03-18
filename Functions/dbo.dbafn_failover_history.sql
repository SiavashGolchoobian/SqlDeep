SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <3/18/2024>
-- Version:		<3.0.0.1>
-- Description:	<Return list of failover events>
-- Input Parameters:
--	@FromTime:			Report failovers greater than this date time
--	@ToTime:			Report failovers less than this date time
-- =============================================
CREATE FUNCTION [dbo].[dbafn_failover_history] (
	@FromTime Datetime,
	@ToTime Datetime
	)
RETURNS TABLE 
RETURN 
(
	WITH myHADR AS (
		SELECT 
			object_name, 
			CONVERT(XML, event_data) AS data
		FROM 
			sys.fn_xe_file_target_read_file('AlwaysOn*.xel', null, null, null)
		WHERE 
			object_name = 'error_reported'
	)

	SELECT
		*
	FROM
		(
		SELECT 
			data.value('(/event/@timestamp)[1]','datetime') AS [timestamp],
			data.value('(/event/data[@name=''error_number''])[1]','int') AS [error_number],
			data.value('(/event/data[@name=''message''])[1]','varchar(max)') AS [message]
		FROM 
			myHADR
		WHERE 
			data.value('(/event/data[@name=''error_number''])[1]','int') = 1480
		) AS myFailoverHistory
	WHERE
		myFailoverHistory.timestamp BETWEEN ISNULL(@FromTime,DATEADD(YEAR,-1,getdate())) AND ISNULL(@ToTime,getdate())
)
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_failover_history', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2024-03-18', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_failover_history', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2024-03-18', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_failover_history', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_failover_history', NULL, NULL
GO
