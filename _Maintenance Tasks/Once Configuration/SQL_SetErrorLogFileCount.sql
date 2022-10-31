--ATTENTION: Replace <yourInstance> with your instance name like MSSQL15.Node or MSSQLServer
USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\<yourInstance>\MSSQLServer', N'ErrorLogSizeInKb', REG_DWORD, 10240
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\<yourInstance>\MSSQLServer', N'NumErrorLogs', REG_DWORD, 12
GO
