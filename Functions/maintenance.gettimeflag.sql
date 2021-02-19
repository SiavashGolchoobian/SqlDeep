SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobin>
-- Create date: <7/7/2014>
-- Version:		<3.0.0.0>
-- Description:	<Retrive specified timeflag>
-- =============================================
CREATE FUNCTION [maintenance].[gettimeflag] (@date DATETIME,@flagname NVARCHAR(50))
RETURNS NVARCHAR(255)
AS
BEGIN
	DECLARE @Answer AS NVARCHAR(255)
	SELECT @Answer=flag_value FROM [maintenance].[timeflags](@date) WHERE flag_name=@flagname
	RETURN @Answer
END


GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'FUNCTION', N'gettimeflag', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-07', 'SCHEMA', N'maintenance', 'FUNCTION', N'gettimeflag', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'FUNCTION', N'gettimeflag', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'FUNCTION', N'gettimeflag', NULL, NULL
GO
