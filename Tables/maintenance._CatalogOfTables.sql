CREATE TABLE [maintenance].[_CatalogOfTables]
(
[TableName] [nvarchar] (200) COLLATE Arabic_CI_AS NOT NULL,
[Type] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[Title] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[_CatalogOfTables] ADD CONSTRAINT [PK__CatalogOfTables] PRIMARY KEY CLUSTERED  ([TableName]) WITH (FILLFACTOR=100, PAD_INDEX=ON) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'_CatalogOfTables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-13', 'SCHEMA', N'maintenance', 'TABLE', N'_CatalogOfTables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'_CatalogOfTables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'_CatalogOfTables', NULL, NULL
GO
