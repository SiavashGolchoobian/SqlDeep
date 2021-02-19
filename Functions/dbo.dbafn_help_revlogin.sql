SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Microsoft + Siavash Golchoobian>
-- Create date: <5/10/2017>
-- Version:		<3.0.0.0>
-- Description:	<Generate Create or Alter Script for logins>
-- =============================================
CREATE FUNCTION [dbo].[dbafn_help_revlogin]
(
	@login_name sysname
)
RETURNS NVARCHAR(4000)
AS
BEGIN

DECLARE @login_curs CURSOR
DECLARE @name sysname
DECLARE @type varchar (1)
DECLARE @hasaccess int
DECLARE @denylogin int
DECLARE @is_disabled int
DECLARE @PWD_varbinary  varbinary (256)
DECLARE @PWD_string  varchar (514)
DECLARE @SID_varbinary varbinary (85)
DECLARE @SID_string varchar (514)
DECLARE @tmpstr  nvarchar (4000)
DECLARE @tmpstrCreate  nvarchar (4000)
DECLARE @tmpstrAlter  nvarchar (4000)
DECLARE @tmpstrPolicyBefore  nvarchar (4000)
DECLARE @tmpstrPolicyAfter  nvarchar (4000)
DECLARE @tmpstrExpirationBefore  nvarchar (4000)
DECLARE @tmpstrExpirationAfter  nvarchar (4000)
DECLARE @is_policy_checked nvarchar (3)
DECLARE @is_expiration_checked nvarchar (3)
DECLARE @defaultdb sysname
DECLARE @answer NVARCHAR(4000) --NVARCHAR(1024)
DECLARE @myNewLine NVARCHAR(10)
DECLARE @myNewTab NVARCHAR(10)
SET @myNewLine=CHAR(13)+CHAR(10)
SET @myNewTab=CHAR(9)

IF (@login_name IS NULL)
	BEGIN	--Create Cursor 01
	SET @login_curs = CURSOR FOR
		SELECT 
			p.sid, 
			p.name, 
			p.type, 
			p.is_disabled, 
			p.default_database_name, 
			l.hasaccess, 
			l.denylogin 
		FROM 
			sys.server_principals AS p 
			LEFT JOIN sys.syslogins AS l ON ( l.name = p.name ) 
		WHERE 
			p.type IN ( 'S', 'G', 'U' ) 
			AND p.name <> 'sa'
	END		--Create Cursor 01
ELSE
	BEGIN	--Create Cursor 02
	SET @login_curs = CURSOR FOR
		SELECT 
			p.sid, 
			p.name, 
			p.type, 
			p.is_disabled, 
			p.default_database_name, 
			l.hasaccess, 
			l.denylogin 
		FROM 
			sys.server_principals AS p 
			LEFT JOIN sys.syslogins AS l ON ( l.name = p.name ) 
		WHERE 
			p.type IN ( 'S', 'G', 'U' ) 
			AND p.name = @login_name
	END		--Create Cursor 02

OPEN @login_curs
FETCH NEXT FROM @login_curs INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
IF (@@fetch_status = -1)
	BEGIN	--Check Cursor Status 01
	--Print 'No login(s) found.'
	SET @answer = NULL
	END		--Check Cursor Status 01
ELSE
	BEGIN	--Check Cursor Status 02
	SET @tmpstr = '/* sp_help_revlogin script '
	--Print @tmpstr
	SET @tmpstr = '** Generated ' + CONVERT (varchar, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
	--Print @tmpstr
	--Print ''
	WHILE (@@fetch_status <> -1)
		BEGIN	--Loop through Cursor records 01
		IF (@@fetch_status <> -2)
			BEGIN	--Check fetch status
			--Print ''
			SET @tmpstr = '-- Login: ' + @name
			--Print @tmpstr
			IF (@type IN ( 'G', 'U'))
				BEGIN	--STEP B1:NT authenticated account/group
				SET @tmpstrCreate = N'IF(SELECT [state] FROM sys.[databases] WHERE [name]=''' + @defaultdb + N''')=0' +
								@myNewLine + N'	BEGIN'+
								@myNewLine + N'		CREATE LOGIN ' + QUOTENAME( @name ) + N' FROM WINDOWS WITH DEFAULT_DATABASE = [' + @defaultdb + N']'+
								@myNewLine + N'	END'+
								@myNewLine + N'	ELSE'+
								@myNewLine + N'	BEGIN'+
								@myNewLine + N'		CREATE LOGIN ' + QUOTENAME( @name ) + N' FROM WINDOWS'+
								@myNewLine + N'	END'
				SET @tmpstrAlter = N'IF(SELECT [state] FROM sys.[databases] WHERE [name]=''' + @defaultdb + N''')=0' +
								@myNewLine + N'	BEGIN'+
								@myNewLine + N'		ALTER LOGIN ' + QUOTENAME( @name ) + N' WITH DEFAULT_DATABASE = [' + @defaultdb + N']'+
								@myNewLine + N'	END'
				SET @tmpstr =	N'IF NOT EXISTS (SELECT 1 FROM sys.[server_principals] AS myServerLogins WHERE myServerLogins.[name] = N''' + @name + N''')' + 
								@myNewLine + N'BEGIN' +
								@myNewLine + @myNewTab + @tmpstrCreate +
								@myNewLine + N'END' +
								@myNewLine + N'ELSE' +
								@myNewLine + N'BEGIN' +
								@myNewLine + @myNewTab + @tmpstrAlter +
								@myNewLine + N'END'
				END		--STEP B1
			ELSE
				BEGIN	--STEP B2:SQL Server authentication
				-- obtain password and sid
				SET @PWD_varbinary = CAST( LOGINPROPERTY( @name, 'PasswordHash' ) AS varbinary (256) )
				SET @PWD_string = dbo.dbafn_hexadecimal (@PWD_varbinary)
				SET @SID_string = dbo.dbafn_hexadecimal (@SID_varbinary)
				-- obtain password policy state
				SELECT @is_policy_checked = CASE is_policy_checked WHEN 1 THEN N'ON' WHEN 0 THEN N'OFF' ELSE NULL END FROM sys.sql_logins WHERE name = @name
				SELECT @is_expiration_checked = CASE is_expiration_checked WHEN 1 THEN N'ON' WHEN 0 THEN N'OFF' ELSE NULL END FROM sys.sql_logins WHERE name = @name

				SET @tmpstrCreate = N'IF(SELECT [state] FROM sys.[databases] WHERE [name]=''' + @defaultdb + N''')=0' +
								@myNewLine + N'	BEGIN'+
								@myNewLine + N'		CREATE LOGIN ' + QUOTENAME( @name ) + N' WITH PASSWORD = ' + @PWD_string + N' HASHED, SID = ' + @SID_string + N', DEFAULT_DATABASE = [' + @defaultdb + N']'+
								@myNewLine + N'	END'+
								@myNewLine + N'	ELSE'+
								@myNewLine + N'	BEGIN'+
								@myNewLine + N'		CREATE LOGIN ' + QUOTENAME( @name ) + N' WITH PASSWORD = ' + @PWD_string + N' HASHED, SID = ' + @SID_string +
								@myNewLine + N'	END'
				SET @tmpstrAlter = N'IF(SELECT [state] FROM sys.[databases] WHERE [name]=''' + @defaultdb + N''')=0' +
								@myNewLine + N'	BEGIN'+
								@myNewLine + N'		ALTER LOGIN ' + QUOTENAME( @name ) + N' WITH PASSWORD = ' + @PWD_string + N' HASHED, DEFAULT_DATABASE = [' + @defaultdb + N']'+
								@myNewLine + N'	END'+
								@myNewLine + N'	ELSE'+
								@myNewLine + N'	BEGIN'+
								@myNewLine + N'		ALTER LOGIN ' + QUOTENAME( @name ) + N' WITH PASSWORD = ' + @PWD_string + N' HASHED'+
								@myNewLine + N'	END'
				IF ( @is_policy_checked IS NOT NULL )
					BEGIN	--STEP B3
					SET @tmpstrPolicyBefore = N'ALTER LOGIN ' + QUOTENAME( @name ) + N' WITH CHECK_POLICY = OFF'
					SET @tmpstrPolicyAfter = N'ALTER LOGIN ' + QUOTENAME( @name ) + N' WITH CHECK_POLICY = ' + @is_policy_checked
					--SET @tmpstrCreate = @tmpstrCreate + ', CHECK_POLICY = ' + 'OFF'	--@is_policy_checked: A HASHED password cannot be set for a login that has CHECK_POLICY turned on.
					--SET @tmpstrAlter = @tmpstrAlter + ', CHECK_POLICY = ' + 'OFF'	--@is_policy_checked: A HASHED password cannot be set for a login that has CHECK_POLICY turned on.
					END		--STEP B3
				IF ( @is_expiration_checked IS NOT NULL )
					BEGIN	--STEP B4
					SET @tmpstrExpirationBefore = N'ALTER LOGIN ' + QUOTENAME( @name ) + N' WITH CHECK_EXPIRATION = OFF'
					SET @tmpstrExpirationAfter = N'ALTER LOGIN ' + QUOTENAME( @name ) + N' WITH CHECK_EXPIRATION = ' + @is_expiration_checked
					--SET @tmpstrCreate = @tmpstrCreate + ', CHECK_EXPIRATION = ' + 'OFF'	--@is_expiration_checked: The CHECK_EXPIRATION option cannot be used when CHECK_POLICY is OFF.
					--SET @tmpstrAlter = @tmpstrAlter + ', CHECK_EXPIRATION = ' + 'OFF'	--@is_expiration_checked: The CHECK_EXPIRATION option cannot be used when CHECK_POLICY is OFF.
					END		--STEP B4

				SET @tmpstr =	N'IF NOT EXISTS (SELECT 1 FROM sys.[server_principals] AS myServerLogins WHERE myServerLogins.[name] = N''' + @name + ''')' + 
								@myNewLine + N'BEGIN' +
								@myNewLine + @myNewTab + @tmpstrCreate +
								@myNewLine + @myNewTab + @tmpstrPolicyAfter +
								@myNewLine + @myNewTab + @tmpstrExpirationAfter +
								@myNewLine + N'END' +
								@myNewLine + N'ELSE' +
								@myNewLine + N'BEGIN' +
								@myNewLine + @myNewTab + @tmpstrPolicyBefore +
								@myNewLine + @myNewTab + @tmpstrExpirationBefore +
								@myNewLine + @myNewTab + @tmpstrAlter +
								@myNewLine + @myNewTab + @tmpstrPolicyAfter +
								@myNewLine + @myNewTab + @tmpstrExpirationAfter +
								@myNewLine + N'END'
				END		--STEP B2:SQL Server authentication

			IF (@denylogin = 1)
				BEGIN	--STEP B5: login is denied access
				SET @tmpstr = @tmpstr + N'; DENY CONNECT SQL TO ' + QUOTENAME( @name )
				END		--STEP B5
			ELSE IF (@hasaccess = 0)
				BEGIN	--STEP B6: login exists but does not have access
				SET @tmpstr = @tmpstr + N'; REVOKE CONNECT SQL TO ' + QUOTENAME( @name )
				END		--STEP B6

			IF (@is_disabled = 1)
				BEGIN	--STEP B7: login is disabled
				SET @tmpstr = @tmpstr + N'; ALTER LOGIN ' + QUOTENAME( @name ) + N' DISABLE'
				END		--STEP B7
			
			--Print @tmpstr
			SET @answer=@tmpstr
			END		--Check fetch status
		FETCH NEXT FROM @login_curs INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
		END		--Loop through Cursor records 01
	END		--Check Cursor Status 02

CLOSE @login_curs
DEALLOCATE @login_curs

RETURN @answer
END
GO
EXEC sp_addextendedproperty N'Author', N'Microsoft + Siavash Golchoobian', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_help_revlogin', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2013-12-18', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_help_revlogin', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-05-10', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_help_revlogin', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_help_revlogin', NULL, NULL
GO
