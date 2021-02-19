CREATE TABLE [trace].[ActivityLogHistory]
(
[RecordId] [bigint] NOT NULL IDENTITY(1, 1),
[session_id] [smallint] NULL,
[RequestStartTime] [datetime] NOT NULL,
[RequestStatus] [nvarchar] (30) COLLATE Arabic_CI_AS NULL,
[command] [nvarchar] (32) COLLATE Arabic_CI_AS NULL,
[DBname] [nvarchar] (128) COLLATE Arabic_CI_AS NULL,
[wait_resource] [nvarchar] (256) COLLATE Arabic_CI_AS NULL,
[cpu_time_ms] [int] NULL,
[total_elapsed_time] [int] NULL,
[reads_KB] [bigint] NULL,
[writes_KB] [bigint] NULL,
[logical_reads_KB] [bigint] NULL,
[memory_usage_KB] [int] NULL,
[memory_request_time] [datetime] NULL,
[memory_grant_time] [datetime] NULL,
[requested_memory_kb] [bigint] NULL,
[min_required_memory_kb] [bigint] NULL,
[granted_memory_kb] [bigint] NULL,
[used_memory_kb] [bigint] NULL,
[max_used_memory_kb] [bigint] NULL,
[oreder_of_query_in_wait_memory_queue] [int] NULL,
[memory_wait_time_ms] [bigint] NULL,
[use_small_memory] [bit] NULL,
[dop] [smallint] NULL,
[query_cost] [float] NULL,
[login_time] [datetime] NOT NULL,
[host_name] [nvarchar] (128) COLLATE Arabic_CI_AS NULL,
[program_name] [nvarchar] (128) COLLATE Arabic_CI_AS NULL,
[client_interface_name] [nvarchar] (32) COLLATE Arabic_CI_AS NULL,
[login_name] [nvarchar] (128) COLLATE Arabic_CI_AS NOT NULL,
[SessionStatus] [nvarchar] (30) COLLATE Arabic_CI_AS NOT NULL,
[objectid] [int] NULL,
[CurrentSessionStatement] [nvarchar] (max) COLLATE Arabic_CI_AS NULL,
[CurrentRequestStatement] [nvarchar] (max) COLLATE Arabic_CI_AS NULL,
[CurrentRequestSectionStatement] [nvarchar] (max) COLLATE Arabic_CI_AS NULL,
[CurrentRequestPlan] [xml] NULL,
[CurrentRequestSectionPlan] [xml] NULL,
[wait_duration_ms] [bigint] NULL,
[wait_type] [nvarchar] (60) COLLATE Arabic_CI_AS NULL,
[resource_address] [varbinary] (8) NULL,
[blocking_session_id] [smallint] NULL,
[resource_description] [nvarchar] (3072) COLLATE Arabic_CI_AS NULL,
[HeadBlocker] [bit] NULL,
[client_net_address] [nvarchar] (50) COLLATE Arabic_CI_AS NULL,
[LogTime] [datetime] NULL CONSTRAINT [DF_ActivityLogHistory_LogTime] DEFAULT (getdate())
) ON [Data_OLTP]
GO
ALTER TABLE [trace].[ActivityLogHistory] ADD CONSTRAINT [PK__Activity__FBDF78E9BC278F45] PRIMARY KEY CLUSTERED  ([RecordId]) WITH (FILLFACTOR=70, PAD_INDEX=ON) ON [Data_OLTP]
GO
CREATE NONCLUSTERED INDEX [NCIX_RequestStartTime] ON [trace].[ActivityLogHistory] ([RequestStartTime]) WITH (FILLFACTOR=90, PAD_INDEX=ON) ON [Index_All]
GO
GRANT INSERT ON  [trace].[ActivityLogHistory] TO [role_events]
GO
GRANT SELECT ON  [trace].[ActivityLogHistory] TO [role_perfmon]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'trace', 'TABLE', N'ActivityLogHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2017-01-01', 'SCHEMA', N'trace', 'TABLE', N'ActivityLogHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2018-05-26', 'SCHEMA', N'trace', 'TABLE', N'ActivityLogHistory', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.2', 'SCHEMA', N'trace', 'TABLE', N'ActivityLogHistory', NULL, NULL
GO
