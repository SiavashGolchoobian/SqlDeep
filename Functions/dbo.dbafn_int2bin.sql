SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <4/30/2014>
-- Version:		<3.0.0.0>
-- Description:	<Translate Int,Bigint dat type to equal Binary string>
-- =============================================
CREATE FUNCTION [dbo].[dbafn_int2bin] (@IncomingNumber bigint)
RETURNS varchar(200)
as
BEGIN
 
	DECLARE @BinNumber	VARCHAR(200)
	SET @BinNumber = ''
 
	WHILE @IncomingNumber <> 0
	BEGIN
		SET @BinNumber = SUBSTRING('0123456789', (@IncomingNumber % 2) + 1, 1) + @BinNumber
		SET @IncomingNumber = @IncomingNumber / 2
	END
 
	RETURN @BinNumber
 
END

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_int2bin', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-04-30', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_int2bin', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_int2bin', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_int2bin', NULL, NULL
GO
