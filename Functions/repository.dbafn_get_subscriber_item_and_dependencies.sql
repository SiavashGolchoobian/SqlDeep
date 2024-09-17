SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <6/2/2024>
-- Version:		<3.0.0.0>
-- =============================================
CREATE FUNCTION [repository].[dbafn_get_subscriber_item_and_dependencies] 
(	
	@ItemName nvarchar(255), 
	@ItemVersion nvarchar(50) = 'Latest',
	@PublisherName nvarchar(256) = Null
)
RETURNS TABLE 
AS
RETURN 
(
	With myItem AS (SELECT * FROM [repository].[dbafn_get_subscriber_item] (@ItemName,@ItemVersion,@PublisherName) AS myItem)
	SELECT [myItem].* FROM myItem
	UNION ALL
	SELECT	[myDependentItems].* FROM myItem CROSS APPLY [repository].[dbafn_get_subscriber_dependentitems] ([myItem].[SubscriberItemId]) AS myDependentItems
)

GO
