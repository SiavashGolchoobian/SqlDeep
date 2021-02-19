SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<>
-- Create date: <2020/01/11>
-- Version:		<3.0.0.0>                
-- Description:	<Extract valid portion of @String according to @MatchExpression> 
-- Input Parameters:
--	@String:				//Any string as input
--	@MatchExpression:		//Any valid expression for evaluaiing @String and export valid portion of @String according to @MatchExpression
-- =============================================

CREATE FUNCTION [dbo].[dbafn_StripCharacters]
(
    @String NVARCHAR(MAX), 
    @MatchExpression VARCHAR(255)
)
RETURNS NVARCHAR(MAX)
WITH SCHEMABINDING AS
BEGIN
	/*
	--Alphabetic only:
	SELECT [Gen].[udf_StripCharacters]('a1!s2@d3#f4$', '^a-z')

	--Numeric only:
	SELECT [Gen].[udf_StripCharacters]('a1!s2@d3#f4$', '^0-9')

	--Alphanumeric only:
	SELECT [Gen].[udf_StripCharacters]('a1!s2@d3#f4$', '^a-z0-9')

	--Non-alphanumeric:
	SELECT [Gen].[udf_StripCharacters]('a1!s2@d3#f4$', 'a-z0-9')
	*/

    SET @MatchExpression =  '%['+@MatchExpression+']%'

    WHILE PatIndex(@MatchExpression, @String) > 0
        SET @String = Stuff(@String, PatIndex(@MatchExpression, @String), 1, '')

    RETURN @String
END
GO
