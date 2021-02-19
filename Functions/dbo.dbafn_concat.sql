SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		<Golchoobian>
-- Create date: <12/18/2013>
-- Version:		<3.0.0.0>
-- Description:	<Concatenate List of values to a single string delimitered by @delimiter character>
-- Input Parameters:
--	@Table:		//Table with type of dbo.ConcatTableType that used for concatenating rows
--	@delimiter:	'x'	//Any single character that used to seperate values in concatenated string
-- =============================================
CREATE FUNCTION [dbo].[dbafn_concat](
	@Table dbo.ConcatTableType_v03 READONLY,
	@delimiter nchar(1)=N','
	)
RETURNS nvarchar(MAX)
AS
BEGIN
	DECLARE @Result nvarchar(MAX);

	With myCSV (Concatenated) as (
	SELECT
		ISNULL(myList.[value],N'') + CAST(@delimiter as nvarchar(1)) AS [text()]
	FROM 
		@Table as myList
	for xml path('')
	)
	
	--Slolution #2:
	--SET @Result=''
	--SELECT @Result=@Result + ISNULL(myList.[value],'') + CAST(@delimiter as nvarchar(1)) FROM @Table as myList
	--SELECT @Result = LEFT(Concatenated,Len(Concatenated)- LEN(@delimiter)) FROM myCSV
	
	SELECT @Result = LEFT(Concatenated,Len(Concatenated)- LEN(@delimiter)) FROM myCSV
	Return @Result
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_concat', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2013-12-18', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_concat', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_concat', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_concat', NULL, NULL
GO
