SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Zahra Saffarpour>
-- Create date: <8/27/2018>
-- Version:		<3.0.0.0>
-- Description:	<add role or remove role from login>
-- Input Parameters:
--	@DatabaseNames: '<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@Login:		
--	@AddRoles:	
--	@RemoveRoles:	
--	@PrintOnly:		0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_management_login]
(
	@DatabaseNames NVARCHAR(MAX) = NULL ,
	@Login NVARCHAR(50) = NULL ,
	@AddRoles NVARCHAR(50) = NULL ,
	@RemoveRoles NVARCHAR(50) = NULL ,
	@PrintOnly BIT = 0
)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @NewLine VARCHAR(50)
	DECLARE @2008Version BIT

	IF (@@VERSION LIKE '%2008%')
		SET @2008Version  = 1
	ELSE
		SET @2008Version = 0

	SET @NewLine = CHAR(13) + CHAR(10)
	SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
		
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @mySQLScript = CAST(N'' AS NVARCHAR(MAX))
		SET @mySQLScript = N'USE ' + QUOTENAME(@Database_Name) + ';' + @NewLine 
		SET @mySQLScript = @mySQLScript + N'IF EXISTS (SELECT 1 FROM master.sys.syslogins WHERE name LIKE ''' + @Login + ''') AND NOT EXISTS(SELECT 1 FROM sys.sysusers WHERE name = ''' + @Login +''')' + @NewLine 
		SET @mySQLScript = @mySQLScript + N'	CREATE USER ['+ @Login +'] FOR LOGIN ['+ @Login +']; ' + @NewLine 
		SET @mySQLScript = @mySQLScript + N'ALTER USER ['+ @Login +'] WITH LOGIN = ['+ @Login +'];' + @NewLine
		--==Drop Role
		IF(@RemoveRoles IS NOT NULL AND @RemoveRoles != '')
		BEGIN
			SELECT @mySQLScript = @mySQLScript + N'IF EXISTS( SELECT 1 FROM sys.sysusers AS mySYSUsers ' + @NewLine + 
			N'			 RIGHT JOIN  sys.database_role_members AS myDatabaseRoleMembers ON mySYSUsers.uid = myDatabaseRoleMembers.member_principal_id '+ @NewLine +
			N'			 INNER JOIN sys.database_principals AS myDatabasePrincipals ON myDatabaseRoleMembers.role_principal_id =  myDatabasePrincipals.principal_id ' + @NewLine +
			N'			 WHERE mySYSUsers.name = ''' + @Login + ''' AND myDatabasePrincipals.name IN ('''+ REPLACE(@RemoveRoles , ',', ''',''') + '''))'+ @NewLine +
			N'BEGIN' + @NewLine  
			IF (@2008Version = 1)
			BEGIN
				SELECT @mySQLScript = @mySQLScript + N'	EXEC sp_droprolemember N''' + Parameter + ''' , N''' + @Login + ''';' + @NewLine 
				FROM dbo.[dbafn_split](',' , @RemoveRoles)
			END
			ELSE
			BEGIN				
				SELECT @mySQLScript = @mySQLScript + N'	ALTER ROLE [' + Parameter +'] DROP MEMBER ['+ @Login +'];' + @NewLine 
				FROM dbo.[dbafn_split](',' , @RemoveRoles)
			END
			SET @mySQLScript = @mySQLScript + N'END' + @NewLine 
		END
		--==Add Role
		IF(@AddRoles IS NOT NULL AND @AddRoles != '')
		BEGIN
			IF (@2008Version = 1)
			BEGIN
				SELECT @mySQLScript = @mySQLScript + N'EXEC sp_addrolemember N''' + Parameter + ''' , N''' + @Login + ''';' + @NewLine 
				FROM dbo.[dbafn_split](',' , @AddRoles)		
			END
			ELSE
			BEGIN
				SELECT @mySQLScript = @mySQLScript + N'ALTER ROLE ['+ Parameter +'] ADD MEMBER ['+ @Login +'] ;' + @NewLine 
				FROM dbo.[dbafn_split](',' , @AddRoles)		
			END
		END
		PRINT @mySQLScript
		IF @PrintOnly = 0
			EXECUTE (@mySQLScript)
		PRINT '--======================================================================='
		FETCH NEXT FROM @myCursor INTO @Database_Name
	END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_management_login', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2018-08-27', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_management_login', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_management_login', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_management_login', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_management_login', NULL, NULL
GO
