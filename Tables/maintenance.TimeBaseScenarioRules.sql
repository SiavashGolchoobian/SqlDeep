CREATE TABLE [maintenance].[TimeBaseScenarioRules]
(
[ScenarioName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[RuleID] [int] NOT NULL,
[RuleName] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_TimeBaseScenario_Rules_RuleName] DEFAULT (N'SELECT CAST(1 AS BIT) AS RESULT'),
[RuleTrueCondition] [nvarchar] (4000) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_Scenario_Rules_Rule_TrueCondition] DEFAULT (N'SELECT CAST(1 AS BIT) AS RESULT'),
[DestConnectionString] [nvarchar] (4000) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_TimeBaseScenarioRules_DestConnectionString] DEFAULT ('<root><param name="protocol">UNC</param><param name="host">127.0.0.1</param><param name="port"></param><param name="sshhostkey"></param><param name="username"></param><param name="password"></param></root>'),
[DestVarFolderPath] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[DestVarFilename] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[RetantionDays] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_Scenario_Rules_Retantion_Days] DEFAULT ((31)),
[ExistenceCheck] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_TimeBaseScenarioRules_ExistenceCheck] DEFAULT (N'Check All'),
[Enabled] [bit] NOT NULL CONSTRAINT [DF_Scenario_Rules_Enabled] DEFAULT ((-1))
) ON [PRIMARY]
WITH
(
DATA_COMPRESSION = PAGE
)
GO
ALTER TABLE [maintenance].[TimeBaseScenarioRules] ADD CONSTRAINT [PK_Scenario_Rules] PRIMARY KEY CLUSTERED  ([ScenarioName], [RuleID]) WITH (FILLFACTOR=90, PAD_INDEX=ON, DATA_COMPRESSION = PAGE) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[TimeBaseScenarioRules] ADD CONSTRAINT [FK_TimeBaseScenarioRules_Lookup_ExistenceCheck] FOREIGN KEY ([ExistenceCheck]) REFERENCES [maintenance].[Lookup_ExistenceCheck] ([ExistenceCheck]) ON UPDATE CASCADE
GO
ALTER TABLE [maintenance].[TimeBaseScenarioRules] ADD CONSTRAINT [FK_TimeBaseScenarioRules_TimeBaseScenarios] FOREIGN KEY ([ScenarioName]) REFERENCES [maintenance].[TimeBaseScenarios] ([ScenarioName]) ON DELETE CASCADE ON UPDATE CASCADE
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'TimeBaseScenarioRules', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-13', 'SCHEMA', N'maintenance', 'TABLE', N'TimeBaseScenarioRules', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'TimeBaseScenarioRules', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'TimeBaseScenarioRules', NULL, NULL
GO
