CREATE TABLE [dbo].[Notifications]
(
[RecordId] [bigint] NOT NULL IDENTITY(-9223372036854775808, 1),
[Message] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[EmailSubject] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[RecievePhone] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[RecieveEmail] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[EmailMessage] [nvarchar] (max) COLLATE Arabic_CI_AS NULL,
[RecieveCC] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[RecieveBCC] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[NotificationConfigId] [int] NOT NULL,
[EmailAttachmentPath] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[ServerName] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_Notifications_ServerName] DEFAULT (CONVERT([nvarchar](128),@@servername,(0))),
[SessionId] [int] NOT NULL CONSTRAINT [DF_Notifications_SessionId] DEFAULT (CONVERT([int],@@spid,(0))),
[RequestDateTime] [datetime] NOT NULL CONSTRAINT [DF_Notifications_RequestDateTime] DEFAULT (getdate()),
[AppName] [nvarchar] (256) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_Notifications_AppName] DEFAULT (CONVERT([nvarchar](256),app_name(),(0))),
[Username] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_Notifications_Username] DEFAULT (CONVERT([nvarchar](128),suser_sname(),(0))),
[Hostname] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_Notifications_Hostname] DEFAULT (CONVERT([nvarchar](128),host_name(),(0))),
[ClientIP] [nvarchar] (15) COLLATE Arabic_CI_AS NULL CONSTRAINT [DF_Notifications_ClientIP] DEFAULT (CONVERT([nvarchar](15),'127.0.0.1',(0))),
[CheckValue] [int] NULL,
[CalculatedCheckValue] AS (binary_checksum([ServerName],[SessionId],[AppName],[Username],[Hostname],[Message],[EmailSubject],[RecievePhone],[RecieveEmail]))
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Notifications] ADD CONSTRAINT [PK_Notifications] PRIMARY KEY CLUSTERED  ([RecordId]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Notifications] ADD CONSTRAINT [FK_Notifications_NotificationConfig] FOREIGN KEY ([NotificationConfigId]) REFERENCES [dbo].[NotificationConfig] ([RecordId])
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'TABLE', N'Notifications', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-05-09', 'SCHEMA', N'dbo', 'TABLE', N'Notifications', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-31', 'SCHEMA', N'dbo', 'TABLE', N'Notifications', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'جدول محتوای Notifcation', 'SCHEMA', N'dbo', 'TABLE', N'Notifications', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TABLE', N'Notifications', NULL, NULL
GO
