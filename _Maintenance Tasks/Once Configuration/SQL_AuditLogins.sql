USE [master]
GO
CREATE SERVER AUDIT [SqlDeep_TrackLogins] TO APPLICATION_LOG WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE)
--CREATE SERVER AUDIT [SqlDeep_TrackLogins] TO SECURITY_LOG WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE)	--Read bellow Note for resolving any encountered error
GO

CREATE SERVER AUDIT SPECIFICATION SqlDeep_TrackAllLogins
FOR SERVER AUDIT SqlDeep_TrackLogins
	ADD (FAILED_LOGIN_GROUP),
	ADD (SUCCESSFUL_LOGIN_GROUP),
	ADD (AUDIT_CHANGE_GROUP)
WITH (STATE = ON);
GO

ALTER SERVER AUDIT SqlDeep_TrackLogins WITH (STATE = ON);
GO

/*
Note: if you encountered bellow error after enabling Server Audit on SECURITY_LOG, you should add sql server account to bellow path in Group Policy and Reset you SQL Services:
	Computer Configurations > Windows Settings > Security Settings > Local Policies > User Right Assignments > Generate Security Audits
	OR
	Security Settings > Local Policies > User Right Assignments > Generate Security Audits
*/

/*
TITLE: Microsoft.SqlServer.Smo
------------------------------

Enable failed for Audit 'SqlDeep_TrackLogins'. 

For help, click: https://go.microsoft.com/fwlink?ProdName=Microsoft+SQL+Server&ProdVer=16.200.48036.0&EvtSrc=Microsoft.SqlServer.Management.Smo.ExceptionTemplates.FailedOperationExceptionText&EvtID=Enable+Audit&LinkId=20476

------------------------------
ADDITIONAL INFORMATION:

An exception occurred while executing a Transact-SQL statement or batch. (Microsoft.SqlServer.ConnectionInfo)

------------------------------

Audit 'SqlDeep_TrackLogins' failed to start . For more information, see the SQL Server error log. You can also query sys.dm_os_ring_buffers where ring_buffer_type = 'RING_BUFFER_XE_LOG'. (Microsoft SQL Server, Error: 33222)

For help, click: https://docs.microsoft.com/sql/relational-databases/errors-events/mssqlserver-33222-database-engine-error

------------------------------
BUTTONS:

OK
------------------------------
*/

Resource:
	https://support.microsoft.com/en-us/topic/kb4052136-fix-sql-server-audit-events-don-t-write-to-the-security-log-d9708450-6981-2fab-4e58-5f09d561110e