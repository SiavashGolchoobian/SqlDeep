SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <6/12/2018>
-- Version:		<3.0.0.0>
-- Description:	<Manage Linked Server connection and change LinkedServer target according to priority if higher periority target is alive>
-- Input Parameters:
--	@Name:		'xxx' //Name of linkedserver according to Name field in [maintenance].[LinkedServers] tables and actual LinkedServer name
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_linkedservers] (@Name sysname) AS
BEGIN
	DECLARE @myPrintString NVARCHAR(MAX);
	DECLARE @myCursor Cursor;
	DECLARE @myAllowContinue BIT
	DECLARE @myRecordId INT;
	DECLARE @myServer sysname;
	DECLARE @myProduct NVARCHAR(128);
	DECLARE @myProvider NVARCHAR(128);
	DECLARE @myDataSource NVARCHAR(4000);
	DECLARE @myCatalog sysname;
	DECLARE @myPriority INT;
	DECLARE @myUserName NVARCHAR(255);
	DECLARE @myUserPassword NVARCHAR(255);
	DECLARE @myLinkIsExists BIT;
	DECLARE @myExistedLinkPriority INT;
	DECLARE @myExistedLinkIsAlive BIT;
	DECLARE @myProceedLinkIsAlive BIT;
	DECLARE @myExistedLinkSameAsProceedLink BIT;
	DECLARE @myAllowCreateNewLink BIT;
	DECLARE @myIsNewLinkCreated BIT;
	DECLARE @myServerTemp sysname;

	SET @myPrintString = CAST(N'' AS NVARCHAR(MAX))
	SET @myAllowContinue=1
	SET @myCursor=CURSOR For
	SELECT
		[myLS].[RecordId],
		[myLS].[Name],
		[myLS].[Product],
		[myLS].[Provider],
		[myLS].[DataSource],
		[myLS].[Catalog],
		[myLS].[Priority],
		[myLS].[UserName],
		[myLS].[Password]
	FROM
		[maintenance].[LinkedServers] AS myLS
	WHERE
		[myLS].[Name]=@Name
		AND [myLS].[Enabled]=1
	ORDER BY
		[myLS].[Priority]

	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @myRecordId,@myServer,@myProduct,@myProvider,@myDataSource,@myCatalog,@myPriority,@myUserName,@myUserPassword
	WHILE @@FETCH_STATUS=0 AND @myAllowContinue=1
		BEGIN
			SET @myLinkIsExists=0;
			SET @myExistedLinkPriority=9999;
			SET @myExistedLinkIsAlive=0;
			SET @myProceedLinkIsAlive=0;
			SET @myExistedLinkSameAsProceedLink=0;
			SET @myAllowCreateNewLink=0;
			SET @myIsNewLinkCreated=0;
				
			--Check if linked server exists
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Check Link existance'
			EXEC [dbo].[dbasp_print_text] @myPrintString
			IF EXISTS(SELECT 1 FROM [master].[sys].[servers] WHERE [name]=@myServer)
			BEGIN
				SET @myLinkIsExists=1
			END
			ELSE
			BEGIN
				SET @myLinkIsExists=0
			END
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N':			' + CAST(@myLinkIsExists AS NVARCHAR(MAX))
			EXEC [dbo].[dbasp_print_text] @myPrintString

			--Check if existed linked server is same as current proceed link
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Check Same Link processing'
			EXEC [dbo].[dbasp_print_text] @myPrintString
			IF EXISTS(SELECT 1 FROM [master].[sys].[servers] WHERE [name]=@myServer AND [product]=@myProduct AND [provider]=@myProvider AND [data_source]=@myDataSource AND ISNULL([catalog],'')=ISNULL(@myCatalog,''))
			BEGIN
				SET @myExistedLinkSameAsProceedLink=1
				SET @myExistedLinkPriority=@myPriority
			END
			ELSE
			BEGIN
				SET @myExistedLinkSameAsProceedLink=0
				SET @myExistedLinkPriority=ISNULL((SELECT [myLS].[Priority] FROM [maintenance].[LinkedServers] AS myLS INNER JOIN [master].[sys].[servers] AS mySrv ON [mySrv].[name] COLLATE DATABASE_DEFAULT = [myLS].[Name] COLLATE DATABASE_DEFAULT AND [mySrv].[product] COLLATE DATABASE_DEFAULT = [myLS].[Product] COLLATE DATABASE_DEFAULT AND [mySrv].[provider] COLLATE DATABASE_DEFAULT = [myLS].[Provider] COLLATE DATABASE_DEFAULT AND [mySrv].[data_source] COLLATE DATABASE_DEFAULT =[myLS].[DataSource] COLLATE DATABASE_DEFAULT AND ISNULL([mySrv].[catalog],'') COLLATE DATABASE_DEFAULT = ISNULL([myLS].[Catalog],'') COLLATE DATABASE_DEFAULT WHERE [myLS].[Enabled]=1),9999)
			END
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N':			' + CAST(@myExistedLinkSameAsProceedLink AS NVARCHAR(MAX))
			EXEC [dbo].[dbasp_print_text] @myPrintString

			--Check if existed linked server is alive
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Check Existed Link is alive'
			EXEC [dbo].[dbasp_print_text] @myPrintString
			IF @myLinkIsExists=1
			BEGIN
				BEGIN TRY
					EXEC sp_testlinkedserver @servername=@myServer
					SET @myExistedLinkIsAlive=1
				END TRY
				BEGIN CATCH
					SET @myExistedLinkIsAlive=0
				END CATCH
			END
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N':			' + CAST(@myExistedLinkIsAlive AS NVARCHAR(MAX))
			EXEC [dbo].[dbasp_print_text] @myPrintString

			--Check if procced linked server is alive
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Check Procced Link is alive'
			EXEC [dbo].[dbasp_print_text] @myPrintString
			IF @myExistedLinkSameAsProceedLink=0
			BEGIN
				BEGIN TRY
					SET @myServerTemp=@myServer+CAST(NEWID() AS sysname)
					EXEC [master].[dbo].sp_addlinkedserver @server=@myServerTemp,@srvproduct=@myProduct,@provider=@myProvider,@datasrc=@myDataSource,@catalog=@myCatalog;
					IF @myUserName IS NULL
					BEGIN
						EXEC [master].[dbo].sp_addlinkedsrvlogin @rmtsrvname = @myServerTemp, @locallogin = NULL , @useself = N'True'
					END
					ELSE
					BEGIN
						EXEC [master].[dbo].sp_addlinkedsrvlogin @rmtsrvname = @myServerTemp, @locallogin = NULL , @useself = N'False', @rmtuser = @myUserName, @rmtpassword = @myUserPassword
					END

					EXEC sp_testlinkedserver @servername=@myServerTemp
					EXEC [master].[dbo].[sp_dropserver] @server=@myServerTemp, @droplogins='droplogins'
					SET @myProceedLinkIsAlive=1
				END TRY
				BEGIN CATCH
					EXEC [master].[dbo].[sp_dropserver] @server=@myServerTemp, @droplogins='droplogins'
					SET @myProceedLinkIsAlive=0
				END CATCH
			END
			ELSE
            BEGIN
				SET @myProceedLinkIsAlive=@myExistedLinkIsAlive
			END
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N':			' + CAST(@myProceedLinkIsAlive AS NVARCHAR(MAX))
			EXEC [dbo].[dbasp_print_text] @myPrintString

			--Drop existed dead Linked server
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Check for dropping existed dead Link'
			EXEC [dbo].[dbasp_print_text] @myPrintString
			IF @myLinkIsExists=1 AND @myProceedLinkIsAlive=1 AND @myExistedLinkSameAsProceedLink=0
			BEGIN
				EXEC [master].[dbo].[sp_dropserver] @server=@myServer, @droplogins='droplogins'
				SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N':			Dropeed'
				EXEC [dbo].[dbasp_print_text] @myPrintString
			END

			--Determine allowing creation of new linked server
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Check for allowing Link creation'
			EXEC [dbo].[dbasp_print_text] @myPrintString
			IF @myProceedLinkIsAlive=1 AND (@myLinkIsExists=0 OR (@myLinkIsExists=1 AND @myExistedLinkSameAsProceedLink=0))
				SET @myAllowCreateNewLink=1
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N':			' + CAST(@myAllowCreateNewLink AS NVARCHAR(MAX))
			EXEC [dbo].[dbasp_print_text] @myPrintString

			--Create new linked server if allowable
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Create link'
			EXEC [dbo].[dbasp_print_text] @myPrintString
			IF @myAllowCreateNewLink=1
			BEGIN
				BEGIN TRY
					SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Exec add link'
					EXEC [dbo].[dbasp_print_text] @myPrintString
					EXEC [master].[dbo].sp_addlinkedserver @server=@myServer,@srvproduct=@myProduct,@provider=@myProvider,@datasrc=@myDataSource,@catalog=@myCatalog;
					SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Exec add login'
					EXEC [dbo].[dbasp_print_text] @myPrintString
					IF @myUserName IS NULL
					BEGIN
						EXEC [master].[dbo].sp_addlinkedsrvlogin @rmtsrvname = @myServer, @locallogin = NULL , @useself = N'True'
					END
					ELSE
					BEGIN
						EXEC [master].[dbo].sp_addlinkedsrvlogin @rmtsrvname = @myServer, @locallogin = NULL , @useself = N'False', @rmtuser = @myUserName, @rmtpassword = @myUserPassword
					END
					SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Exec test link'
					EXEC [dbo].[dbasp_print_text] @myPrintString
					EXEC sp_testlinkedserver @servername=@myServer
					SET @myIsNewLinkCreated=1
				END TRY
				BEGIN CATCH
					SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N': Exception in Create link'
					EXEC [dbo].[dbasp_print_text] @myPrintString
					SET @myIsNewLinkCreated=0
					DECLARE @CustomMessage1 NVARCHAR(255)
					SET @CustomMessage1='Link Creation Error for ' + @Name + N' on RecordId' + CAST(@myRecordId AS NVARCHAR(255))
					EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
				END CATCH
			END
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N':			' + CAST(@myIsNewLinkCreated AS NVARCHAR(MAX))
			EXEC [dbo].[dbasp_print_text] @myPrintString

			--Allow Continue ?
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N':	Allow Continue ?'
			EXEC [dbo].[dbasp_print_text] @myPrintString
			IF 
				(@myExistedLinkIsAlive=0 AND @myIsNewLinkCreated=0) OR
				(@myExistedLinkIsAlive=1 AND @myIsNewLinkCreated=0 AND @myPriority<@myExistedLinkPriority)
			BEGIN
				SET @myAllowContinue=1
			END
			ELSE
			BEGIN
				SET @myAllowContinue=0
			END
			SET @myPrintString=CAST(@myRecordId AS NVARCHAR(MAX)) + N':			' + CAST(@myAllowContinue AS NVARCHAR(MAX))
			EXEC [dbo].[dbasp_print_text] @myPrintString

		FETCH NEXT FROM @myCursor INTO @myRecordId,@myServer,@myProduct,@myProvider,@myDataSource,@myCatalog,@myPriority,@myUserName,@myUserPassword
		END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_linkedservers', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2018-06-12', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_linkedservers', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-06-12', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_linkedservers', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_linkedservers', NULL, NULL
GO
