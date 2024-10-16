CREATE TABLE [repository].[Subscriber]
(
[SubscriberItemId] [bigint] NOT NULL IDENTITY(-9223372036854775807, 1),
[SubscriberDownloadDate] [datetime] NOT NULL CONSTRAINT [DF_Repository_Subscriber_SubscriberDownloadDate] DEFAULT (getdate()),
[SubscriberExecutionResult] [nvarchar] (20) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_Repository_Subscriber_SubscriberExecutionResult] DEFAULT (N'NOT EXECUTED'),
[SubscriberItemChecksum] AS (binary_checksum([ItemId],[ItemName],[ItemType],[ItemContent],[Metadata])) PERSISTED,
[PublisherName] [nvarchar] (256) COLLATE Arabic_CI_AS NOT NULL,
[ItemId] [bigint] NOT NULL,
[ItemName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[ItemType] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[ItemVersion] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[ItemContent] [varbinary] (max) NOT NULL,
[Tags] [nvarchar] (4000) COLLATE Arabic_CI_AS NOT NULL,
[CreateDate] [datetime] NOT NULL,
[UpdateDate] [datetime] NOT NULL,
[Description] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[IsEnabled] [bit] NOT NULL,
[Metadata] [xml] NULL,
[ItemChecksum] [int] NOT NULL,
[RowVersion] [binary] (8) NOT NULL
) ON [Data_OLTP]
GO
ALTER TABLE [repository].[Subscriber] ADD CONSTRAINT [CHK_Repository_Subscriber_SubscriberExecutionResult] CHECK (([SubscriberExecutionResult]='FAILED' OR [SubscriberExecutionResult]='SUCCEEDED' OR [SubscriberExecutionResult]=N'NOT EXECUTED'))
GO
ALTER TABLE [repository].[Subscriber] ADD CONSTRAINT [PK_Repository_Subscriber] PRIMARY KEY CLUSTERED ([SubscriberItemId]) WITH (FILLFACTOR=85, PAD_INDEX=ON) ON [Data_OLTP]
GO
CREATE UNIQUE NONCLUSTERED INDEX [UNQ_Repository_Subscriber] ON [repository].[Subscriber] ([PublisherName], [ItemName], [ItemVersion]) WITH (FILLFACTOR=85) ON [Data_OLTP]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'repository', 'TABLE', N'Subscriber', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-06-04', 'SCHEMA', N'repository', 'TABLE', N'Subscriber', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2019-06-04', 'SCHEMA', N'repository', 'TABLE', N'Subscriber', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'repository', 'TABLE', N'Subscriber', NULL, NULL
GO
