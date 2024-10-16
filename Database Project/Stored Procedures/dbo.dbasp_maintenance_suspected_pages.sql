SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		<Golchoobian>
-- Create date: <01/11/2014>
-- Version:		<3.0.0.0>
-- Description:	<Alter recipients for suspected pages on database>
-- Input Parameters:
--	@mail_profile_name:	'...'	\\SQL Server profile name for sending email
--	@mail_recipients:	'...'	\\Email of recipients of notice
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_suspected_pages] (
	@mail_profile_name nvarchar(255),
	@mail_recipients nvarchar(255)
	)
AS
BEGIN

DECLARE @SuspectedPages int
DECLARE @ErrorMsg nvarchar(255)
SELECT @SuspectedPages=COUNT(*) FROM msdb.dbo.suspect_pages
IF @SuspectedPages>0
	BEGIN
		SET @ErrorMsg = 'You have ' + CAST(@SuspectedPages as nvarchar) + ' Suspected pages on ' + @@SERVERNAME + '. You can use DBCC CheckDB to recover it or you can restore suspected pages from backups.'
		EXEC master.sys.xp_logevent 50001, @ErrorMsg , ERROR
		EXEC msdb.dbo.sp_send_dbmail
			@profile_name = @mail_profile_name,	--'Sql Server Database Mail Profile - Public'
			@recipients = @mail_recipients,		--'siavash.golchoobian@gmail.com'
			@query = 'SELECT * FROM msdb.dbo.suspect_pages',
			@subject = 'Suspected Page Detection',
			@importance= 'High',
			@attach_query_result_as_file = 1 ;
			SELECT * FROM msdb.dbo.suspect_pages
	END

END

GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_suspected_pages', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-01-11', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_suspected_pages', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_suspected_pages', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_suspected_pages', NULL, NULL
GO
