CREATE SEQUENCE [trace].[Sequence-Events_ID]
AS bigint
START WITH 1
INCREMENT BY 1
MINVALUE 1
MAXVALUE 9223372036854775807
CYCLE
CACHE 10
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'trace', 'SEQUENCE', N'Sequence-Events_ID', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-14', 'SCHEMA', N'trace', 'SEQUENCE', N'Sequence-Events_ID', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-07-03', 'SCHEMA', N'trace', 'SEQUENCE', N'Sequence-Events_ID', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'trace', 'SEQUENCE', N'Sequence-Events_ID', NULL, NULL
GO
