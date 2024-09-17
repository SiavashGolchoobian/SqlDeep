SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <9/25/2013>
-- Version:		<3.0.0.0>
-- Description:	<convert comma seperated string values to table of string values>
-- Input Parameters:
--	@delimiter:		'x'	//Any single character used for spiliting string
--	@array_string:	'...'	//Any string
-- =============================================
CREATE FUNCTION [dbo].[dbafn_split] 
(	
	-- Add the parameters for the function here
	@delimiter nvarchar(4000) = N',', 
	@array_string nvarchar(MAX)
)
RETURNS TABLE 
AS
RETURN 
(
    WITH Pieces(Position, [start], [stop]) AS (
      SELECT CAST(1 AS BIGINT), CAST(1 AS BIGINT), CAST(CHARINDEX(@delimiter, @array_string) AS BIGINT)
      UNION ALL
      SELECT CAST(Position + 1 AS BIGINT), CAST([stop] + 1 AS BIGINT), CAST(CHARINDEX(@delimiter, @array_string, [stop] + 1) AS BIGINT)
      FROM Pieces
      WHERE [stop] > 0
    )
    SELECT Position,
      SUBSTRING(@array_string, [start], CASE WHEN [stop] > 0 THEN [stop]-[start] ELSE LEN(@array_string) END) AS Parameter
    FROM Pieces
)


GO
GRANT SELECT ON  [dbo].[dbafn_split] TO [role_sqldeep_repo]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_split', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2013-09-25', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_split', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_split', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_split', NULL, NULL
GO
