SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <7/12/2014>
-- Version:		<3.0.0.0>
-- Description:	<Replace variables by values>
-- =============================================
CREATE FUNCTION [maintenance].[variable_replacement] (@VariableString as nvarchar(4000),@DATE datetime,@SERVER_NAME nvarchar(255)=NULL, @INSTANCE_NAME nvarchar(255)=NULL,@DBNAME nvarchar(50)=NULL,@BACKUP_TYPE nvarchar(50)=NULL,@RETANTION_DAYS int=0,@FILE_PATH nvarchar(255)=NULL)
RETURNS nvarchar(4000)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @myAnswer as nvarchar(4000)
	DECLARE @myVariablesIterator as Cursor;
	DECLARE @myVariableName as nvarchar(50)
	DECLARE @myVariableSource as nvarchar(20)
	DECLARE @myVariableValue as nvarchar(255)
	
	SET @myAnswer=@VariableString
	SET @myVariablesIterator = Cursor For Select Variable_Name,Variable_Source From maintenance.Variables
	Open @myVariablesIterator
	FETCH NEXT FROM @myVariablesIterator INTO @myVariableName,@myVariableSource
			WHILE @@FETCH_STATUS=0
			BEGIN
				IF CHARINDEX(@myVariableName,@myAnswer)>0
				BEGIN
					SET @myVariableValue = CASE
						WHEN UPPER(@myVariableSource)=UPPER('TIMEFLAGS') THEN [maintenance].[gettimeflag](@DATE,@myVariableName)
						WHEN UPPER(@myVariableSource)=UPPER('BAKCUPRECORD') AND UPPER(@myVariableName)=UPPER('{%BACKUP_TYPE%}') THEN CAST(@BACKUP_TYPE as nvarchar(255))
						WHEN UPPER(@myVariableSource)=UPPER('BAKCUPRECORD') AND UPPER(@myVariableName)=UPPER('{%DBNAME%}') THEN CAST(@DBNAME as nvarchar(255))
						WHEN UPPER(@myVariableSource)=UPPER('BAKCUPRECORD') AND UPPER(@myVariableName)=UPPER('{%SERVER_NAME%}') THEN CAST(@SERVER_NAME as nvarchar(255))
						WHEN UPPER(@myVariableSource)=UPPER('BAKCUPRECORD') AND UPPER(@myVariableName)=UPPER('{%INSTANCE_NAME%}') THEN CAST(@INSTANCE_NAME as nvarchar(255))
						WHEN UPPER(@myVariableSource)=UPPER('BAKCUPRECORD') AND UPPER(@myVariableName)=UPPER('{%RETANTION_DAYS%}') THEN CAST(@RETANTION_DAYS as nvarchar(255))
						ELSE ''
						END
						
					IF (UPPER(@myVariableSource)=UPPER('BAKCUPRECORD') AND UPPER(@myVariableName)=UPPER('{%FILE_EXTENSION%}'))
						BEGIN
						SELECT @myVariableValue=
							CASE WHEN ISNULL(CHARINDEX('.',REVERSE(@FILE_PATH),0),0) > 0 THEN
								REVERSE(LEFT(REVERSE(@FILE_PATH),CHARINDEX('.',REVERSE(@FILE_PATH),0)-1))
							ELSE
								NULL
							END
						END
						
					IF (UPPER(@myVariableSource)=UPPER('BAKCUPRECORD') AND UPPER(@myVariableName)=UPPER('{%FILE_NAME%}'))
						BEGIN
						SELECT @myVariableValue=
							CASE WHEN MAX(myStartPoint.Position) > 0 THEN
								REVERSE(LEFT(REVERSE(@FILE_PATH),MAX(myStartPoint.Position)-1))
							ELSE
								@FILE_PATH
							END
						FROM
							(
							select ISNULL(CHARINDEX('\',REVERSE(@FILE_PATH),0),0) as Position
							UNION
							select ISNULL(CHARINDEX('/',REVERSE(@FILE_PATH),0),0) as Position
							) as myStartPoint
						END

					SET @myAnswer=REPLACE(@myAnswer,@myVariableName,@myVariableValue)
				END
				FETCH NEXT FROM @myVariablesIterator INTO @myVariableName,@myVariableSource
			END
	CLOSE @myVariablesIterator;
	DEALLOCATE @myVariablesIterator;
	-- Return the result of the function
	RETURN @myAnswer

END

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'FUNCTION', N'variable_replacement', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-12', 'SCHEMA', N'maintenance', 'FUNCTION', N'variable_replacement', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'FUNCTION', N'variable_replacement', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'FUNCTION', N'variable_replacement', NULL, NULL
GO
