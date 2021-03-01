Declare @object_set_id int
EXEC msdb.dbo.sp_syspolicy_add_object_set @object_set_name=N'SqlDeep_CheckDataFileSizing_ObjectSet', @facet=N'DataFile', @object_set_id=@object_set_id OUTPUT
Select @object_set_id

Declare @target_set_id int
EXEC msdb.dbo.sp_syspolicy_add_target_set @object_set_name=N'SqlDeep_CheckDataFileSizing_ObjectSet', @type_skeleton=N'Server/Database/FileGroup/File', @type=N'FILE', @enabled=True, @target_set_id=@target_set_id OUTPUT
Select @target_set_id

EXEC msdb.dbo.sp_syspolicy_add_target_set_level @target_set_id=@target_set_id, @type_skeleton=N'Server/Database/FileGroup/File', @level_name=N'File', @condition_name=N'', @target_set_level_id=0
EXEC msdb.dbo.sp_syspolicy_add_target_set_level @target_set_id=@target_set_id, @type_skeleton=N'Server/Database/FileGroup', @level_name=N'FileGroup', @condition_name=N'SqlDeep_NonFilestreamFilegroup', @target_set_level_id=0
EXEC msdb.dbo.sp_syspolicy_add_target_set_level @target_set_id=@target_set_id, @type_skeleton=N'Server/Database', @level_name=N'Database', @condition_name=N'', @target_set_level_id=0


GO

Declare @policy_id int
EXEC msdb.dbo.sp_syspolicy_add_policy @name=N'SqlDeep_CheckDataFileSizing', @condition_name=N'SqlDeep_DataFileSizingCondition', @policy_category=N'SmartAdmin warnings', @description=N'Check standard Data File sizing conditions', @help_text=N'Set Max Data File Size to 80GB and AuthoGrowth to Fixed size', @help_link=N'', @schedule_uid=N'00000000-0000-0000-0000-000000000000', @execution_mode=0, @is_enabled=False, @policy_id=@policy_id OUTPUT, @root_condition_name=N'', @object_set=N'SqlDeep_CheckDataFileSizing_ObjectSet'
Select @policy_id


GO

