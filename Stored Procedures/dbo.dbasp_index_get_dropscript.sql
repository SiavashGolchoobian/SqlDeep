SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/29/2015>
-- Version:		<3.0.0.0>
-- Description:	<Return list of index deletion commands of database>
-- Input Parameters:
--	@DatabaseNames:	'<ALL_USER_DATABASES>' or '<ALL_SYSTEM_DATABASES>' or '<ALL_DATABASES>' or 'dbname1,dbname2,...,dbnameN'
-- =============================================
CREATE Procedure [dbo].[dbasp_index_get_dropscript] (
	@DatabaseNames NVARCHAR(MAX) = N'<ALL_USER_DATABASES>'
	)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @myCursor Cursor;
	DECLARE @Database_Name nvarchar(255);
	DECLARE @myNewLine nvarchar(10);
	DECLARE @mySQLScript NVARCHAR(max);
	DECLARE @CommandList TABLE ([Database_Name] nvarchar(255) ,[DropIndexScript] nvarchar (max))

	SET @myNewLine=CHAR(13)+CHAR(10)
    SET @myCursor=CURSOR For
		Select [Name] FROM [dbo].[dbafn_database_list](@DatabaseNames,1,1,1,0,0)

	Open @myCursor
	FETCH NEXT FROM @myCursor INTO @Database_Name
	WHILE @@FETCH_STATUS=0
		BEGIN
			SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
			SET @mySQLScript = @mySQLScript+
				CAST(
				@myNewLine + N'USE '+ CAST(QUOTENAME(@Database_Name) AS NVARCHAR(MAX)) + N';'+
				@myNewLine +
					N'SELECT 
						DB_NAME(),
						'' DROP INDEX '' +
						QUOTENAME(Schema_name(T.Schema_id))+''.''+QUOTENAME(T.name)+''.''+QUOTENAME(I.name)
					FROM 
						sys.indexes as I  
						INNER JOIN sys.tables as T ON T.Object_id = I.Object_id   
						INNER JOIN sys.sysindexes as SI ON I.Object_id = SI.id AND I.index_id = SI.indid  
					WHERE 
						I.type>0 
						AND T.is_ms_shipped=0 
						AND T.name<>''sysdiagrams''
						AND I.is_primary_key = 0 
						AND I.is_unique_constraint = 0'
				AS NVARCHAR(MAX))
			
			EXEC [dbo].[dbasp_print_text] @mySQLScript
			INSERT INTO @CommandList ([Database_Name],[DropIndexScript]) EXECUTE sp_executesql @mySQLScript
			FETCH NEXT FROM @myCursor INTO @Database_Name
		END
	CLOSE @myCursor;
	DEALLOCATE @myCursor;

	SELECT [Database_Name],[DropIndexScript] FROM @CommandList
END



GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_index_get_dropscript', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-29', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_index_get_dropscript', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_index_get_dropscript', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_index_get_dropscript', NULL, NULL
GO
