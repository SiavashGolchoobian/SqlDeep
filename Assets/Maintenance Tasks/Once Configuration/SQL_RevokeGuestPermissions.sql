DECLARE @command varchar(1000)
SELECT @command = '
USE ?
IF DB_NAME() NOT IN (''master'',''msdb'',''tempdb'',''model'')
	REVOKE CONNECT FROM guest;
'
EXEC sp_MSforeachdb @command 