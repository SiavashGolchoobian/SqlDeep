SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <6/2/2024>
-- Version:		<3.0.0.0>
-- =============================================
CREATE FUNCTION [repository].[dbafn_get_subscriber_item] 
(	
	@ItemName nvarchar(255), 
	@ItemVersion nvarchar(50) = 'Latest',
	@PublisherName nvarchar(256) = Null
)
RETURNS TABLE 
AS
RETURN 
(
    SELECT TOP 1
		mySubscriber.*
	FROM
		[repository].[Subscriber] AS mySubscriber WITH (READPAST)
	WHERE
		[mySubscriber].[ItemName]=@ItemName
		AND ISNULL(@PublisherName,[mySubscriber].[PublisherName])=[mySubscriber].[PublisherName]
		AND CASE WHEN (@ItemVersion IS NULL OR UPPER(@ItemVersion)=N'LATEST' OR LEN(RTRIM(LTRIM(@ItemVersion)))=0) THEN [mySubscriber].[ItemVersion] ELSE @ItemVersion END=[mySubscriber].[ItemVersion]
	ORDER BY 
		[mySubscriber].[ItemVersion] DESC, 
		[mySubscriber].[UpdateDate] DESC
)

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'repository', 'FUNCTION', N'dbafn_get_subscriber_item', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2013-09-25', 'SCHEMA', N'repository', 'FUNCTION', N'dbafn_get_subscriber_item', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'repository', 'FUNCTION', N'dbafn_get_subscriber_item', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'repository', 'FUNCTION', N'dbafn_get_subscriber_item', NULL, NULL
GO
