SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <24/12/2017>
-- Version:		<3.0.0.0>
-- Description:	<Set Extended Property for Database>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
--	@AllowUpdateExistance:	0 or 1 //use 1 allow this code to update existed extended property
--	@PropertyName:			Name of Extended Property
--	@PropertyValue:			Value of Extended Property
--	@PrintOnly:				0 or 1
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_set_extendedproperty]
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>',
	@AllowUpdateExistance BIT=0,
	@PropertyName sysname,
	@PropertyValue NVARCHAR(MAX),
	@PrintOnly BIT=0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @Database_ID INT;
	DECLARE @Database_IsReadOnly bit;
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @myNewLine nvarchar(10);
	
	SET @myNewLine=CHAR(13)+CHAR(10)
	
    SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,1,1)
		
	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
	WHILE @@FETCH_STATUS=0
	BEGIN
		SELECT @Database_ID=database_id,@Database_IsReadOnly=CAST(is_read_only as bit) from sys.databases where name=@Database_Name
		SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
		SET @mySQLScript=@mySQLScript+
			CAST(
			@myNewLine+ N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
			@myNewLine+ N'DECLARE @myName sysname;'+
			@myNewLine+ N'DECLARE @myValue sql_variant;'+
			@myNewLine+ N'SET @myName=''' + CAST(@PropertyName AS NVARCHAR(MAX)) + N''';'+
			@myNewLine+ N'SET @myValue=''' + CAST(@PropertyValue AS NVARCHAR(MAX)) + N''';'+
			@myNewLine+ N'IF NOT EXISTS (SELECT 1 FROM sys.extended_properties AS myEP WHERE myEP.class=0 and myEP.name=''' + CAST(@PropertyName AS NVARCHAR(MAX)) + ''')'+
			@myNewLine+ N'BEGIN'+
			@myNewLine+ N'	EXEC sys.sp_addextendedproperty @name=@myName, @value=@myValue'+
			@myNewLine+	N'END'+
			@myNewLine+ N'ELSE IF ' + CAST(@AllowUpdateExistance AS NVARCHAR(MAX)) + N'=1'+
			@myNewLine+ N'BEGIN'+
			@myNewLine+ N'	EXEC sys.sp_updateextendedproperty @name=@myName, @value=@myValue'+
			@myNewLine+	N'END'
			AS NVARCHAR(MAX))

		EXEC [dbo].[dbasp_print_text] @mySQLScript

		IF @Database_IsReadOnly=0
		BEGIN
			--=======Start of executing commands
			BEGIN TRY
				EXECUTE (@mySQLScript);
			END TRY
			BEGIN CATCH
				DECLARE @CustomMessage1 NVARCHAR(255)
				SET @CustomMessage1='Set extended property error on ' + @Database_Name
				EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage1,1,0,1,0,NULL
			END CATCH
			--=======End of executing commands
		END
		ELSE
		BEGIN
			PRINT (@myNewLine + @Database_Name + ' is read-only.');
		END
		FETCH NEXT FROM @myCursor INTO @Database_Name
	END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_set_extendedproperty', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-12-24', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_set_extendedproperty', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-12-24', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_set_extendedproperty', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_set_extendedproperty', NULL, NULL
GO
