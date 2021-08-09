CREATE TABLE [monitor].[JobFailure]
(
[JobFailureId] [int] NOT NULL IDENTITY(1, 1),
[JobId] [int] NOT NULL,
[InstanceId] [int] NOT NULL,
[JobStartDatetime] [datetime] NOT NULL,
[JobFailureDatetime] [datetime] NOT NULL,
[JobFailureStepNumber] [smallint] NOT NULL,
[JobFailureStepName] [varchar] (250) COLLATE Arabic_CI_AS NOT NULL,
[JobFailureMessage] [varchar] (max) COLLATE Arabic_CI_AS NOT NULL,
[JobFailureStepMessage] [varchar] (max) COLLATE Arabic_CI_AS NOT NULL,
[JobStepSeverity] [int] NOT NULL,
[JobStepMessageId] [int] NOT NULL,
[RetriesAttempted] [int] NOT NULL,
[IsEmailSent] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [monitor].[JobFailure] ADD CONSTRAINT [PK_JobFailure] PRIMARY KEY CLUSTERED  ([JobFailureId]) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'monitor', 'TABLE', N'JobFailure', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-05-17', 'SCHEMA', N'monitor', 'TABLE', N'JobFailure', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'monitor', 'TABLE', N'JobFailure', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N' ', 'SCHEMA', N'monitor', 'TABLE', N'JobFailure', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'monitor', 'TABLE', N'JobFailure', NULL, NULL
GO
