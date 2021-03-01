Declare @object_set_id int
EXEC msdb.dbo.sp_syspolicy_add_object_set @object_set_name=N'SqlDeep_CheckSameFileSize_ObjectSet', @facet=N'Database', @object_set_id=@object_set_id OUTPUT
Select @object_set_id

Declare @target_set_id int
EXEC msdb.dbo.sp_syspolicy_add_target_set @object_set_name=N'SqlDeep_CheckSameFileSize_ObjectSet', @type_skeleton=N'Server/Database', @type=N'DATABASE', @enabled=True, @target_set_id=@target_set_id OUTPUT
Select @target_set_id

EXEC msdb.dbo.sp_syspolicy_add_target_set_level @target_set_id=@target_set_id, @type_skeleton=N'Server/Database', @level_name=N'Database', @condition_name=N'', @target_set_level_id=0


GO

Declare @policy_id int
EXEC msdb.dbo.sp_syspolicy_add_policy @name=N'SqlDeep_CheckSameFileSize', @condition_name=N'SqlDeep_CheckSameFileSizeCondition', @policy_category=N'SmartAdmin warnings', @description=N'Check for same File size in same filegroups', @help_text=N'Set Equal file size for files in same filegroup', @help_link=N'', @schedule_uid=N'00000000-0000-0000-0000-000000000000', @execution_mode=0, @is_enabled=False, @policy_id=@policy_id OUTPUT, @root_condition_name=N'', @object_set=N'SqlDeep_CheckSameFileSize_ObjectSet'
Select @policy_id


GO

