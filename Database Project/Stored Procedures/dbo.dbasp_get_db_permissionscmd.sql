SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/16/2024>
-- Version:		<3.0.0.0>
-- Description:	<Get database permissions command, give you command to create database user + it's database level roles + it's database level permission>
-- Input Parameters:
--	@DatabaseName:		name of database
-- =============================================
CREATE Procedure [dbo].[dbasp_get_db_permissionscmd] (@DatabaseName sysname) AS
BEGIN
	DECLARE @myCommand NVARCHAR(4000)
	SET @myCommand=N'
	SELECT
		N''' + @DatabaseName + ''' AS DatabaseName,
		N''USE [' + @DatabaseName + N']; IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].[sys].[database_principals] AS myDatabaseLogins WITH (READPAST) WHERE [myDatabaseLogins].[name] = '''''' + CAST([myDBUser].[name] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) +N'''''') CREATE USER ['' + CAST([myDBUser].[name] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) + N''] FOR LOGIN ['' + CAST([myDBUser].[name] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) + N'']; ALTER ROLE ['' + CAST([myDBRole].[name] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) + N''] ADD MEMBER ['' + CAST([myDBUser].[name] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) + ''];'' AS Command
	FROM
		[' + @DatabaseName + '].[sys].[database_role_members] AS [myDbRoleMembers]
		INNER JOIN [' + @DatabaseName + '].[sys].[database_principals] AS [myDBRole] ON [myDbRoleMembers].[role_principal_id] = [myDBRole].[principal_id]
		INNER JOIN [' + @DatabaseName + '].[sys].[database_principals] AS [myDBUser] ON [myDbRoleMembers].[member_principal_id] = [myDBUser].[principal_id]
		INNER JOIN [master].[sys].[server_principals] AS myLogins ON [myDBUser].[sid]=[myLogins].[sid]
	WHERE
		[myDBRole].[type] = ''R''
		AND [myDBUser].[name] NOT IN (''dbo'')
	UNION ALL
	SELECT 
		N''' + @DatabaseName + ''' AS DatabaseName,
		N''USE [' + @DatabaseName + N']; IF NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + '].[sys].[database_principals] AS myDatabaseLogins WITH (READPAST) WHERE [myDatabaseLogins].[name] = '''''' + CAST([myLogins].[name] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) +N'''''') CREATE USER ['' + CAST([myLogins].[name] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) + N''] FOR LOGIN ['' + CAST([myLogins].[name] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) + N'']; ''+ CAST([myPermissions].[state_desc] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX))+ N'' '' + CAST([myPermissions].[permission_name] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) + CASE WHEN [myPermissions].[major_id] <> 0 THEN N'' ON ['' + CAST(OBJECT_SCHEMA_NAME([myPermissions].[major_id]) COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) + N''].['' + CAST(OBJECT_NAME([myPermissions].[major_id]) COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) + N''] '' ELSE N'''' END + N'' TO ['' + CAST([myDbUsers].[name] COLLATE SQL_Latin1_General_CP1_CI_AI AS NVARCHAR(MAX)) + N''];'' AS Command
	FROM 
		[' + @DatabaseName + '].[sys].[database_permissions] AS myPermissions
		INNER JOIN [' + @DatabaseName + '].[sys].[database_principals] AS myDbUsers ON myPermissions.grantee_principal_id=myDbUsers.principal_id
		INNER JOIN [master].[sys].[server_principals] AS myLogins ON myDbUsers.sid=myLogins.sid
	WHERE
		[myPermissions].[type] NOT IN (''CO'')
	'
	IF @DatabaseName NOT IN ('master','msdb','model','tempdb')
	BEGIN
		Print @myCommand
		EXEC sp_executesql @myCommand
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_db_permissionscmd', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2021-03-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_db_permissionscmd', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-03-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_db_permissionscmd', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_get_db_permissionscmd', NULL, NULL
GO
