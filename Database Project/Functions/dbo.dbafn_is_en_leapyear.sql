SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Yousef Rahimy Akhondzadeh>
-- Create date: <2011/08/28>
-- Version:		<3.0.0.0>
-- Description:	<Identify En Leap Year>         
-- =============================================
CREATE FUNCTION [dbo].[dbafn_is_en_leapyear](@EnYear SMALLINT) RETURNS BIT
BEGIN 
  DECLARE @Result BIT 
  IF ((@EnYear % 4) = 0) AND (((@EnYear % 100) <> 0) OR ((@EnYear % 400) = 0))
    SET @Result = 1
  ELSE 
    SET @Result = 0
  RETURN @Result
END

GO
EXEC sp_addextendedproperty N'Author', N'Yousef Rahimy Akhondzadeh', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_is_en_leapyear', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2011-08-28', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_is_en_leapyear', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_is_en_leapyear', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_is_en_leapyear', NULL, NULL
GO
