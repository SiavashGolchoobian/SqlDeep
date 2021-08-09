CREATE TABLE [dbo].[NotificationProcess]
(
[RecordId] [bigint] NOT NULL IDENTITY(-9223372036854775808, 1),
[NotificationId] [bigint] NOT NULL,
[ProcessType] [varchar] (5) COLLATE Arabic_CI_AS NOT NULL,
[ProcessDatetime] [datetime] NOT NULL,
[ProcessDate] AS (CONVERT([date],[ProcessDateTime],(0))) PERSISTED,
[ProcessPersianDate] [varchar] (10) COLLATE Arabic_CI_AS NOT NULL,
[ResponseStatus] [nvarchar] (50) COLLATE Arabic_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[NotificationProcess] ADD CONSTRAINT [PK_NotificationProcess] PRIMARY KEY CLUSTERED  ([RecordId]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [NCIX_NotificationIdProcessType] ON [dbo].[NotificationProcess] ([NotificationId], [ProcessType]) WITH (DATA_COMPRESSION = ROW) ON [PRIMARY]
GO
ALTER TABLE [dbo].[NotificationProcess] ADD CONSTRAINT [FK_NotificationProcess_Notifications] FOREIGN KEY ([NotificationId]) REFERENCES [dbo].[Notifications] ([RecordId])
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'TABLE', N'NotificationProcess', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-05-09', 'SCHEMA', N'dbo', 'TABLE', N'NotificationProcess', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-31', 'SCHEMA', N'dbo', 'TABLE', N'NotificationProcess', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'جدول  وضعیت Notification های ارسال شده', 'SCHEMA', N'dbo', 'TABLE', N'NotificationProcess', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TABLE', N'NotificationProcess', NULL, NULL
GO
