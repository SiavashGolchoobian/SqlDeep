SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <9/25/2013>
-- Version:		<3.0.0.0>
-- Description:	<aggregate perfmon data>
-- Input Parameters:
--	@from_date:	any datetime
--	@to_date:	any datetime
-- =============================================
CREATE procedure [dbo].[db_get_dbmetrics_p] (
	@from_date datetime,
	@to_date datetime
	)
as
begin
	-- Fill indicators data for work time period
	insert into [dbo].[dbmetrics](
					min_snap_id,
					max_snap_id,
					min_begin_time,
					max_end_time,
					metric_id,
					metric_name,
					min_minval,
					max_maxval,
					avg_average,
					metric_unit,
					in_work_time)
	select			min(RecordIndex) as min_snap_id
					,max(RecordIndex) as max_snap_id
					,CONVERT(datetime,LEFT(min(myData.CounterDateTime), 19), 120) as min_begin_time
					,CONVERT(datetime,LEFT(max(myData.CounterDateTime), 19), 120) as max_end_time
					,mydef.CounterID as metric_id
					,ISNULL(max(mydef.ObjectName),'') + ' - ' + ISNULL(max(mydef.CounterName),'') + ' (' + ISNULL(max(mydef.InstanceName),'') + ')' As metric_name
					,min(myData.CounterValue) As min_minval
					,max(myData.CounterValue) As max_maxval
					,avg(myData.CounterValue) As avg_average
					,max(mydef.CounterName) as metric_unit
					,1 as in_work_time
	from dbo.CounterData as myData
	inner join [dbo].[CounterDetails] as myDef on mydata.CounterID=myDef.CounterID
	where CONVERT(datetime,LEFT(myData.CounterDateTime, 19), 120) between @from_date and @to_date and
		  CAST(CONVERT(datetime,LEFT(myData.CounterDateTime, 19), 120) AS time(0)) BETWEEN '07:00:00' AND '16:00:00'
	group by mydef.CounterID
	order by mydef.CounterID
	
	-- Fill indicators data for out of work time period
	insert into [dbo].[dbmetrics](
					min_snap_id,
					max_snap_id,
					min_begin_time,
					max_end_time,
					metric_id,
					metric_name,
					min_minval,
					max_maxval,
					avg_average,
					metric_unit,
					in_work_time)
	select			min(RecordIndex) as min_snap_id
					,max(RecordIndex) as max_snap_id
					,CONVERT(datetime,LEFT(min(myData.CounterDateTime), 19), 120) as min_begin_time
					,CONVERT(datetime,LEFT(max(myData.CounterDateTime), 19), 120) as max_end_time
					,mydef.CounterID as metric_id
					,ISNULL(max(mydef.ObjectName),'') + ' - ' + ISNULL(max(mydef.CounterName),'') + ' (' + ISNULL(max(mydef.InstanceName),'') + ')' As metric_name
					,min(myData.CounterValue) As min_minval
					,max(myData.CounterValue) As max_maxval
					,avg(myData.CounterValue) As avg_average
					,max(mydef.CounterName) as metric_unit
					,0 as in_work_time
	from dbo.CounterData as myData
	inner join [dbo].[CounterDetails] as myDef on mydata.CounterID=myDef.CounterID
	where CONVERT(datetime,LEFT(myData.CounterDateTime, 19), 120) between @from_date and @to_date and
		  (CAST(CONVERT(datetime,LEFT(myData.CounterDateTime, 19), 120) AS time(0)) BETWEEN '16:00:01' AND '23:59:59' or
		  CAST(CONVERT(datetime,LEFT(myData.CounterDateTime, 19), 120) AS time(0)) BETWEEN '00:00:01' AND '06:59:59')
	group by mydef.CounterID
	order by mydef.CounterID
end

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'db_get_dbmetrics_p', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2013-09-25', 'SCHEMA', N'dbo', 'PROCEDURE', N'db_get_dbmetrics_p', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'db_get_dbmetrics_p', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'db_get_dbmetrics_p', NULL, NULL
GO
