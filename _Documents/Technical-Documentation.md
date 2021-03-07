SqlDeep scripts can be categorized as below

# Jobs

#### [SqlDeep_ActivityMonitor](https://github.com/SiavashGolchoobian/SqlDeep/wiki/SqlDeep_ActivityMonitor)

This job capture active user sessions (non sleeping) with more than 30 seconds activity after sending it's last request.

#### [SqlDeep_FullBackup](https://github.com/SiavashGolchoobian/SqlDeep/wiki/SqlDeep_FullBackup)

This job take full backup on multiple files (for performance purpose) and put it in a structured folder. Also this job deleting old backup files from specified location.

#### SqlDeep_DiffBackup

This job take differential backup on multiple files (for performance purpose) and put it in a structured folder.

#### SqlDeep_LogBackup

This job take log backup, put it in a structured folder and finally shrinking log file to specified value.

#### SqlDeep_Reindex

This job rebuilding and reorganizing indexes automatically and finally updating statistics.

#### SqlDeep_CheckDB

This job executing DBCC CHECKDB without locking table(s).

#### SqlDeep_KillOpenSessions

This job kill regular idle sessions and also sysadmin sessions.

#### SqlDeep_RecycleErrorLog

This job create new SQL Server error log, if it's size is more than 10MB.

#### SqlDeep_Purge_JobHistory

This job purging SQL Server agent history.

#### SqlDeep_ReportCleanup

This job removes SQL Agent reports.

#### SqlDeep_TimeSyncronization

This job force server to sync it self with it's NTP server.

#### SqlDeep_SetUniformExtent

Force user databases to use uniform extent.

#### SqlDeep_Suspected_Page_Detection

Detet suspected pages in database and inform admins via email notification.

#### SqlDeep_BoostOn

Boost-on server processing power by removing Idle state of CPU.

#### SqlDeep_BoostOff

Return server to normall state if it was boosted.

#### SqlDeep_PolicyChecks

Check pre-defined policies such as traceflags control, data file size, ... on all databases.

# Alerts

SqlDeep_Alert_AG_Data_Movement_Resumed

SqlDeep_Alert_AG_Data_Movement_Suspended

SqlDeep_Alert_Deadlocks

SqlDeep_Alert_Error825_ReadRetryRequired

SqlDeep_Alert_HighTransactions

SqlDeep_Alert_HighUserConnections

SqlDeep_Alert_LowCacheHitRatio

SqlDeep_Alert_OpenedTransaction

SqlDeep_Alert_Sev19_FatalErrorInResource

SqlDeep_Alert_Sev20_FatalErrorInCurrentProcess

SqlDeep_Alert_Sev21_FatalErrorInDatabaseProcess

SqlDeep_Alert_Sev22_FatalErrorTableIntegritySuspect

SqlDeep_Alert_Sev23_FatalErrorDatabaseIntegritySuspect

SqlDeep_Alert_Sev24_FatalHardwareError

SqlDeep_Alert_Sev25_FatalError

# Extended Events

SqlDeep_Capture_Deadlock

SqlDeep_Capture_Blocking

SqlDeep_Capture_PageSplit

# Policies

SqlDeep_CheckDataFileSizing

SqlDeep_CheckExtendedProperties

SqlDeep_CheckSameFileSize

SqlDeep_CheckTraceFlags

# Functions and Stored Procedures
