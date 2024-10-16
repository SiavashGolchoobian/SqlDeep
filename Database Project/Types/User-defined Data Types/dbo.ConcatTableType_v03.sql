CREATE TYPE [dbo].[ConcatTableType_v03] AS TABLE
(
[Value] [nvarchar] (max) COLLATE Arabic_CI_AS NOT NULL
)
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'TYPE', N'ConcatTableType_v03', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-12', 'SCHEMA', N'dbo', 'TYPE', N'ConcatTableType_v03', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'TYPE', N'ConcatTableType_v03', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TYPE', N'ConcatTableType_v03', NULL, NULL
GO
