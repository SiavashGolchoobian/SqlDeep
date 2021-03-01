Declare @condition_id int
EXEC msdb.dbo.sp_syspolicy_add_condition @name=N'SqlDeep_DataFileSizingCondition', @description=N'All data files Max size property should set to less than 80GB anf Auto Growth mode should be in KB', @facet=N'DataFile', @expression=N'<Operator>
  <TypeClass>Bool</TypeClass>
  <OpType>AND</OpType>
  <Count>2</Count>
  <Operator>
    <TypeClass>Bool</TypeClass>
    <OpType>AND</OpType>
    <Count>2</Count>
    <Operator>
      <TypeClass>Bool</TypeClass>
      <OpType>NE</OpType>
      <Count>2</Count>
      <Attribute>
        <TypeClass>Numeric</TypeClass>
        <Name>MaxSize</Name>
      </Attribute>
      <Constant>
        <TypeClass>Numeric</TypeClass>
        <ObjType>System.Double</ObjType>
        <Value>-1</Value>
      </Constant>
    </Operator>
    <Operator>
      <TypeClass>Bool</TypeClass>
      <OpType>LE</OpType>
      <Count>2</Count>
      <Attribute>
        <TypeClass>Numeric</TypeClass>
        <Name>MaxSize</Name>
      </Attribute>
      <Constant>
        <TypeClass>Numeric</TypeClass>
        <ObjType>System.Double</ObjType>
        <Value>83886080</Value>
      </Constant>
    </Operator>
  </Operator>
  <Operator>
    <TypeClass>Bool</TypeClass>
    <OpType>NE</OpType>
    <Count>2</Count>
    <Attribute>
      <TypeClass>Numeric</TypeClass>
      <Name>GrowthType</Name>
    </Attribute>
    <Function>
      <TypeClass>Numeric</TypeClass>
      <FunctionType>Enum</FunctionType>
      <ReturnType>Numeric</ReturnType>
      <Count>2</Count>
      <Constant>
        <TypeClass>String</TypeClass>
        <ObjType>System.String</ObjType>
        <Value>Microsoft.SqlServer.Management.Smo.FileGrowthType</Value>
      </Constant>
      <Constant>
        <TypeClass>String</TypeClass>
        <ObjType>System.String</ObjType>
        <Value>Percent</Value>
      </Constant>
    </Function>
  </Operator>
</Operator>', @is_name_condition=0, @obj_name=N'', @condition_id=@condition_id OUTPUT
Select @condition_id

GO

