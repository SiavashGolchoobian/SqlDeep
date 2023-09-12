EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'remote access', 0;
RECONFIGURE;
GO 
EXECUTE sp_configure 'show advanced options', 0;
RECONFIGURE;