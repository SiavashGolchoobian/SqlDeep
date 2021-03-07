## SqlDeep_FullBackup (Job)

This job runs every day at 1:00:00 AM and has two steps, in first step it takes full backup from both system and user databases and save backup files on a folder(s) specified on Extended Properties of [SqlDeep] database, named "_BackupLocation" and after succssesfull execution, in second step it will delete backup files (with .bak extension) older than 8 days from backup folder(s) specified in "_BackupLocation".

### Remarks

Backup file(s) stored under folder as `<_BackupLocation>\<YYYY>_<MM>\<DD>\` pattern and backup file(s) will stored as below pattern.

`FULL_<database name>_<YYYY>_<MM>_<DD>_<m>of<n>.bak`

In this patterns we have these parameters:

`_BackupLocatin`

Is the root path(s) of storing all backups and specified in **[SqlDeep]** database, under database Extended Properties named "**_BackupLocation**". It can be a single path like `U:\Databases\Backup` or it can be multiple comma seperated paths like `U:\Databases\Backup,V:\Databases\Backup,W:\Databases\Backup`

`YYYY`

Is calendar year in four numeric character format like 2021

`MM`

Is calendar month in two numeric character format like 09

`DD`

Is calendar day in two numeric character format like 30

`database name`

Is the name of each database targeted for backup

`m of n`

This job has a algorithm two split backup file to multiple files with same size for better performance, and spread these files to **<_BackupLocation>** path(s), in this patter `n` is total number of generated files and `m` is the current file number

### Examples

In [SqlDeep] database, under "Extended Properties", the property named "_BackupLocation" has value of "U:\Databases\Backup". After executing and finishing "SqlDeep_FullBackup" job we have backup files stored on disk as below:

`U:\Databases\Backup\2021_09\30\FULL_master_2021_09_30_1of1.bak`

`U:\Databases\Backup\2021_09\30\FULL_msdb_2021_09_30_1of1.bak`

`U:\Databases\Backup\2021_09\30\FULL_model_2021_09_30_1of1.bak`

`U:\Databases\Backup\2021_09\30\FULL_AdventureWorks_2021_09_30_1of1.bak`

`U:\Databases\Backup\2021_09\30\FULL_BigDatabase_2021_09_30_1of2.bak`

`U:\Databases\Backup\2021_09\30\FULL_BigDatabase_2021_09_30_2of2.bak`

In previouse example if "_BackupLocation" has multiple values such as "U:\Databases\Backup,V:\Databases\Backup" the result maybe something like this:

`U:\Databases\Backup\2021_09\30\FULL_master_2021_09_30_1of2.bak``V:\Databases\Backup\2021_09\30\FULL_master_2021_09_30_2of2.bak`

`U:\Databases\Backup\2021_09\30\FULL_msdb_2021_09_30_1of2.bak`

`V:\Databases\Backup\2021_09\30\FULL_msdb_2021_09_30_2of2.bak`

`U:\Databases\Backup\2021_09\30\FULL_model_2021_09_30_1of2.bak`

`V:\Databases\Backup\2021_09\30\FULL_model_2021_09_30_2of2.bak`

`U:\Databases\Backup\2021_09\30\FULL_AdventureWorks_2021_09_30_1of2.bak``V:\Databases\Backup\2021_09\30\FULL_AdventureWorks_2021_09_30_2of2.bak`

`U:\Databases\Backup\2021_09\30\FULL_BigDatabase_2021_09_30_1of4.bak`

`V:\Databases\Backup\2021_09\30\FULL_BigDatabase_2021_09_30_2of4.bak`

`U:\Databases\Backup\2021_09\30\FULL_BigDatabase_2021_09_30_3of4.bak`

`V:\Databases\Backup\2021_09\30\FULL_BigDatabase_2021_09_30_4of4.bak`

### See Also

[dbo].[dbasp_maintenance_take_backup] (Stored Procedure)

[dbo].[dbasp_maintenance_delete_folderfiles] (Stored Procedures)

SqlDeep_DiffBackup (Job)

SqlDeep_LogBackup (Job)
