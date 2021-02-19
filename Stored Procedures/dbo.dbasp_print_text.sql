SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Siavash Golchoobian>
-- Create date: <6/24/2017>
-- Version:		<3.0.0.0>
-- Description:	<Print string variables over 4000 chanracter>
-- Input Parameters:
--	@Command:	any string variable
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_print_text] (@string NVARCHAR(MAX))
AS
BEGIN
	DECLARE @mySQLScript_Print NVARCHAR(4000);
	DECLARE @myBreakPointLength BIGINT;
	DECLARE @myStartPoint BIGINT;
	DECLARE @mySelectionLength BIGINT;
	DECLARE @myNewLine nvarchar(10);

	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myBreakPointLength=4000
	SET @myStartPoint=1

	--Print Generated Command
	WHILE @myStartPoint<LEN(@string)
	BEGIN
		SET @mySelectionLength=@myBreakPointLength
		SET @mySQLScript_Print=SUBSTRING(@string,@myStartPoint,@mySelectionLength)
		IF LEN(@mySQLScript_Print)=@mySelectionLength AND RIGHT(@mySQLScript_Print,LEN(@myNewLine))!=@myNewLine
		BEGIN
			SET @mySelectionLength=CHARINDEX(REVERSE(@myNewLine),REVERSE(@mySQLScript_Print),0)
			IF @mySelectionLength>0
			BEGIN
				SET @mySelectionLength=@myBreakPointLength-(@mySelectionLength + LEN(@myNewLine) -1)
				SET @mySQLScript_Print=SUBSTRING(@string,@myStartPoint,@mySelectionLength)
				SET @mySelectionLength=@mySelectionLength+LEN(@myNewLine)
			END
			ELSE
			BEGIN
				SET @mySelectionLength=@myBreakPointLength
			END
		END
		PRINT (@mySQLScript_Print)
		--PRINT ('--Line Break')
		SET @myStartPoint=@myStartPoint+@mySelectionLength
	END
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_print_text', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-06-24', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_print_text', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_print_text', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_print_text', NULL, NULL
GO
