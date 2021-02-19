CREATE TABLE [dbo].[dbmetrics]
(
[min_snap_id] [int] NULL,
[max_snap_id] [int] NULL,
[min_begin_time] [date] NULL,
[max_end_time] [date] NULL,
[metric_id] [int] NULL,
[metric_name] [varchar] (3072) COLLATE Arabic_CI_AS NULL,
[min_minval] [float] NULL,
[max_maxval] [float] NULL,
[avg_average] [float] NULL,
[metric_unit] [varchar] (1024) COLLATE Arabic_CI_AS NULL,
[in_work_time] [int] NOT NULL CONSTRAINT [DF_dbmetrics_in_work_time] DEFAULT ((2))
) ON [Data_OLTP]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'TABLE', N'dbmetrics', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2014-02-15', 'SCHEMA', N'dbo', 'TABLE', N'dbmetrics', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'TABLE', N'dbmetrics', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'TABLE', N'dbmetrics', NULL, NULL
GO
