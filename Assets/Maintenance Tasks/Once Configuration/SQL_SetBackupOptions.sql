EXEC sys.sp_configure N'backup compression default', N'1'
GO
EXEC sys.sp_configure N'backup checksum default', N'1'
GO
RECONFIGURE WITH OVERRIDE
GO
