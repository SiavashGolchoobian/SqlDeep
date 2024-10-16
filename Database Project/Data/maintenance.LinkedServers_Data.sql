SET IDENTITY_INSERT [maintenance].[LinkedServers] ON
INSERT INTO [maintenance].[LinkedServers] ([RecordId], [Name], [Product], [Provider], [DataSource], [Catalog], [UserName], [Password], [Priority], [Enabled]) VALUES (1, N'QomDatabase', N'', N'SQLNCLI11', N'LSNRxxx,1433', N'TestDb', N'LinkedUser', N'LinkedServerPass', 1, 1)
INSERT INTO [maintenance].[LinkedServers] ([RecordId], [Name], [Product], [Provider], [DataSource], [Catalog], [UserName], [Password], [Priority], [Enabled]) VALUES (2, N'QomDatabase', N'', N'SQLNCLI11', N'DB-Cn-DLV0n\Instance,1433', N'TestDb', NULL, NULL, 2, 1)
INSERT INTO [maintenance].[LinkedServers] ([RecordId], [Name], [Product], [Provider], [DataSource], [Catalog], [UserName], [Password], [Priority], [Enabled]) VALUES (3, N'QomDatabase', N'', N'SQLNCLI11', N'DB-Cm-DLV0m\Instance,5210', N'TestDb', N'Test', N'LinkedServerPass', 3, 1)
SET IDENTITY_INSERT [maintenance].[LinkedServers] OFF
