CREATE TABLE [trace].[AuditLogDDLEvents]
(
[RecordId] [bigint] NOT NULL IDENTITY(1, 1),
[DbName] [varchar] (128) COLLATE Arabic_CI_AS NULL,
[EventTime] [datetime] NULL,
[LoginName] [varchar] (50) COLLATE Arabic_CI_AS NULL,
[TSQLCommand] [nvarchar] (max) COLLATE Arabic_CI_AS NULL
) ON [Data_OLTP]
GO
ALTER TABLE [trace].[AuditLogDDLEvents] ADD CONSTRAINT [PK_AuditLogDDLEvents] PRIMARY KEY CLUSTERED  ([RecordId]) WITH (FILLFACTOR=85) ON [Data_OLTP]
GO
GRANT INSERT ON  [trace].[AuditLogDDLEvents] TO [role_events]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'trace', 'TABLE', N'AuditLogDDLEvents', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-05-13', 'SCHEMA', N'trace', 'TABLE', N'AuditLogDDLEvents', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-05-13', 'SCHEMA', N'trace', 'TABLE', N'AuditLogDDLEvents', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'کاتالوگ تغییرات ساختاری سیستم', 'SCHEMA', N'trace', 'TABLE', N'AuditLogDDLEvents', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'trace', 'TABLE', N'AuditLogDDLEvents', NULL, NULL
GO
