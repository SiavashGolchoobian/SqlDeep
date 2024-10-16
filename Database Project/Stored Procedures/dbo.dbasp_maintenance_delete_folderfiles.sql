SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <2/4/2015>
-- Version:		<3.0.0.0>
-- Description:	<delete files located in the @FolderPath with extension of @FileExtension and CreateDate older that @OlderThan>
-- Input Parameters:
--	@BackupExtension:	'xxx' //File extension of backup files
-- =============================================
CREATE PROCEDURE [dbo].[dbasp_maintenance_delete_folderfiles]
	 @FolderPath nvarchar(MAX)
	,@FileExtension nvarchar(3)
	,@OlderThan datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	SET NOCOUNT ON;
	DECLARE @myCurrentRoot nvarchar(255);
	DECLARE @myCurrentFolder nvarchar(255);
	DECLARE @myCursor_Roots Cursor;
	DECLARE @myCursor_Folders Cursor;
	DECLARE @ReturnValue bit;
	DECLARE @myDirTree TABLE (rowno int identity,folder nvarchar(255),depth int, parentrow int)
	DECLARE @myFolders TABLE (folder nvarchar(255))
	DECLARE @myFileType INT
	DECLARE @myOsPathSeperator CHAR(1);

	SET @myOsPathSeperator = CASE WHEN CHARINDEX('Linux',@@VERSION,1)<>0 THEN N'/' ELSE N'\' END
	SET @ReturnValue= cast(0 as bit)	--0 is OK and 1 is Error
	SET @myCursor_Roots=CURSOR For
		Select [myList].[Parameter] AS [Path] FROM [dbo].[dbafn_split](N',',@FolderPath) AS myList 

	OPEN @myCursor_Roots
	FETCH NEXT FROM @myCursor_Roots INTO @myCurrentRoot
		WHILE @@FETCH_STATUS=0
		BEGIN
			IF RIGHT (@myCurrentRoot,1)!=@myOsPathSeperator
				SET @myCurrentRoot=@myCurrentRoot + @myOsPathSeperator

			DELETE FROM @myDirTree
			DELETE FROM @myFolders
			INSERT INTO @myDirTree (folder,depth) exec xp_dirtree @myCurrentRoot
			UPDATE @myDirTree SET 
				folder = folder + @myOsPathSeperator,
				parentrow = (select top 1 rowno from @myDirTree as mySecond where mySecond.depth=myFirst.depth-1 and mySecond.rowno<myFirst.rowno order by rowno desc)
			FROM
				@myDirTree as myFirst

			;With myCte AS (
				SELECT
					myParent.rowno
					,CAST(myParent.folder as nvarchar(4000)) as folder
					,myParent.parentrow
				FROM
					@myDirTree as myParent
				WHERE
					myParent.depth=1
				UNION ALL
				SELECT
					myChild.rowno
					,cast(myCte.folder + myChild.folder as nvarchar(4000)) as folder
					,myChild.parentrow
				FROM
					@myDirTree as myChild
					INNER JOIN myCte on myChild.parentrow=myCte.rowno
				WHERE
					myChild.depth>1
			)

			INSERT INTO @myFolders (folder) 
				SELECT @myCurrentRoot + folder FROM myCte
				UNION ALL
				SELECT @myCurrentRoot

			SET @myCursor_Folders=CURSOR For
				SELECT folder FROM @myFolders

			Open @myCursor_Folders
			FETCH NEXT FROM @myCursor_Folders INTO @myCurrentFolder
				WHILE @@FETCH_STATUS=0
				BEGIN
					--=====Start of Removing File
					BEGIN TRY
						--SET @CurrentFolderPath = LEFT(@CurrentFilePath, LEN(@CurrentFilePath) - CHARINDEX('\',REVERSE(@CurrentFilePath),1)) + '\'
						--Parameters:
						--	File Type = 0 for backup files or 1 for report files.
						--	Folder Path = The folder to delete files. The path must end with a backslash "\".
						--	File Extension = This could be 'BAK' or 'TRN' or whatever you normally use.
						--	Date = The cutoff date for what files need to be deleted.
						--	Subfolder = 0 to ignore subfolders, 1 to delete files in subfolders.
						IF UPPER(@FileExtension) IN (N'BAK',N'TRN')
						BEGIN
							SET @myFileType=0
						END
						ELSE
						BEGIN
							SET @myFileType=1
						END

						EXECUTE master.dbo.xp_delete_file @myFileType,@myCurrentFolder,@FileExtension,@OlderThan,0
						Print N'(only backup or report files can be deleted!) Delete *.' + CAST(@FileExtension AS NVARCHAR(10)) + N' files that older than ' + CAST(@OlderThan AS NVARCHAR(255)) + N' from ' + @myCurrentFolder
						SET @ReturnValue= cast(1 as bit)
					END TRY
					BEGIN CATCH
						DECLARE @CustomMessage nvarchar(255)
						SET @CustomMessage='Delete backup or report files error on ' + CAST(@myCurrentFolder as nvarchar)
						EXECUTE [dbo].[dbasp_get_error_info] @CustomMessage,1,0,1,0,NULL
					END CATCH
					--=====End of Removing File
					FETCH NEXT FROM @myCursor_Folders INTO @myCurrentFolder
				END
			CLOSE @myCursor_Folders;
			DEALLOCATE @myCursor_Folders;

			--=====End of Root Folder iteration
			FETCH NEXT FROM @myCursor_Roots INTO @myCurrentRoot
		END
	CLOSE @myCursor_Roots;
	DEALLOCATE @myCursor_Roots;
	Return @ReturnValue
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_delete_folderfiles', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-02-04', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_delete_folderfiles', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-04-10', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_delete_folderfiles', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.1', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_maintenance_delete_folderfiles', NULL, NULL
GO
