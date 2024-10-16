--Stop Telemetry Extended Event
ALTER EVENT SESSION [telemetry_xevents] ON SERVER STATE = STOP;
GO
ALTER EVENT SESSION [telemetry_xevents] ON SERVER WITH (STARTUP_STATE=OFF);
GO
