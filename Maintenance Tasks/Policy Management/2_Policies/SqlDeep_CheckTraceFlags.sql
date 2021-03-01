Declare @object_set_id int
EXEC msdb.dbo.sp_syspolicy_add_object_set @object_set_name=N'SqlDeep_CheckTraceFlags_ObjectSet', @facet=N'Server', @object_set_id=@object_set_id OUTPUT
Select @object_set_id

Declare @target_set_id int
EXEC msdb.dbo.sp_syspolicy_add_target_set @object_set_name=N'SqlDeep_CheckTraceFlags_ObjectSet', @type_skeleton=N'Server', @type=N'SERVER', @enabled=True, @target_set_id=@target_set_id OUTPUT
Select @target_set_id



GO

Declare @policy_id int
EXEC msdb.dbo.sp_syspolicy_add_policy @name=N'SqlDeep_CheckTraceFlags', @condition_name=N'SqlDeep_CheckTraceFlagsCondition', @policy_category=N'SmartAdmin warnings', @description=N'Check Standard Tarce Flags Existence', @help_text=N'Set Standard Trace Flags (1118,2371,2549,2562,4199)', @help_link=N'', @schedule_uid=N'00000000-0000-0000-0000-000000000000', @execution_mode=0, @is_enabled=False, @policy_id=@policy_id OUTPUT, @root_condition_name=N'', @object_set=N'SqlDeep_CheckTraceFlags_ObjectSet'
Select @policy_id


GO

