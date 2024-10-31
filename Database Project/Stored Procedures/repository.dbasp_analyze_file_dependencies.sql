SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Siavash Golchoobian>
-- Create date: <2023/10/30>
-- Version:		<3.0.0.0>                
-- Description:	<Extract powershell using module dependencies> 
-- Input Parameters:
--	@FilePath:				//Powershell file path
--	@Metadata:				//Generated metadata XML as output
-- =============================================

CREATE PROCEDURE [repository].[dbasp_analyze_file_dependencies] (@FilePath NVARCHAR(255), @Metadata XML OUTPUT) AS
BEGIN
	DECLARE @myOsPathSeperator CHAR(1);
	DECLARE @myStatement NVARCHAR(MAX)
	DECLARE @myStatementParams NVARCHAR(255)

	SET @myOsPathSeperator = CASE WHEN CHARINDEX('Linux',@@VERSION,1)<>0 THEN N'/' ELSE N'\' END
	SET @myStatementParams=N'@myMetadataRoot XML OUTPUT'
	SET @myStatement = N'
	DECLARE @myNewLine NVARCHAR(10)
	DECLARE @myTextContent VARBINARY(MAX)
	DECLARE @myMetadataContent XML

	SET @myMetadataRoot=CAST(N''<metadata></metadata>'' AS XML)
	SET @myNewLine=CHAR(10)
	SET @myTextContent=(SELECT [FileContent].* FROM OPENROWSET (BULK '''+@FilePath+''', SINGLE_BLOB) AS [FileContent])
	SET @myMetadataContent = (
		SELECT 
			RIGHT(myTextLines.Parameter,CHARINDEX(''\'',REVERSE(myTextLines.Parameter),0)-1) AS ''name'',
			'''' as ''version''
		FROM
			[dbo].[dbafn_split](@myNewLine,CAST(@myTextContent AS VARCHAR(MAX)) ) AS myTextLines
		WHERE
			myTextLines.Parameter LIKE N''%using module%''
		FOR XML RAW (''Item''), ROOT (''DependentItems''),TYPE
		)

	SET @myMetadataRoot.modify(''insert sql:variable("@myMetadataContent") into (/metadata)[1]'')
	'
	
	EXECUTE sp_executesql @myStatement,@myStatementParams,@myMetadataRoot=@Metadata OUTPUT
END

GO
