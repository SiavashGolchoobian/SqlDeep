CREATE TABLE [monitor].[JobAlert]
(
[JobAlertId] [int] NOT NULL IDENTITY(1, 1),
[JobName] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL,
[SendSMS] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[SendEmail] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[TicketRegister] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[SendAlertAfterMinute] [int] NULL,
[IsEnabled] [bit] NOT NULL CONSTRAINT [DF_JobAlert_IsEnabled] DEFAULT ((1))
) ON [PRIMARY]
GO
ALTER TABLE [monitor].[JobAlert] ADD CONSTRAINT [PK_JobAlert] PRIMARY KEY CLUSTERED  ([JobAlertId]) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'monitor', 'TABLE', N'JobAlert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-05-17', 'SCHEMA', N'monitor', 'TABLE', N'JobAlert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'monitor', 'TABLE', N'JobAlert', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N' ', 'SCHEMA', N'monitor', 'TABLE', N'JobAlert', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'monitor', 'TABLE', N'JobAlert', NULL, NULL
GO
