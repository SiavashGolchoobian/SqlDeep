CREATE TABLE [dbo].[CounterDetails]
(
[CounterID] [int] NOT NULL IDENTITY(1, 1),
[MachineName] [varchar] (1024) COLLATE Arabic_CI_AS NOT NULL,
[ObjectName] [varchar] (1024) COLLATE Arabic_CI_AS NOT NULL,
[CounterName] [varchar] (1024) COLLATE Arabic_CI_AS NOT NULL,
[CounterType] [int] NOT NULL,
[DefaultScale] [int] NOT NULL,
[InstanceName] [varchar] (1024) COLLATE Arabic_CI_AS NULL,
[InstanceIndex] [int] NULL,
[ParentName] [varchar] (1024) COLLATE Arabic_CI_AS NULL,
[ParentObjectID] [int] NULL,
[TimeBaseA] [int] NULL,
[TimeBaseB] [int] NULL
) ON [Data_OLTP]
GO
ALTER TABLE [dbo].[CounterDetails] ADD CONSTRAINT [PK__CounterD__F12879E4164452B1] PRIMARY KEY CLUSTERED  ([CounterID]) WITH (FILLFACTOR=100, PAD_INDEX=ON) ON [Data_OLTP]
GO
GRANT INSERT ON  [dbo].[CounterDetails] TO [role_kpi_insert]
GO
GRANT SELECT ON  [dbo].[CounterDetails] TO [role_kpi_insert]
GO
GRANT SELECT ON  [dbo].[CounterDetails] TO [role_kpi_select]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'TABLE', N'CounterDetails', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-01-01', 'SCHEMA', N'dbo', 'TABLE', N'CounterDetails', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'TABLE', N'CounterDetails', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TABLE', N'CounterDetails', NULL, NULL
GO
