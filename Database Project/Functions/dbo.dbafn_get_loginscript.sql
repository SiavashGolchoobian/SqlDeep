SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Siavash Golchoobian>
-- Create date: <12/27/2024>
-- Version:		<3.0.0.1>
-- Description:	<Generate Create or Alter Script for logins>
-- =============================================
CREATE FUNCTION [dbo].[dbafn_get_loginscript]
(
	@LoginName sysname
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	DECLARE @myLoginCursor CURSOR
	DECLARE @myLoginName sysname
	DECLARE @mySidString VARCHAR(514)
	DECLARE @myLoginType CHAR(1)
	DECLARE @myIsDisabled BIT
	DECLARE @myDefaultDatabaseName sysname
	DECLARE @myDefaultLanguageName sysname
	DECLARE @myIsPolicyChecked BIT
	DECLARE @myIsExperationChecked BIT
	DECLARE @myHashedPasswordString NVARCHAR(514)
	DECLARE @myAnswer NVARCHAR(MAX)
	DECLARE @myStatement NVARCHAR(MAX)
	DECLARE @myTemplateOfCreateSqlLogin NVARCHAR(MAX)
	DECLARE @myTemplateOfCreateWinLogin NVARCHAR(MAX)
	DECLARE @myTemplateOfAlterSqlLogin NVARCHAR(MAX)
	DECLARE @myTemplateOfAlterWinLogin NVARCHAR(MAX)
	DECLARE @myTemplateOfDefaultDatabase NVARCHAR(MAX)
	DECLARE @myTemplateOfDisableLogin NVARCHAR(MAX)
	DECLARE @myNewLine NVARCHAR(10)

	SET @myAnswer=NULL
	SET @myStatement=NULL
	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myTemplateOfCreateSqlLogin=N'CREATE LOGIN [<@myLoginName>] WITH Password=<@myHashedPasswordString> HASHED, SID=<@mySidString>, DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[<@myDefaultLanguageName>], CHECK_EXPIRATION=<@myIsExperationChecked>, CHECK_POLICY=<@myIsPolicyChecked>;'
	SET @myTemplateOfCreateWinLogin=N'CREATE LOGIN [<@myLoginName>] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[<@myDefaultLanguageName>];'
	SET @myTemplateOfAlterSqlLogin=N'
	IF EXISTS (SELECT 1 FROM [master].[sys].[sql_logins] WHERE [name]=''<@myLoginName>'' AND [master].[sys].[fn_varbintohexstr](CAST([password_hash] AS VARBINARY(MAX)))=N''<@myHashedPasswordString>'')
	BEGIN
		ALTER LOGIN [<@myLoginName>] WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[<@myDefaultLanguageName>], CHECK_EXPIRATION=<@myIsExperationChecked>, CHECK_POLICY=<@myIsPolicyChecked>;
	END
	ELSE
	BEGIN
		ALTER LOGIN [<@myLoginName>] WITH Password=<@myHashedPasswordString> HASHED, DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[<@myDefaultLanguageName>], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;
		ALTER LOGIN [<@myLoginName>] WITH CHECK_EXPIRATION=<@myIsExperationChecked>, CHECK_POLICY=<@myIsPolicyChecked>;
	END'
	SET @myTemplateOfAlterWinLogin=N'ALTER LOGIN [<@myLoginName>] WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[<@myDefaultLanguageName>];'
	SET @myTemplateOfDefaultDatabase=N'IF(SELECT [state] FROM [master].[sys].[databases] WITH (READPAST) WHERE [name]=''<@myDefaultDatabaseName>'')=0
		ALTER LOGIN [<@myLoginName>] WITH DEFAULT_DATABASE=[<@myDefaultDatabaseName>];'
	SET @myTemplateOfDisableLogin=N'ALTER LOGIN [<@myLoginName>] <@myIsDisabled>;'
	SET @myLoginCursor = CURSOR FOR

	SELECT
		[myLogins].[name] AS LoginName,
		CAST([master].[sys].[fn_varbintohexstr]([myLogins].[sid]) AS VARCHAR(514)) AS [SidString],
		[myLogins].[type] AS LoginType,
		[myLogins].[is_disabled] AS IsDisabled,
		[myLogins].[default_database_name] AS DefaultDatabaseName,
		[myLogins].[default_language_name] AS DefaultLanguageName,
		[mySqlLogins].[is_policy_checked] AS IsPolicyChecked,
		[mySqlLogins].[is_expiration_checked] AS IsExperationChecked,
		CASE WHEN [mySqlLogins].[password_hash] IS NOT NULL THEN [master].[sys].[fn_varbintohexstr](CAST([mySqlLogins].[password_hash] AS VARBINARY(MAX))) ELSE N'' END AS HashedPasswordString
	FROM
		[master].[sys].[server_principals] AS myLogins WITH (READPAST)
		LEFT OUTER JOIN [master].[sys].[sql_logins] AS mySqlLogins WITH (READPAST) ON [myLogins].[sid]=[mySqlLogins].[sid]
	WHERE
		[myLogins].[type] IN ('S', 'G', 'U') 
		AND [myLogins].[sid] <> 0x01	--sa
		AND [myLogins].[name] NOT LIKE '##%'
		AND [myLogins].[name] NOT LIKE 'NT SERVICE\%'
		AND CASE WHEN @LoginName IS NULL THEN '' ELSE [myLogins].[name] END = CASE WHEN @LoginName IS NULL THEN '' ELSE @LoginName END
	ORDER BY
		[myLogins].[name]

	--Generate CREATE/ALTER login script
	OPEN @myLoginCursor
	FETCH NEXT FROM @myLoginCursor INTO @myLoginName,@mySidString,@myLoginType,@myIsDisabled,@myDefaultDatabaseName,@myDefaultLanguageName,@myIsPolicyChecked,@myIsExperationChecked,@myHashedPasswordString
	WHILE @@Fetch_Status = 0
	BEGIN
		IF @myAnswer IS NULL
			SET @myAnswer=CAST(N'' AS NVARCHAR(MAX))
		SET @myStatement=CAST('' AS NVARCHAR(MAX))
		SET @myStatement=@myStatement +
		CAST(
		@myNewLine+ '/* Login: ' + CAST(@myLoginName AS NVARCHAR(MAX))+' */'+
		@myNewLine+ N'USE [master];'+
		@myNewLine+ N'IF NOT EXISTS (SELECT 1 FROM [master].[sys].[server_principals] AS myLogins WITH (READPAST) WHERE [myLogins].[name]=''<@myLoginName>'')'+
		@myNewLine+ N'BEGIN'+
		@myNewLine+ CASE @myLoginType
				WHEN 'S' THEN @myTemplateOfCreateSqlLogin
				WHEN 'G' THEN @myTemplateOfCreateWinLogin
				WHEN 'U' THEN @myTemplateOfCreateWinLogin
			END+
		@myNewLine+ N'END'+
		@myNewLine+ N'ELSE'+
		@myNewLine+ N'BEGIN'+
		@myNewLine+ CASE @myLoginType
				WHEN 'S' THEN @myTemplateOfAlterSqlLogin
				WHEN 'G' THEN @myTemplateOfAlterWinLogin
				WHEN 'U' THEN @myTemplateOfAlterWinLogin
			END+
		@myNewLine+ N'END'+
		@myNewLine+ @myTemplateOfDefaultDatabase+
		@myNewLine+ @myTemplateOfDisableLogin
		AS NVARCHAR(MAX))
		SET @myStatement=REPLACE(@myStatement,'<@myLoginName>',@myLoginName)
		SET @myStatement=REPLACE(@myStatement,'<@mySidString>',@mySidString)
		SET @myStatement=REPLACE(@myStatement,'<@myIsDisabled>',CASE WHEN @myIsDisabled=1 THEN 'DISABLE' ELSE 'ENABLE' END)
		SET @myStatement=REPLACE(@myStatement,'<@myDefaultDatabaseName>',@myDefaultDatabaseName)
		SET @myStatement=REPLACE(@myStatement,'<@myDefaultLanguageName>',@myDefaultLanguageName)
		SET @myStatement=REPLACE(@myStatement,'<@myIsPolicyChecked>',CASE @myIsPolicyChecked WHEN 1 THEN 'ON' ELSE 'OFF' END)
		SET @myStatement=REPLACE(@myStatement,'<@myIsExperationChecked>',CASE @myIsExperationChecked WHEN 1 THEN 'ON' ELSE 'OFF' END)
		SET @myStatement=REPLACE(@myStatement,'<@myHashedPasswordString>',@myHashedPasswordString)
		SET @myAnswer=@myAnswer+@myStatement+@myNewLine
		FETCH NEXT FROM @myLoginCursor INTO @myLoginName,@mySidString,@myLoginType,@myIsDisabled,@myDefaultDatabaseName,@myDefaultLanguageName,@myIsPolicyChecked,@myIsExperationChecked,@myHashedPasswordString
	END
	CLOSE @myLoginCursor;
	DEALLOCATE @myLoginCursor;
	RETURN @myAnswer
END
GO
