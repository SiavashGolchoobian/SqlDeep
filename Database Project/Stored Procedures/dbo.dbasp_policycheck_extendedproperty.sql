SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <2/25/2015>
-- Version:		<3.0.0.0>
-- Description:	<Check for extended property exists>
-- Input Parameters:
--	@PropertyName:	nvarchar
--	@DatabaseName:	nvarchar
-- =============================================
CREATE PROC [dbo].[dbasp_policycheck_extendedproperty] (@PropertyName nvarchar(255), @DatabaseID int)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @Command nvarchar(4000);

	DECLARE @Parameters nvarchar(255);
	DECLARE @Result int;

	SET @Command=N'SELECT @Result=COUNT(*) FROM [' + DB_Name(@DatabaseID) + N'].sys.extended_properties WHERE name = @PropertyName and class=0'
	SET @Parameters = N'@PropertyName nvarchar(255), @Result int OUTPUT'
	Execute sp_executesql @Command, @Parameters, @PropertyName, @Result OUTPUT
	Select @Result

----========================================Create Condition
--DECLARE @condition_id INT
--EXEC msdb.dbo.sp_syspolicy_add_condition @name=N'DBA_CheckExtendedPropertiesCondition', @description=N'Standard Extended Properties does not set correctly', @facet=N'Database', @expression=N'<Operator>
--  <TypeClass>Bool</TypeClass>
--  <OpType>EQ</OpType>
--  <Count>2</Count>
--  <Function>
--    <TypeClass>Numeric</TypeClass>
--    <FunctionType>ExecuteSql</FunctionType>
--    <ReturnType>Numeric</ReturnType>
--    <Count>2</Count>
--    <Constant>
--      <TypeClass>String</TypeClass>
--      <ObjType>System.String</ObjType>
--      <Value>Numeric</Value>
--    </Constant>
--    <Function>
--      <TypeClass>String</TypeClass>
--      <FunctionType>Concatenate</FunctionType>
--      <ReturnType>String</ReturnType>
--      <Count>2</Count>
--      <Constant>
--        <TypeClass>String</TypeClass>
--        <ObjType>System.String</ObjType>
--        <Value>[SqlDeep].[dbo].[dbasp_policycheck_extendedproperty] ''''_ShrinkLogToSizeMB'''',</Value>
--      </Constant>
--      <Function>
--        <TypeClass>String</TypeClass>
--        <FunctionType>String</FunctionType>
--        <ReturnType>String</ReturnType>
--        <Count>1</Count>
--        <Attribute>
--          <TypeClass>Numeric</TypeClass>
--          <Name>ID</Name>
--        </Attribute>
--      </Function>
--    </Function>
--  </Function>
--  <Constant>
--    <TypeClass>Numeric</TypeClass>
--    <ObjType>System.Double</ObjType>
--    <Value>1</Value>
--  </Constant>
--</Operator>', @is_name_condition=0, @obj_name=N'', @condition_id=@condition_id OUTPUT
--SELECT @condition_id
--GO

----========================================Create Plocy
--Declare @object_set_id int
--EXEC msdb.dbo.sp_syspolicy_add_object_set @object_set_name=N'DBA_CheckExtendedProperties_ObjectSet', @facet=N'Database', @object_set_id=@object_set_id OUTPUT
--Select @object_set_id

--Declare @target_set_id int
--EXEC msdb.dbo.sp_syspolicy_add_target_set @object_set_name=N'DBA_CheckExtendedProperties_ObjectSet', @type_skeleton=N'Server/Database', @type=N'DATABASE', @enabled=True, @target_set_id=@target_set_id OUTPUT
--Select @target_set_id

--EXEC msdb.dbo.sp_syspolicy_add_target_set_level @target_set_id=@target_set_id, @type_skeleton=N'Server/Database', @level_name=N'Database', @condition_name=N'', @target_set_level_id=0
--GO

--Declare @policy_id int
--EXEC msdb.dbo.sp_syspolicy_add_policy @name=N'DBA_CheckExtendedProperties', @condition_name=N'DBA_CheckExtendedPropertiesCondition', @policy_category=N'SmartAdmin warnings', @description=N'Check Standard Extended Properties Existence', @help_text=N'Set Standard Properties (_ShrinkLogToSizeMB)', @help_link=N'', @schedule_uid=N'00000000-0000-0000-0000-000000000000', @execution_mode=0, @is_enabled=False, @policy_id=@policy_id OUTPUT, @root_condition_name=N'', @object_set=N'DBA_CheckExtendedProperties_ObjectSet'
--Select @policy_id
--GO
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_policycheck_extendedproperty] TO [role_policy_check]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_extendedproperty', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-02-25', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_extendedproperty', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-04-29', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_extendedproperty', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.1', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_extendedproperty', NULL, NULL
GO
