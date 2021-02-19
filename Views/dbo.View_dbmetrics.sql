SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE view [dbo].[View_dbmetrics] as 
select TOP 100 PERCENT
	min(dbmtr.min_snap_id) as min_snap_id,
	max(dbmtr.max_snap_id) as max_snap_id,
	min(dbmtr.min_begin_time) as min_begin_time,
	max(dbmtr.max_end_time) as max_end_time,
	dbmtr.metric_id,
	max(dbmtr.metric_name) as metric_name_original,	--
	min(dbmtr.min_minval) as min_minval,
	max(dbmtr.max_maxval) as max_maxval,
	avg(dbmtr.avg_average) as avg_average,
	max(dbmtr.metric_unit) as metric_unit_original,	--
	CASE dbmtr.metric_id
		WHEN 25 THEN 'Response Time Per Txn (secs)'
		WHEN 70 THEN 'Session Count'
		WHEN 41 THEN 'User Transaction Per Sec'
		ELSE max(dbmtr.metric_name)
	END as metric_name,
	CASE dbmtr.metric_id
		WHEN 25 THEN max(dbmtr.max_maxval)/1000
		ELSE max(dbmtr.max_maxval)
	END as maxval,
	CASE dbmtr.metric_id
		WHEN 25 THEN avg(dbmtr.avg_average)/1000
		ELSE avg(dbmtr.avg_average)
	END as average,
	CASE dbmtr.metric_id
		WHEN 25 THEN 'Sec Per Response'
		WHEN 70 THEN 'Session Per Sec'
		WHEN 41 THEN 'Transaction Per Sec'
		ELSE max(dbmtr.metric_unit)
	END as metric_unit 
from 
	dbmetrics as dbmtr
where
	dbmtr.in_work_time = 1
	and dbmtr.metric_id in (25 /*'Response Time Per Txn'*/,70 /*'Session Count'*/,41 /*'User Transaction Per Sec'*/)
group by 
	dbmtr.metric_id
order by 
	min(dbmtr.min_begin_time), 
	max(dbmtr.max_end_time)
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'VIEW', N'View_dbmetrics', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-07', 'SCHEMA', N'dbo', 'VIEW', N'View_dbmetrics', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'VIEW', N'View_dbmetrics', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'VIEW', N'View_dbmetrics', NULL, NULL
GO
