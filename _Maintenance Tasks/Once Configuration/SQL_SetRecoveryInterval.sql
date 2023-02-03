USE master ;  
GO  
EXEC sp_configure 'show advanced options', 1 ;  
GO  
RECONFIGURE  
GO 
EXEC sys.sp_configure N'recovery interval (min)', N'1'
GO
RECONFIGURE WITH OVERRIDE
GO
