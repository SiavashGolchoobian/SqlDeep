CREATE TABLE [maintenance].[TimeBaseScenarios]
(
[ScenarioName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[Enabled] [bit] NOT NULL CONSTRAINT [DF_Scenarios_Enabled] DEFAULT ((-1))
) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[TimeBaseScenarios] ADD CONSTRAINT [PK_TimeBaseScenarios] PRIMARY KEY CLUSTERED  ([ScenarioName]) WITH (FILLFACTOR=100, PAD_INDEX=ON) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'TimeBaseScenarios', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-12', 'SCHEMA', N'maintenance', 'TABLE', N'TimeBaseScenarios', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'TimeBaseScenarios', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'TimeBaseScenarios', NULL, NULL
GO
