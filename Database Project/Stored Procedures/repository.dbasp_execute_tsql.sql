SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <10/20/2024>
-- Version:		<3.0.0.0>
-- Description:	<Execute script that stored on Subscriber repository
-- Input Parameters:
--	@ItemName:	nvarchar(255)
--	@PrintOnly:	bit
-- =============================================
CREATE PROCEDURE [repository].[dbasp_execute_tsql] (@ItemName NVARCHAR(255), @PrintOnly BIT=0) AS
BEGIN
	DECLARE @myScriptText NVARCHAR(MAX)
	DECLARE @myErrorMessage NVARCHAR(4000)
	DECLARE @myNewLine nvarchar(10);
	DECLARE @myErrorState INT

	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @myErrorState=1

	SELECT TOP 1 
		@myScriptText=[myTargetItem].[ItemContent] 
	FROM 
		[repository].[Subscriber] AS myTargetItem WITH (READPAST)
		INNER JOIN (
			SELECT 
				[myItems].[ItemName],
				[myItems].[SubscriberItemId] 
			FROM 
				[repository].[dbafn_get_subscriber_item_and_dependencies] (@ItemName,Null,Null) AS myItems 
			WHERE 
				[myItems].[IsEnabled]=1 
				AND [myItems].[ItemChecksum]=[myItems].[SubscriberItemChecksum]
				AND [myItems].[ItemType]=N'TSQL'
		) AS myCandidateItems ON [myCandidateItems].[SubscriberItemId] = [myTargetItem].[SubscriberItemId]

	EXECUTE [dbo].[dbasp_print_text] @myScriptText
	IF @PrintOnly=0
	BEGIN
		BEGIN TRY
			EXECUTE sp_executesql @myScriptText
		END TRY	
		BEGIN CATCH	
			SET @myErrorMessage=CAST(N'ItemName ' AS NVARCHAR(MAX)) + CAST(@ItemName AS NVARCHAR(MAX)) + N' Failed: ' + @myNewLine+ + CAST(ERROR_MESSAGE() AS NVARCHAR(3600))
			RAISERROR (
				@myErrorMessage, -- Message text.
				11 ,--@ErrorSeverity, -- Severity.
				@myErrorState -- State.
				) WITH LOG;
		END CATCH
	END
END
GO
