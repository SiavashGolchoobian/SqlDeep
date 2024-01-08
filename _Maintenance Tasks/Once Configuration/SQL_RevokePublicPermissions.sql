--Show bad permissions
SELECT
	[myPrincipals].[name] AS [Principal],
	[myObjects].[name] AS [Extended Stored Procedure],
	[myPrincipals].[type_desc] AS [Type]
FROM
	[master].[sys].[system_objects]	AS [myObjects]
	JOIN [master].[sys].[database_permissions] AS [myPermissions] ON [myObjects].[object_id] = [myPermissions].[major_id]
	JOIN [master].[sys].[database_principals] AS [myPrincipals] ON [myPermissions].[grantee_principal_id] = [myPrincipals].[principal_id]
WHERE
	(
		[myObjects].[name] LIKE 'xp_reg%'
		OR [myObjects].[name] LIKE 'xp_instance_reg%'
	)
	AND [myPermissions].[type] = 'EX'
ORDER BY
	[myObjects].[name],
	[myPrincipals].[name];
	
--Revoke bad permissions from Public role
REVOKE EXEC ON OBJECT::master.dbo.xp_instance_regread TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_regread TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_dirtree TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_fileexist TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_fixeddrives TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_getnetname TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_grantlogin TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_revokelogin TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_sprintf TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_sscanf TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_repl_convert_encrypt_sysadmin_wrapper TO Public;
REVOKE EXEC ON OBJECT::master.dbo.xp_replposteor TO Public;

--This revokation cause, non sysadmin users can't connect via SSMS, in this case you need to grant bellow permission to that specific users:
USE [master]
GO
CREATE ROLE [Role_SSMS]
GO
GRANT EXEC ON master.dbo.xp_instance_regread TO [Role_SSMS];
GO
CREATE USER [myLogin] FOR LOGIN [myLogin]
GO
ALTER ROLE [Role_SSMS] ADD MEMBER [myLogin]
GO