SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <12/18/2013>
-- Version:		<3.0.0.0>
-- Description:	<if path was existed return true value>
-- Input Parameters:
--	@Path:	'...'
-- =============================================
CREATE FUNCTION [dbo].[dbafn_file_existed](
	@Path nvarchar(4000)
	)
RETURNS bit
AS
BEGIN
	-- Declare the return variable here
	Declare @path_exists as int
    
    EXEC master.dbo.xp_fileexist @path, @path_exists OUTPUT
	RETURN CAST(@path_exists as bit)
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_file_existed', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2013-12-18', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_file_existed', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_file_existed', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_file_existed', NULL, NULL
GO
