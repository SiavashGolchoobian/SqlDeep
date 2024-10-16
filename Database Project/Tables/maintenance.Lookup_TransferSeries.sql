CREATE TABLE [maintenance].[Lookup_TransferSeries]
(
[TransferSeries] [nvarchar] (50) COLLATE Arabic_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [maintenance].[Lookup_TransferSeries] ADD CONSTRAINT [PK_Lookup_TransferSeries] PRIMARY KEY CLUSTERED  ([TransferSeries]) WITH (FILLFACTOR=100, PAD_INDEX=ON) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'TABLE', N'Lookup_TransferSeries', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-13', 'SCHEMA', N'maintenance', 'TABLE', N'Lookup_TransferSeries', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'TABLE', N'Lookup_TransferSeries', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'TABLE', N'Lookup_TransferSeries', NULL, NULL
GO
