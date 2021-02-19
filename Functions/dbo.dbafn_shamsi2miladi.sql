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
CREATE FUNCTION [dbo].[dbafn_shamsi2miladi](@FaDate nvarchar(10),@Delimiter nvarchar(1)='/')
RETURNS DATE
AS 
BEGIN
   DECLARE 
		@YYear int
		,@MMonth int
		,@DDay int
		,@epbase int
		,@epyear int
		,@mdays int
		,@persian_jdn int
		,@i int
		,@j int
		,@l int
		,@n int
		,@TMPRESULT nvarchar(10)
		,@IsValideDate int
		,@TempStr nvarchar(20)
		,@TmpDateStr nvarchar(10)

	SET @i=charindex(@Delimiter,@FaDate)
	IF LEN(@FaDate) - CHARINDEX(@Delimiter, @FaDate,CHARINDEX(@Delimiter, @FaDate,1)+1) = 4
	BEGIN
		IF ( ISDATE(@TmpDateStr) =1 ) 
		RETURN @TmpDateStr
			ELSE            
		RETURN NULL
	END
	ELSE
		SET @TmpDateStr = @FaDate

	IF ((@i<>0) and (ISNUMERIC(REPLACE(@TmpDateStr,@Delimiter,''))=1) and (charindex('.',@TmpDateStr)=0))
	BEGIN
		SET @YYear=CAST(SUBSTRING(@TmpDateStr,1,@i-1) AS INT)
		IF ( @YYear< 1300 )
			SET @YYear =@YYear + 1300
		IF @YYear > 9999
			RETURN NULL
		SET @TempStr= SUBSTRING(@TmpDateStr,@i+1,Len(@TmpDateStr))
		SET @i=charindex(@Delimiter,@TempStr)
		SET @MMonth=CAST(SUBSTRING(@TempStr,1,@i-1) AS INT)
        SET @MMonth=@MMonth-- -1
        SET @TempStr= SUBSTRING(@TempStr,@i+1,Len(@TempStr))  
        SET @DDay=CAST(@TempStr AS INT)
		SET @DDay=@DDay-- - 1
        IF ( @YYear >= 0 )
			SET @epbase = @YYear - 474
		Else
			SET @epbase = @YYear - 473
		SET @epyear = 474 + (@epbase % 2820)
        IF (@MMonth <= 7 )
			SET @mdays = ((@MMonth) - 1) * 31
        Else
			SET @mdays = ((@MMonth) - 1) * 30 + 6
		
		SET @persian_jdn =(@DDay)  + @mdays + CAST((((@epyear * 682) - 110) / 2816) as int)  + (@epyear - 1) * 365  +  CAST((@epbase / 2820)  as int ) * 1029983  + (1948321 - 1)
        IF (@persian_jdn > 2299160)
		BEGIN
			SET @l = @persian_jdn + 68569
            SET @n = CAST(((4 * @l) / 146097) as int)
            SET @l = @l -  CAST(((146097 * @n + 3) / 4) as int)
            SET @i =  CAST(((4000 * (@l + 1)) / 1461001) as int)
            SET @l = @l - CAST( ((1461 * @i) / 4) as int) + 31
            SET @j =  CAST(((80 * @l) / 2447) as int)
            SET @DDay = @l - CAST( ((2447 * @j) / 80) as int)
            SET @l =  CAST((@j / 11) as int)
            SET @MMonth = @j + 2 - 12 * @l
            SET @YYear = 100 * (@n - 49) + @i + @l
		END
		SET @TMPRESULT=Cast(@MMonth as nvarchar(2))+'/'+CAST(@DDay as nVarchar(2))+'/'+CAST(@YYear as nvarchar(4)) 
		RETURN Cast(@TMPRESULT as nvarchar(10))
	END
	RETURN NULL     
END

GO
EXEC sp_addextendedproperty N'Author', N'Yousef Rahimy Akhondzadeh', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_shamsi2miladi', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2011-08-28', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_shamsi2miladi', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_shamsi2miladi', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'FUNCTION', N'dbafn_shamsi2miladi', NULL, NULL
GO
