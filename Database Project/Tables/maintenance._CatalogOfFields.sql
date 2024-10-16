CREATE TABLE [maintenance].[_CatalogOfFields]
(
[TableName] [nvarchar] (200) COLLATE Arabic_CI_AS NOT NULL,
[FieldName] [nvarchar] (200) COLLATE Arabic_CI_AS NOT NULL,
[Title] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[Type] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[Lookup] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[DefaultValue] [nvarchar] (4000) COLLATE Arabic_CI_AS NULL,
[Priority] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[_CatalogOfFields] ADD CONSTRAINT [PK__CatalogOfFields] PRIMARY KEY CLUSTERED  ([TableName], [FieldName]) WITH (FILLFACTOR=70, PAD_INDEX=ON) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[_CatalogOfFields] ADD CONSTRAINT [FK__CatalogOfFields__CatalogOfTables] FOREIGN KEY ([TableName]) REFERENCES [maintenance].[_CatalogOfTables] ([TableName]) ON DELETE CASCADE ON UPDATE CASCADE
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'_CatalogOfFields', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-13', 'SCHEMA', N'maintenance', 'TABLE', N'_CatalogOfFields', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'_CatalogOfFields', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'_CatalogOfFields', NULL, NULL
GO
