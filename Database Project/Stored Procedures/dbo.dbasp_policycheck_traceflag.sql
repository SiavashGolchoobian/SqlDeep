SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <1/26/2015>
-- Version:		<3.0.0.0>
-- Description:	<Check for enabaling of @TraceFlagNumber trace flag number in global scope, if traceflag existed return 1>
-- Input Parameters:
--	@TraceFlagNumber:	int	//TraceFlagNumber
-- =============================================
CREATE PROC [dbo].[dbasp_policycheck_traceflag] (@TraceFlagNumber int)
AS
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tbl_TraceFlags (
		[TraceFlag] INT NULL
		,[TraceFlagStatus] BIT NULL
		,[Global] INT NULL
		,[session] INT NULL)

	INSERT INTO #tbl_TraceFlags (TraceFlag, TraceFlagStatus, [global], [session]) EXEC ('dbcc tracestatus(-1) with NO_INFOMSGS')
	SELECT COUNT(*) as Existed FROM #tbl_TraceFlags WHERE TraceFlag=@TraceFlagNumber and Global=1
	DROP TABLE #tbl_TraceFlags

------========================================Create Condition
--Declare @condition_id int
--EXEC msdb.dbo.sp_syspolicy_add_condition @name=N'DBA_CheckTraceFlagsCondition', @description=N'Standard Trace Flags does not set correctly', @facet=N'Server', @expression=N'<Operator>
--  <TypeClass>Bool</TypeClass>
--  <OpType>AND</OpType>
--  <Count>2</Count>
--  <Operator>
--    <TypeClass>Bool</TypeClass>
--    <OpType>AND</OpType>
--    <Count>2</Count>
--    <Operator>
--      <TypeClass>Bool</TypeClass>
--      <OpType>AND</OpType>
--      <Count>2</Count>
--      <Operator>
--        <TypeClass>Bool</TypeClass>
--        <OpType>AND</OpType>
--        <Count>2</Count>
--        <Operator>
--          <TypeClass>Bool</TypeClass>
--          <OpType>AND</OpType>
--          <Count>2</Count>
--          <Operator>
--            <TypeClass>Bool</TypeClass>
--            <OpType>EQ</OpType>
--            <Count>2</Count>
--            <Function>
--              <TypeClass>Numeric</TypeClass>
--              <FunctionType>ExecuteSql</FunctionType>
--              <ReturnType>Numeric</ReturnType>
--              <Count>2</Count>
--              <Constant>
--                <TypeClass>String</TypeClass>
--                <ObjType>System.String</ObjType>
--                <Value>Numeric</Value>
--              </Constant>
--              <Constant>
--                <TypeClass>String</TypeClass>
--                <ObjType>System.String</ObjType>
--                <Value>EXECUTE [SqlDeep].[dbo].[dbasp_policycheck_traceflag] 1117</Value>
--              </Constant>
--            </Function>
--            <Constant>
--              <TypeClass>Numeric</TypeClass>
--              <ObjType>System.Double</ObjType>
--              <Value>1</Value>
--            </Constant>
--          </Operator>
--          <Operator>
--            <TypeClass>Bool</TypeClass>
--            <OpType>EQ</OpType>
--            <Count>2</Count>
--            <Function>
--              <TypeClass>Numeric</TypeClass>
--              <FunctionType>ExecuteSql</FunctionType>
--              <ReturnType>Numeric</ReturnType>
--              <Count>2</Count>
--              <Constant>
--                <TypeClass>String</TypeClass>
--                <ObjType>System.String</ObjType>
--                <Value>Numeric</Value>
--              </Constant>
--              <Constant>
--                <TypeClass>String</TypeClass>
--                <ObjType>System.String</ObjType>
--                <Value>EXECUTE [SqlDeep].[dbo].[dbasp_policycheck_traceflag] 1118</Value>
--              </Constant>
--            </Function>
--            <Constant>
--              <TypeClass>Numeric</TypeClass>
--              <ObjType>System.Double</ObjType>
--              <Value>1</Value>
--            </Constant>
--          </Operator>
--        </Operator>
--        <Operator>
--          <TypeClass>Bool</TypeClass>
--          <OpType>EQ</OpType>
--          <Count>2</Count>
--          <Function>
--            <TypeClass>Numeric</TypeClass>
--            <FunctionType>ExecuteSql</FunctionType>
--            <ReturnType>Numeric</ReturnType>
--            <Count>2</Count>
--            <Constant>
--              <TypeClass>String</TypeClass>
--              <ObjType>System.String</ObjType>
--              <Value>Numeric</Value>
--            </Constant>
--            <Constant>
--              <TypeClass>String</TypeClass>
--              <ObjType>System.String</ObjType>
--              <Value>EXECUTE [SqlDeep].[dbo].[dbasp_policycheck_traceflag] 2371</Value>
--            </Constant>
--          </Function>
--          <Constant>
--            <TypeClass>Numeric</TypeClass>
--            <ObjType>System.Double</ObjType>
--            <Value>1</Value>
--          </Constant>
--        </Operator>
--      </Operator>
--      <Operator>
--        <TypeClass>Bool</TypeClass>
--        <OpType>EQ</OpType>
--        <Count>2</Count>
--        <Function>
--          <TypeClass>Numeric</TypeClass>
--          <FunctionType>ExecuteSql</FunctionType>
--          <ReturnType>Numeric</ReturnType>
--          <Count>2</Count>
--          <Constant>
--            <TypeClass>String</TypeClass>
--            <ObjType>System.String</ObjType>
--            <Value>Numeric</Value>
--          </Constant>
--          <Constant>
--            <TypeClass>String</TypeClass>
--            <ObjType>System.String</ObjType>
--            <Value>EXECUTE [SqlDeep].[dbo].[dbasp_policycheck_traceflag] 2549</Value>
--          </Constant>
--        </Function>
--        <Constant>
--          <TypeClass>Numeric</TypeClass>
--          <ObjType>System.Double</ObjType>
--          <Value>1</Value>
--        </Constant>
--      </Operator>
--    </Operator>
--    <Operator>
--      <TypeClass>Bool</TypeClass>
--      <OpType>EQ</OpType>
--      <Count>2</Count>
--      <Function>
--        <TypeClass>Numeric</TypeClass>
--        <FunctionType>ExecuteSql</FunctionType>
--        <ReturnType>Numeric</ReturnType>
--        <Count>2</Count>
--        <Constant>
--          <TypeClass>String</TypeClass>
--          <ObjType>System.String</ObjType>
--          <Value>Numeric</Value>
--        </Constant>
--        <Constant>
--          <TypeClass>String</TypeClass>
--          <ObjType>System.String</ObjType>
--          <Value>EXECUTE [SqlDeep].[dbo].[dbasp_policycheck_traceflag] 2562</Value>
--        </Constant>
--      </Function>
--      <Constant>
--        <TypeClass>Numeric</TypeClass>
--        <ObjType>System.Double</ObjType>
--        <Value>1</Value>
--      </Constant>
--    </Operator>
--  </Operator>
--  <Operator>
--    <TypeClass>Bool</TypeClass>
--    <OpType>EQ</OpType>
--    <Count>2</Count>
--    <Function>
--      <TypeClass>Numeric</TypeClass>
--      <FunctionType>ExecuteSql</FunctionType>
--      <ReturnType>Numeric</ReturnType>
--      <Count>2</Count>
--      <Constant>
--        <TypeClass>String</TypeClass>
--        <ObjType>System.String</ObjType>
--        <Value>Numeric</Value>
--      </Constant>
--      <Constant>
--        <TypeClass>String</TypeClass>
--        <ObjType>System.String</ObjType>
--        <Value>EXECUTE [SqlDeep].[dbo].[dbasp_policycheck_traceflag] 4199</Value>
--      </Constant>
--    </Function>
--    <Constant>
--      <TypeClass>Numeric</TypeClass>
--      <ObjType>System.Double</ObjType>
--      <Value>1</Value>
--    </Constant>
--  </Operator>
--</Operator>', @is_name_condition=0, @obj_name=N'', @condition_id=@condition_id OUTPUT
--Select @condition_id
--GO

------========================================Create Plocy
--Declare @object_set_id int
--EXEC msdb.dbo.sp_syspolicy_add_object_set @object_set_name=N'DBA_CheckTraceFlags_ObjectSet', @facet=N'Server', @object_set_id=@object_set_id OUTPUT
--Select @object_set_id

--Declare @target_set_id int
--EXEC msdb.dbo.sp_syspolicy_add_target_set @object_set_name=N'DBA_CheckTraceFlags_ObjectSet', @type_skeleton=N'Server', @type=N'SERVER', @enabled=True, @target_set_id=@target_set_id OUTPUT
--Select @target_set_id
--GO

--Declare @policy_id int
--EXEC msdb.dbo.sp_syspolicy_add_policy @name=N'DBA_CheckTraceFlags', @condition_name=N'DBA_CheckTraceFlagsCondition', @policy_category=N'SmartAdmin warnings', @description=N'Check Standard Tarce Flags Existence', @help_text=N'Set Standard Trace Flags (1118,2371,2549,2562,4199)', @help_link=N'', @schedule_uid=N'00000000-0000-0000-0000-000000000000', @execution_mode=0, @is_enabled=False, @policy_id=@policy_id OUTPUT, @root_condition_name=N'', @object_set=N'DBA_CheckTraceFlags_ObjectSet'
--Select @policy_id
--GO
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_policycheck_traceflag] TO [role_policy_check]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_traceflag', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2015-01-26', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_traceflag', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-04-29', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_traceflag', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.1', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_traceflag', NULL, NULL
GO
