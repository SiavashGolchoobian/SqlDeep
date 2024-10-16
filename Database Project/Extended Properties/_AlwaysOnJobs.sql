EXEC sp_addextendedproperty N'_AlwaysOnJobs', N' <jobs>
   <job name="JobName01" enabled_on_primary="1" enabled_on_secondary="0" />
   <job name="JobName02" enabled_on_primary="1" enabled_on_secondary="0" />
   <job name="JobName03" enabled_on_primary="1" enabled_on_secondary="0" />
 </jobs>', NULL, NULL, NULL, NULL, NULL, NULL
GO
