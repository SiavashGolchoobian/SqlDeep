CREATE TABLE [monitor].[JobActivity]
(
[JobActivityID] [int] NOT NULL IDENTITY(1, 1),
[JobID] [uniqueidentifier] NOT NULL,
[JobName] [varchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[RunRequestedDate] [datetime] NOT NULL,
[IsProcessed] [bit] NOT NULL CONSTRAINT [DF_JobActivity_IsProcessed] DEFAULT ((0))
) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'Author', N'Zahra Saffarpour', 'SCHEMA', N'monitor', 'TABLE', N'JobActivity', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2020-06-04', 'SCHEMA', N'monitor', 'TABLE', N'JobActivity', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2021-07-31', 'SCHEMA', N'monitor', 'TABLE', N'JobActivity', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N' ', 'SCHEMA', N'monitor', 'TABLE', N'JobActivity', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'monitor', 'TABLE', N'JobActivity', NULL, NULL
GO
