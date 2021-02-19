SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Version:		<3.0.0.0>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[dbafn_hexadecimal]
(
    @binvalue varbinary(256)
)
RETURNS varchar (514)
AS
BEGIN

DECLARE @charvalue varchar (514)
DECLARE @i int
DECLARE @length int
DECLARE @hexstring char(16)

SELECT @charvalue = '0x'
SELECT @i = 1
SELECT @length = DATALENGTH (@binvalue)
SELECT @hexstring = '0123456789ABCDEF'
WHILE (@i <= @length)
BEGIN
  DECLARE @tempint int
  DECLARE @firstint int
  DECLARE @secondint int
  SELECT @tempint = CONVERT(int, SUBSTRING(@binvalue,@i,1))
  SELECT @firstint = FLOOR(@tempint/16)
  SELECT @secondint = @tempint - (@firstint*16)
  SELECT @charvalue = @charvalue +
    SUBSTRING(@hexstring, @firstint+1, 1) +
    SUBSTRING(@hexstring, @secondint+1, 1)
  SELECT @i = @i + 1
END

RETURN @charvalue
END


GO
EXEC sp_addextendedproperty N'Author', N'Microsoft', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_hexadecimal', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2013-12-18', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_hexadecimal', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_hexadecimal', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_hexadecimal', NULL, NULL
GO
