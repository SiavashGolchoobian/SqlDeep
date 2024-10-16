SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <7/12/2014>
-- Version:		<3.0.0.0>
-- Description:	<Translate connection string to its parameters>
-- =============================================
CREATE FUNCTION [maintenance].[connection_translator] (@ConnectionString nvarchar(4000))
RETURNS 
@Answer TABLE 
(
	[ConnectionString] nvarchar(4000),
	[Type] nvarchar(3),
	[Host] nvarchar(255), 
	[Port] int,
	[SshHostKey] nvarchar(255),
	[UserName] nvarchar(255), 
	[Password] nvarchar(255)
)
AS
BEGIN
	Declare @XMLConnectionString xml
	Declare @Type nvarchar(3)
	Declare @Host nvarchar(255)
	Declare @Port varchar(255)
	Declare @SshHostKey nvarchar(255)
	Declare @UserName nvarchar(255)
	Declare @Password nvarchar(255)
	
	SET @XMLConnectionString = CAST(@ConnectionString as XML)

	select @Type = T2.name.value('(.)[1]','nvarchar(3)')
	from @XMLConnectionString.nodes('/root/param') as T2(name)
	where T2.name.exist('(.[(@name) = "protocol"])')=1

	select @Host = T2.name.value('(.)[1]','nvarchar(255)')
	from @XMLConnectionString.nodes('/root/param') as T2(name)
	where T2.name.exist('(.[(@name) = "host"])')=1

	select @Port = T2.name.value('(.)[1]','nvarchar(255)')
	from @XMLConnectionString.nodes('/root/param') as T2(name)
	where T2.name.exist('(.[(@name) = "port"])')=1

	select @SshHostKey = T2.name.value('(.)[1]','nvarchar(255)')
	from @XMLConnectionString.nodes('/root/param') as T2(name)
	where T2.name.exist('(.[(@name) = "sshhostkey"])')=1

	select @UserName = T2.name.value('(.)[1]','nvarchar(255)')
	from @XMLConnectionString.nodes('/root/param') as T2(name)
	where T2.name.exist('(.[(@name) = "username"])')=1

	select @Password = T2.name.value('(.)[1]','nvarchar(255)')
	from @XMLConnectionString.nodes('/root/param') as T2(name)
	where T2.name.exist('(.[(@name) = "password"])')=1

	INSERT INTO @Answer ([ConnectionString],[Type],[Host],[Port],[SshHostKey],[UserName],[Password])
				VALUES  (@ConnectionString,@Type,@Host,CAST(@Port as int),@SshHostKey,@UserName,@Password)

	RETURN 
END

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'maintenance', 'FUNCTION', N'connection_translator', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-07-12', 'SCHEMA', N'maintenance', 'FUNCTION', N'connection_translator', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'maintenance', 'FUNCTION', N'connection_translator', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'maintenance', 'FUNCTION', N'connection_translator', NULL, NULL
GO
