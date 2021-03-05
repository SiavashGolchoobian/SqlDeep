Declare @condition_id int
EXEC msdb.dbo.sp_syspolicy_add_condition @name=N'SqlDeep_CheckSameFileSizeCondition', @description=N'Same Filegroup does not have same file size', @facet=N'Database', @expression=N'<Operator>
  <TypeClass>Bool</TypeClass>
  <OpType>EQ</OpType>
  <Count>2</Count>
  <Function>
    <TypeClass>Numeric</TypeClass>
    <FunctionType>ExecuteSql</FunctionType>
    <ReturnType>Numeric</ReturnType>
    <Count>2</Count>
    <Constant>
      <TypeClass>String</TypeClass>
      <ObjType>System.String</ObjType>
      <Value>Numeric</Value>
    </Constant>
    <Function>
      <TypeClass>String</TypeClass>
      <FunctionType>Concatenate</FunctionType>
      <ReturnType>String</ReturnType>
      <Count>2</Count>
      <Constant>
        <TypeClass>String</TypeClass>
        <ObjType>System.String</ObjType>
        <Value>[SqlDeep].[dbo].[dbasp_policycheck_samefilesize] </Value>
      </Constant>
      <Function>
        <TypeClass>String</TypeClass>
        <FunctionType>String</FunctionType>
        <ReturnType>String</ReturnType>
        <Count>1</Count>
        <Attribute>
          <TypeClass>Numeric</TypeClass>
          <Name>ID</Name>
        </Attribute>
      </Function>
    </Function>
  </Function>
  <Constant>
    <TypeClass>Numeric</TypeClass>
    <ObjType>System.Double</ObjType>
    <Value>0</Value>
  </Constant>
</Operator>', @is_name_condition=0, @obj_name=N'', @condition_id=@condition_id OUTPUT
Select @condition_id

GO

