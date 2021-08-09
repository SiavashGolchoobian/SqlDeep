CREATE TABLE [monitor].[Job]
(
[JobId] [int] NOT NULL IDENTITY(1, 1),
[JobIdGuid] [uniqueidentifier] NOT NULL,
[JobName] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL,
[JobCategoryName] [varchar] (100) COLLATE Arabic_CI_AS NOT NULL,
[IsEnabled] [bit] NOT NULL,
[IsDeleted] [bit] NOT NULL,
[JobCreateDatetime] [datetime] NOT NULL,
[JobLastModifiedDatetime] [datetime] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [monitor].[Job] ADD CONSTRAINT [PK_monitoring_Job] PRIMARY KEY CLUSTERED  ([JobId]) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'monitor', 'TABLE', N'Job', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-05-17', 'SCHEMA', N'monitor', 'TABLE', N'Job', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'monitor', 'TABLE', N'Job', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'', 'SCHEMA', N'monitor', 'TABLE', N'Job', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'monitor', 'TABLE', N'Job', NULL, NULL
GO
