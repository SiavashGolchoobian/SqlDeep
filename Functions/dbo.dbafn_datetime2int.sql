SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[dbafn_datetime2int](@datetime DATETIME, @length int) 
RETURNS 
BIGINT WITH SCHEMABINDING AS
BEGIN 
       RETURN CONVERT(BIGINT,
                      SUBSTRING(
                        REPLACE(REPLACE(
                        REPLACE(REPLACE(
                                CONVERT(CHAR(25), GETDATE(), 121)
                        ,'-','')
                        ,':','')
                        ,' ','')
                        ,'.','')
                    ,0
                    ,@length+1)
                    )
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_datetime2int', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2021-08-02', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_datetime2int', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-08-02', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_datetime2int', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_datetime2int', NULL, NULL
GO
