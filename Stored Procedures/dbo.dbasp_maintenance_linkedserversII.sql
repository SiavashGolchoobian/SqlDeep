SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Zahra Saffarpour>
-- Create date: <3/14/2020>
-- Version:		<3.0.0.0>
-- Description:	<change LinkedServer target>
-- Input Parameters:
--	@ServerName:		'xxx' //Name of linkedserver according to Name field in sys.Servers 
--	@DataSource:		'xxx' 
--	@RemotUsername:		'xxx' 
--	@RemotPassword:		'xxx' 
--	@RemotDatabase:		'xxx' 
--	@RPCEnabled:		'xxx' 
--	@AllowCreate:		'xxx' 
--	@PrintOnly:			'xxx' 
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_linkedserversII] 
(
	@ServerName VARCHAR(50) ,
	@DataSource VARCHAR(50), 
	@RemotUsername VARCHAR(50), 
	@RemotPassword VARCHAR(50), 
	@RemotDatabase VARCHAR(50), 
	@RPCEnabled BIT = 0, 
	@CreateLinkServer BIT = 0,
	@DropLinkServer BIT = 0,
	@ChangeOption BIT = 0,
	@PrintOnly BIT=0
)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myServerName VARCHAR(50)
	DECLARE @myIsSubscriber BIT;
	DECLARE @myDataSource NVARCHAR(50);
	DECLARE @myRemotUsername NVARCHAR(50);
	DECLARE @myRemotPassword NVARCHAR(50);
	DECLARE @myRemotDatabase NVARCHAR(50);
	DECLARE @myDataAccessEnabled BIT;
	DECLARE @myRpcEnabled BIT;
	DECLARE @myCursor Cursor;
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myScript NVARCHAR(MAX)

	SET @myNewLine = CHAR(13) + CHAR(10)

	DECLARE @myServer AS TABLE (ServerName VARCHAR(50), DataSource VARCHAR(50), RemotUsername VARCHAR(50), RemotPassword VARCHAR(50), RemotDatabase VARCHAR(50), DataAccessEnabled BIT,RpcEnabled BIT)
	DECLARE @LinkServer AS TABLE(ServerName VARCHAR(50), IsSubscriber BIT, DataSource VARCHAR(50), RemotUsername VARCHAR(50), RemotPassword VARCHAR(50), RemotDatabase VARCHAR(50), DataAccessEnabled BIT,RpcEnabled BIT)

	INSERT INTO @myServer(ServerName, DataSource, RemotUsername, RemotPassword,RemotDatabase, RPCEnabled)
	VALUES (@ServerName, @DataSource, @RemotUsername, @RemotPassword, @RemotDatabase,@RPCEnabled)

	;WITH myLinkServer
	AS 
	(
		SELECT server_id 
		FROM sys.linked_logins 
		WHERE remote_name IS NOT NULL 
	)
	INSERT INTO @LinkServer (ServerName, IsSubscriber, DataSource, RemotUsername, RemotPassword, RemotDatabase, DataAccessEnabled, RpcEnabled)
	SELECT	CASE WHEN myServer.name IS NULL THEN tmpServer.ServerName ELSE myServer.name END  
		   ,CASE WHEN myServer.name IS NOT NULL AND myServer.is_subscriber = 0 THEN 1 ELSE 0 END
		   ,tmpServer.DataSource, tmpServer.RemotUsername, tmpServer.RemotPassword, tmpServer.RemotDatabase
		   ,CASE WHEN myServer.name  IS NULL THEN 1 ELSE myServer.is_data_access_enabled END, tmpServer.RpcEnabled
	FROM @myServer AS tmpServer
	LEFT JOIN sys.Servers AS myServer ON LOWER(myServer.name) COLLATE SQL_Latin1_General_CP1256_CI_AS LIKE LOWER(tmpServer.ServerName) COLLATE SQL_Latin1_General_CP1256_CI_AS 
	LEFT JOIN myLinkServer ON myServer.server_id = myLinkServer.server_id 

	SET @myCursor = CURSOR For
		 SELECT ServerName, IsSubscriber, DataSource, RemotUsername, RemotPassword, RemotDatabase, DataAccessEnabled, RpcEnabled
		 FROM @LinkServer
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @myServerName, @myIsSubscriber, @myDataSource, @myRemotUsername,@myRemotPassword,@myRemotDatabase,@myDataAccessEnabled, @myRpcEnabled
	WHILE @@FETCH_STATUS = 0  
		BEGIN
			SET @myScript = CAST('' AS NVARCHAR(MAX))
			IF(@myIsSubscriber = 1 AND @DropLinkServer = 1)
				SET @myScript = @myScript + 'EXECUTE master.dbo.sp_dropserver @server=N''' + @myServerName + ''', @droplogins=''droplogins'';' + @myNewLine

			IF ((@CreateLinkServer = 1 OR @myIsSubscriber = 1) AND @DropLinkServer = 1)
			BEGIN
				SET @myScript = @myScript + 'EXECUTE master.dbo.sp_addlinkedserver @server = N''' + @myServerName + ''', @srvproduct=N''' + @myDataSource + ''', @provider=N''SQLOLEDB'', @datasrc=N'''+ @myDataSource ;
				SET @myScript = @myScript + '''' + CASE WHEN @myRemotDatabase IS NOT NULL THEN ',@catalog =''' + @myRemotDatabase + ''''ELSE ';' END + @myNewLine 	
				SET @myScript = @myScript + 'EXECUTE master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N''' + @myServerName + ''', @locallogin = NULL , @useself = N''False'', @rmtuser = N''' + @myRemotUsername + ''', @rmtpassword = N''' + @myRemotPassword + ''';' + @myNewLine
			END

			IF(@ChangeOption = 1)
			BEGIN
				SET @myScript = @myScript + 'EXECUTE master.dbo.sp_serveroption @server=N''' + @myServerName +''', @optname=N''data access'', @optvalue=N''' + CASE @myDataAccessEnabled WHEN 1 THEN 'True' ELSE 'False' END + ''';' + @myNewLine
				SET @myScript = @myScript + 'EXECUTE master.dbo.sp_serveroption @server=N''' + @myServerName +''', @optname=N''rpc'', @optvalue=N''' + CASE @myRpcEnabled WHEN 1 THEN 'True' ELSE 'False' END + ''';' + @myNewLine
				SET @myScript = @myScript + 'EXECUTE master.dbo.sp_serveroption @server=N''' + @myServerName +''', @optname=N''rpc out'', @optvalue=N''' + CASE @myRpcEnabled WHEN 1 THEN 'True' ELSE 'False' END + ''';' + @myNewLine
			END

			IF (@myDataAccessEnabled = 1)
			BEGIN
				SET @myScript = @myScript + 'EXECUTE master.dbo.sp_testlinkedserver @server=N''' + @myServerName + '''' + @myNewLine
			END
			SET @myScript = @myScript +'--======================================================================================='
			IF(@PrintOnly = 0)
				EXECUTE master.sys.sp_executesql @myScript	   
			ELSE
				PRINT @myScript

			FETCH NEXT FROM @myCursor INTO @myServerName, @myIsSubscriber, @myDataSource, @myRemotUsername,@myRemotPassword,@myRemotDatabase,@myDataAccessEnabled, @myRpcEnabled
		END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_linkedserversII', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-03-14', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_linkedserversII', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_linkedserversII', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_linkedserversII', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_linkedserversII', NULL, NULL
GO
