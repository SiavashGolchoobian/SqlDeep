--ATTENTION: Replace <yourInstance> with your instance name like MSSQL15.Node or MSSQLServer
USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\Microsoft SQL Server\<yourInstance,Like:MSSQL15.NODE>\MSSQLServer', N'ErrorLogSizeInKb', REG_DWORD, 10240
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\Microsoft SQL Server\<yourInstance,Like:MSSQL15.NODE>\MSSQLServer', N'NumErrorLogs', REG_DWORD, 12
GO
