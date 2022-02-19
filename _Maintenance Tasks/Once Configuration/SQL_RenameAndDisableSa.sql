USE [master]
Go
IF EXISTS (SELECT name FROM sys.sql_logins WHERE sid = 0x01 and name='sa')
BEGIN
	ALTER LOGIN [sa] WITH NAME = [sqldeepsa];
	ALTER LOGIN [sqldeepsa] DISABLE;
END
Go