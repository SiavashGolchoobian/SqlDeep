CREATE TABLE [maintenance].[LinkedServers]
(
[RecordId] [int] NOT NULL IDENTITY(1, 1),
[Name] [sys].[sysname] NOT NULL,
[Product] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF__LinkedSer__Produ__7E1E7D82] DEFAULT (N''),
[Provider] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL,
[DataSource] [nvarchar] (4000) COLLATE Arabic_CI_AS NOT NULL,
[Catalog] [sys].[sysname] NOT NULL CONSTRAINT [DF__LinkedSer__Catal__7F12A1BB] DEFAULT (''),
[UserName] [nvarchar] (256) COLLATE Arabic_CI_AS NULL,
[Password] [nvarchar] (255) COLLATE Arabic_CI_AS MASKED WITH (FUNCTION = 'default()') NULL,
[Priority] [int] NOT NULL,
[Enabled] [bit] NOT NULL CONSTRAINT [DF__LinkedSer__Enabl__0006C5F4] DEFAULT ((1))
) ON [Data_OLTP]
GO
ALTER TABLE [maintenance].[LinkedServers] ADD CONSTRAINT [PK__LinkedSe__FBDF78E92A65366A] PRIMARY KEY CLUSTERED  ([RecordId]) WITH (FILLFACTOR=85) ON [Data_OLTP]
GO
CREATE UNIQUE NONCLUSTERED INDEX [UNQ_Link] ON [maintenance].[LinkedServers] ([Name], [Priority]) WHERE ([Enabled]=(1)) WITH (FILLFACTOR=85) ON [Index_All]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'LinkedServers', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2018-06-12', 'SCHEMA', N'maintenance', 'TABLE', N'LinkedServers', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-06-12', 'SCHEMA', N'maintenance', 'TABLE', N'LinkedServers', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'LinkedServers', NULL, NULL
GO
