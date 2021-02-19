CREATE TABLE [maintenance].[Variables]
(
[Variable_Name] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL,
[Variable_Description] [nvarchar] (255) COLLATE Arabic_CI_AS NOT NULL,
[Variable_Source] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL CONSTRAINT [DF_Variables_Variable_Source] DEFAULT ('TIMEFLAGS')
) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[Variables] ADD CONSTRAINT [PK_Variables] PRIMARY KEY CLUSTERED  ([Variable_Name]) WITH (FILLFACTOR=100, PAD_INDEX=ON) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[Variables] ADD CONSTRAINT [FK_Variables_Lookup_VariableSource] FOREIGN KEY ([Variable_Source]) REFERENCES [maintenance].[Lookup_VariableSource] ([Name]) ON UPDATE CASCADE
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'Variables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-12', 'SCHEMA', N'maintenance', 'TABLE', N'Variables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'Variables', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'Variables', NULL, NULL
GO
