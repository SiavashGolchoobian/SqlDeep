CREATE TABLE [dbo].[NotificationConfig]
(
[RecordId] [int] NOT NULL IDENTITY(1, 1),
[Name] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[EmailFrom] [varchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[EmailFromPassword] [varchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[EmailPort] [int] NOT NULL,
[EmailSMTP] [varchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[ConfigKey] [varchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[IsDefault] [bit] NOT NULL CONSTRAINT [DF_NotificationConfig_IsDefaulted] DEFAULT ((0)),
[IsEnable] [bit] NOT NULL CONSTRAINT [DF_NotificationConfig_IsEnabled] DEFAULT ((1)),
[CreatedDate] [datetime] NOT NULL CONSTRAINT [DF_NotificationConfig_CreatedDate] DEFAULT (getdate()),
[CheckValue] [int] NOT NULL,
[CalculatedCheckValue] AS (binary_checksum([Name],[EmailFrom],[EmailFromPassword],[EmailPort],[EmailSMTP],[ConfigKey]))
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[NotificationConfig] ADD CONSTRAINT [PK_NotificationConfig] PRIMARY KEY CLUSTERED  ([RecordId]) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'dbo', 'TABLE', N'NotificationConfig', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2019-05-09', 'SCHEMA', N'dbo', 'TABLE', N'NotificationConfig', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-31', 'SCHEMA', N'dbo', 'TABLE', N'NotificationConfig', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'جدول کانفیگ اطلاع رسانی', 'SCHEMA', N'dbo', 'TABLE', N'NotificationConfig', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TABLE', N'NotificationConfig', NULL, NULL
GO
