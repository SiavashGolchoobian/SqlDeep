## SqlDeep_ActivityMonitor (Job)



This job runs every 5 minutes and capture SQL Server sessions activity for users who their activity takes longer than 30 seconds (by default) and retain this data on **[SqlDeep]** database, in a table named **[trace].[ActivityLogHistory]** for 3 days (by default).



### Remarks

This job use **[dbo].[dbasp_activity_monitor]** stored procedure for capturing it's realtime monitored data.

SqlDeep_ActivityMonitor does not capture system processes, also it does not capture sleeping sessions.



### See Also

[dbo].[dbasp_activity_monitor] (Stored Procedure)

[trace].[ActivityLogHistory] (Table)


