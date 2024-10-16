SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <6/2/2024>
-- Version:		<3.0.0.0>
-- =============================================
CREATE FUNCTION [repository].[dbafn_get_subscriber_dependentitems] 
(	
	@SubscriberItemId bigint
)
RETURNS TABLE 
AS
RETURN 
(
	With myCte AS (
		SELECT
			[myActualItems].[SubscriberItemId],
			[myActualItems].[PublisherName],
			[myActualItems].[Metadata]
		FROM
			(
			SELECT 
				[mySubscriber].[PublisherName],
				[myMetadata].[dependency].[value]('@name','nvarchar(255)') AS ItemName,
				[myMetadata].[dependency].[value]('@version','nvarchar(50)') AS ItemVersion
			FROM 
				[repository].[Subscriber] AS mySubscriber WITH (READPAST)
				CROSS APPLY [mySubscriber].[Metadata].nodes('/meatadata/DependentItems/Item') AS myMetadata([dependency])
			WHERE
				[mySubscriber].[SubscriberItemId]=@SubscriberItemId
				AND [mySubscriber].[Metadata].exist('/meatadata/DependentItems/Item')=1 
			) AS myDepndentItems
			CROSS APPLY [repository].[dbafn_get_subscriber_item] ([myDepndentItems].[ItemName],[myDepndentItems].[ItemVersion],[myDepndentItems].[PublisherName]) AS myActualItems
		UNION ALL
		SELECT
			[myActualItems].[SubscriberItemId],
			[myActualItems].[PublisherName],
			[myActualItems].[Metadata]
		FROM
			(
			SELECT 
				[mySubscriber].[PublisherName],
				[myMetadata].[dependency].[value]('@name','nvarchar(255)') AS ItemName,
				[myMetadata].[dependency].[value]('@version','nvarchar(50)') AS ItemVersion
			FROM 
				myCte AS mySubscriber
				CROSS APPLY [mySubscriber].[Metadata].nodes('/meatadata/DependentItems/Item') AS myMetadata([dependency])
			WHERE
				[mySubscriber].[Metadata].exist('/meatadata/DependentItems/Item')=1 
			) AS myDepndentItems
			CROSS APPLY [repository].[dbafn_get_subscriber_item] ([myDepndentItems].[ItemName],[myDepndentItems].[ItemVersion],[myDepndentItems].[PublisherName]) AS myActualItems
	)
	SELECT
		[mySubscriber].*
	FROM
		(
		SELECT 
			[myCte].[SubscriberItemId] 
		FROM 
			myCte
		GROUP BY
			[myCte].[SubscriberItemId] 
		) AS myDependentItems
		INNER JOIN [repository].[Subscriber] AS mySubscriber WITH (READPAST) ON [mySubscriber].[SubscriberItemId]=[myDependentItems].[SubscriberItemId]
)

GO
