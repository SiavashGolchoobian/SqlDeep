SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Golchoobian>
-- Create date: <4/29/2018>
-- Version:		<3.0.0.0>
-- Description:	<Check for same file size in each filegroup>
-- Input Parameters:
--	@DatabaseName:	nvarchar
-- =============================================
CREATE PROC [dbo].[dbasp_policycheck_samefilesize] (@DatabaseID int)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @myNewLine nvarchar(10);
	DECLARE @mySQLScript nvarchar(MAX);
	DECLARE @Parameters nvarchar(255);
	DECLARE @Result int;

	SET @myNewLine=CHAR(13)+CHAR(10)
	SET @mySQLScript=CAST(N'' AS NVARCHAR(MAX))
	SET @mySQLScript=@mySQLScript+
		CAST(
		@myNewLine + N'SELECT '+
		@myNewLine + N'	@Result=COUNT(*)'+
		@myNewLine + N'FROM'+
		@myNewLine + N'	('+
		@myNewLine + N'		SELECT'+
		@myNewLine + N'			[data_space_id],'+
		@myNewLine + N'			MIN([size]) AS MinSize,'+
		@myNewLine + N'			MAX([size]) AS MaxSize'+
		@myNewLine + N'		FROM'+
		@myNewLine + N'			[' + CAST(DB_NAME(@DatabaseID) AS NVARCHAR(MAX)) + N'].sys.[database_files]'+
		@myNewLine + N'		WHERE'+
		@myNewLine + N'			[type] NOT IN (1,2)		--Log and Filestream filegroup'+
		@myNewLine + N'		GROUP BY'+
		@myNewLine + N'			[data_space_id]'+
		@myNewLine + N'		HAVING'+
		@myNewLine + N'			MIN([size]) <> MAX([size])'+
		@myNewLine + N'	) AS myUnequalFileSize'
		AS NVARCHAR(MAX))

	SET @Parameters = N'@Result int OUTPUT'
	Execute sp_executesql @mySQLScript, @Parameters, @Result OUTPUT
	Select @Result

------========================================Create Condition
--DECLARE @condition_id int
--EXEC msdb.dbo.sp_syspolicy_add_condition @name=N'DBA_CheckSameFileSizeCondition', @description=N'Same Filegroup does not have same file size', @facet=N'Database', @expression=N'<Operator>
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
--        <Value>[DBA].[dbo].[dbasp_policycheck_samefilesize] </Value>
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
--    <Value>0</Value>
--  </Constant>
--</Operator>', @is_name_condition=0, @obj_name=N'', @condition_id=@condition_id OUTPUT
--Select @condition_id
--GO

------========================================Create Plocy
--Declare @object_set_id int
--EXEC msdb.dbo.sp_syspolicy_add_object_set @object_set_name=N'DBA_CheckSameFileSize_ObjectSet', @facet=N'Database', @object_set_id=@object_set_id OUTPUT
--Select @object_set_id

--Declare @target_set_id int
--EXEC msdb.dbo.sp_syspolicy_add_target_set @object_set_name=N'DBA_CheckSameFileSize_ObjectSet', @type_skeleton=N'Server/Database', @type=N'DATABASE', @enabled=True, @target_set_id=@target_set_id OUTPUT
--Select @target_set_id

--EXEC msdb.dbo.sp_syspolicy_add_target_set_level @target_set_id=@target_set_id, @type_skeleton=N'Server/Database', @level_name=N'Database', @condition_name=N'', @target_set_level_id=0
--GO

--Declare @policy_id int
--EXEC msdb.dbo.sp_syspolicy_add_policy @name=N'DBA_CheckSameFileSize', @condition_name=N'DBA_CheckSameFileSizeCondition', @policy_category=N'SmartAdmin warnings', @description=N'Check for same File size in same filegroups', @help_text=N'Set Equal file size for files in same filegroup', @help_link=N'', @schedule_uid=N'00000000-0000-0000-0000-000000000000', @execution_mode=0, @is_enabled=False, @policy_id=@policy_id OUTPUT, @root_condition_name=N'', @object_set=N'DBA_CheckSameFileSize_ObjectSet'
--Select @policy_id
--GO
END
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_samefilesize', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2018-04-29', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_samefilesize', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-04-29', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_samefilesize', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_policycheck_samefilesize', NULL, NULL
GO
