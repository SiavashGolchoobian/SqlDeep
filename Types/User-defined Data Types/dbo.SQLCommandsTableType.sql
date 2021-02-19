CREATE TYPE [dbo].[SQLCommandsTableType] AS TABLE
(
[Id] [bigint] NULL,
[SQLStatement] [nvarchar] (max) COLLATE Arabic_CI_AS NULL
)
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'TYPE', N'SQLCommandsTableType', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2016-06-24', 'SCHEMA', N'dbo', 'TYPE', N'SQLCommandsTableType', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'dbo', 'TYPE', N'SQLCommandsTableType', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TYPE', N'SQLCommandsTableType', NULL, NULL
GO
