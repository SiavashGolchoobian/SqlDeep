CREATE TABLE [trace].[Events]
(
[ID] [bigint] NOT NULL CONSTRAINT [DF_Events_ID] DEFAULT (NEXT VALUE FOR [trace].[Sequence-Events_ID]),
[AlertTime] [datetime] NOT NULL,
[AlertType] [varchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[AlertText] [xml] NULL
) ON [Data_OLTP]
GO
ALTER TABLE [trace].[Events] ADD CONSTRAINT [PK_Events] PRIMARY KEY CLUSTERED  ([ID]) WITH (FILLFACTOR=90, PAD_INDEX=ON) ON [Data_OLTP]
GO
GRANT INSERT ON  [trace].[Events] TO [role_events]
GO
GRANT INSERT ON  [trace].[Events] TO [role_perfmon_collector]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'trace', 'TABLE', N'Events', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-05-28', 'SCHEMA', N'trace', 'TABLE', N'Events', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'trace', 'TABLE', N'Events', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'trace', 'TABLE', N'Events', NULL, NULL
GO
