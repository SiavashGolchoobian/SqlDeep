SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Golchoobian>
-- Create date: <02/16/2022>
-- Version:		<3.0.0.0>
-- Description:	<Execute Dynamic OpenQuery command>
-- Input Parameters:
--	@LinkedServerName:	Valid LinkedServer name
--	@Query:				Query to execute (you can use parameters inside query, EX: Select & from sys.databases where database_id=@dbid OR name=''@dbname'')
--	@QueryParameters:	XML based sttring to pass parameters value, Ex: '<parameters><param name="@dbid">1</param><param name="@dbname">msdb</param></parameters>'
--	Example:			EXEC [dbo].[dbasp_remotequery] 'Winclient2022,49149','SELECT * FROM sys.databases where database_id=@dbid or name like N''%@dbname%''','<parameters><param name="@dbid">1</param><param name="@dbname">msdb</param></parameters>'
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_remotequery]
@LinkedServerName sysname, @Query NVARCHAR (4000), @QueryParameters XML=NULL
AS
BEGIN
    DECLARE @myErrorState AS INT;
    DECLARE @myErrorMessage AS NVARCHAR (4000);
    DECLARE @myErrorCount AS INT;
    DECLARE @myStatement AS NVARCHAR (4000);
    SET @myStatement = CAST (N'' AS NVARCHAR (4000));
    SET @myErrorCount = 0;
    SET @LinkedServerName = TRIM(REPLACE(REPLACE(@LinkedServerName, '[', ''), ']', ''));
    SET @Query = REPLACE(@Query, '''', '''''');

    IF NOT EXISTS (SELECT 1
                   FROM   [sys].[servers]
                   WHERE  [name] = @LinkedServerName)
        BEGIN
            SET @myErrorCount += 1;
            SET @myErrorMessage = '@LinkedServerName is not exists.';
            SET @myErrorState = ERROR_STATE();
            RAISERROR (@myErrorMessage, 11, @myErrorState);
        END
    ELSE
        BEGIN
            SET @LinkedServerName = (SELECT QUOTENAME([name])
                                     FROM   [sys].[servers]
                                     WHERE  [name] = @LinkedServerName);
        END

    IF @Query IS NULL OR LEN(TRIM(@Query))=0
        BEGIN
            SET @myErrorCount += 1;
            SET @myErrorMessage = '@Query is empty.';
            SET @myErrorState = ERROR_STATE();
            RAISERROR (@myErrorMessage, 11, @myErrorState);
        END

    IF @myErrorCount > 0
        RETURN;
    IF @QueryParameters IS NOT NULL
        BEGIN
            DECLARE @myParamName AS NVARCHAR (255);
            DECLARE @myParamValue AS NVARCHAR (255);
            DECLARE myParamsCursor CURSOR
                FOR SELECT [myTable].[Col].value('(@name)[1]', 'nvarchar(255)') AS ParamName,
                           [myTable].[Col].value('(.)[1]', 'nvarchar(255)') AS ParamValue
                    FROM   @QueryParameters.nodes('/parameters/param') AS myTable(Col);
            OPEN [myParamsCursor];
            FETCH NEXT FROM [myParamsCursor] INTO @myParamName, @myParamValue;
            WHILE @@Fetch_Status = 0
                BEGIN
                    SET @Query = REPLACE(@Query, @myParamName, REPLACE(@myParamValue, '''', ''''''));
                    FETCH NEXT FROM [myParamsCursor] INTO @myParamName, @myParamValue;
                END
            CLOSE [myParamsCursor];
            DEALLOCATE [myParamsCursor];
        END
    SET @myStatement = @myStatement + 'SELECT * FROM OPENQUERY(' + @LinkedServerName + ',''' + @Query + ''')';
    PRINT @myStatement;
    EXECUTE sp_executesql @myStatement;
END

GO
