SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Siavash Golchoobian>
-- Create date: <2023/10/30>
-- Version:		<3.0.0.1>                
-- Description:	<Extract powershell using module dependencies> 
-- Input Parameters:
--	@FilePath:				//Powershell file path
--	@Metadata:				//Generated metadata XML as output
-- =============================================

CREATE PROCEDURE [repository].[dbasp_analyze_file_dependencies] (@Content VARBINARY(MAX), @Metadata XML OUTPUT) AS
BEGIN
	DECLARE @myNewLine NVARCHAR(10)
	DECLARE @myMetadataContent XML

	SET @Metadata=CAST(N'<metadata></metadata>' AS XML)
	SET @myNewLine=CHAR(10)
	SET @myMetadataContent = (
		SELECT 
			REPLACE(REPLACE(RIGHT(myTextLines.Parameter,CHARINDEX('\',REVERSE(myTextLines.Parameter),0)-1),CHAR(10),''),CHAR(13),'') AS 'name',
			'' as 'version'
		FROM
			[dbo].[dbafn_split](@myNewLine,CAST(@Content AS VARCHAR(MAX)) ) AS myTextLines
		WHERE
			myTextLines.Parameter LIKE N'%using module%'
		FOR XML RAW ('Item'), ROOT ('DependentItems'),TYPE
		)

	SET @Metadata.modify('insert sql:variable("@myMetadataContent") into (/metadata)[1]')
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_analyze_file_dependencies', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2023-10-30', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_analyze_file_dependencies', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2023-10-30', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_analyze_file_dependencies', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.1', 'SCHEMA', N'repository', 'PROCEDURE', N'dbasp_analyze_file_dependencies', NULL, NULL
GO
