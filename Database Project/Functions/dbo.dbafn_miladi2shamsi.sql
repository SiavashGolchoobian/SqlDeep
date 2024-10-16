SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Yousef Rahimy Akhondzadeh>
-- Create date: <2011/08/28>
-- Version:		<3.0.0.0>                
-- Description:	<Convert Gregorian Date to Jalali Date> 
-- =============================================
CREATE FUNCTION [dbo].[dbafn_miladi2shamsi](@EnDate DATETIME, @Delimiter nvarchar(1)='/') RETURNS nVARCHAR(10)
BEGIN
		DECLARE @EnYear SMALLINT 
		DECLARE @EnMonth SMALLINT 
		DECLARE @EnDay SMALLINT 
		DECLARE @I SMALLINT 
		DECLARE @Days_Of_Year SMALLINT 
		DECLARE @Temp NVARCHAR(10)
		DECLARE @M SMALLINT 
		DECLARE @En_Month_Days TABLE(ID SMALLINT IDENTITY(1,1),DayCount SMALLINT )
		INSERT INTO @En_Month_Days(DayCount)VALUES(31)
		INSERT INTO @En_Month_Days(DayCount)VALUES(28)
		INSERT INTO @En_Month_Days(DayCount)VALUES(31)
		INSERT INTO @En_Month_Days(DayCount)VALUES(30)
		INSERT INTO @En_Month_Days(DayCount)VALUES(31)
		INSERT INTO @En_Month_Days(DayCount)VALUES(30)
		INSERT INTO @En_Month_Days(DayCount)VALUES(31)
		INSERT INTO @En_Month_Days(DayCount)VALUES(31)
		INSERT INTO @En_Month_Days(DayCount)VALUES(30)
		INSERT INTO @En_Month_Days(DayCount)VALUES(31)
		INSERT INTO @En_Month_Days(DayCount)VALUES(30)
		INSERT INTO @En_Month_Days(DayCount)VALUES(31)

		SET @EnYear = DATEPART(YYYY,@EnDate)
		SET @EnMonth = DATEPART(MM,@EnDate)
		SET @EnDay = DATEPART(DD,@EnDate)
		SET @Days_Of_Year = 0
		SET @I = 1
--=============================================
--               Special Year
--=============================================
		IF ((@EnYear % 400) = 384)
			SET @M = 1
		ELSE
			SET @M = 0

		SET @EnDay = @EnDay - @M
		IF (@EnDay = 0)
		BEGIN
			SET @EnMonth = @EnMonth - 1
			IF (@EnMonth = 0)
			BEGIN
				SET @EnYear = @EnYear - 1
				SET @EnMonth = 12
				SET @EnDay = (SELECT DayCount FROM @En_Month_Days WHERE ID = @EnMonth)
			END
			ELSE
				SET @EnDay = (SELECT DayCount FROM @En_Month_Days WHERE ID = @EnMonth)
		END
--=============================================
--            Computing Day of Year
--=============================================
		WHILE @I < @EnMonth
		BEGIN 
			SET @Days_Of_Year = @Days_Of_Year + (SELECT DayCount FROM @En_Month_Days WHERE ID = @I)
			SET @I = @I + 1
		END 
		SET @Days_Of_Year = @Days_Of_Year + @EnDay
		IF (((SELECT [dbo].[dbafn_is_en_leapyear](@EnYear)) = 1) AND (@EnMonth > 2))
			SET @Days_Of_Year = @Days_Of_Year + 1
--=============================================
--         Computing Month and Day 
--=============================================
		IF (@Days_Of_Year <= 79)  
		BEGIN
			IF (((@EnYear - 1) % 4) = 0)
				SET @Days_Of_Year = @Days_Of_Year + 11
			ELSE
				SET @Days_Of_Year = @Days_Of_Year + 10
			SET @EnYear = @EnYear - 622
    
			IF ((@Days_Of_Year % 30) = 0)
			BEGIN 
				SET @EnMonth = (@Days_Of_Year / 30) + 9
				SET @EnDay = 30
			END 
			ELSE 
			BEGIN 
				SET @EnMonth = (@Days_Of_Year / 30) + 10
				SET @EnDay = @Days_Of_Year % 30
			END 
		END
		ELSE
		BEGIN 
			SET @EnYear = @EnYear - 621
			SET @Days_Of_Year = @Days_Of_Year - 79
			IF (@Days_Of_Year <= 186)
			BEGIN 
				IF ((@Days_Of_Year % 31) = 0)
				BEGIN 
					SET @EnMonth = (@Days_Of_Year / 31)
					SET @EnDay = 31
				END 
				ELSE
				BEGIN 
					SET @EnMonth = (@Days_Of_Year / 31) + 1
					SET @EnDay = (@Days_Of_Year % 31)
				END 
			END 
			ELSE
			BEGIN 
				SET @Days_Of_Year = @Days_Of_Year - 186
				IF ((@Days_Of_Year % 30) = 0)
				BEGIN 
					SET @EnMonth = (@Days_Of_Year / 30) + 6
					SET @EnDay = 30
				END 
				ELSE 
				BEGIN 
					SET @EnMonth = (@Days_Of_Year / 30) + 7
					SET @EnDay = @Days_Of_Year % 30
				END 
			END 
		END 
--=============================================
--               Format Result
--=============================================
		SET @Temp = CAST(@EnYear AS NCHAR(4)) + @Delimiter
		IF (@EnMonth < 10)
			SET @Temp = @Temp + RIGHT('0' + CAST(@EnMonth AS NCHAR(1)),2) + @Delimiter
		ELSE
			SET @Temp = @Temp + CAST(@EnMonth AS NCHAR(2)) + @Delimiter
		IF (@EnDay < 10)
			SET @Temp = @Temp + RIGHT('0' + CAST(@EnDay AS NCHAR(1)),2) + @Delimiter
		ELSE
			SET @Temp = @Temp + CAST(@EnDay AS NCHAR(2)) + @Delimiter
  
		RETURN @Temp 
END

GO
EXEC sp_addextendedproperty N'Author', N'Yousef Rahimy Akhondzadeh', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_miladi2shamsi', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2011-08-28', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_miladi2shamsi', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_miladi2shamsi', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_miladi2shamsi', NULL, NULL
GO
