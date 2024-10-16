# Getting started on SqlDeep tool

SqlDeep is a SQL Server database with some optional pre-defined agent jobs, alerts, extended events and policies (known as assets). Installing SqlDeep means deploying the database and corresponding optional assets. It's database must be installed on each SQL Server instance, but it's jobs can be installed on MSX server for central maintenace or it can be installed on each server independently.



You can install SqlDeep in several ways.

- Restore https://github.com/SiavashGolchoobian/SqlDeep/releases[latest SqlDeep database backup] (This backup file is created under SQL Server 2019) and run our optional pre-defined maintenace task scripts manually (named "Maintenance.Tasks.zip").

- Install it's https://github.com/SiavashGolchoobian/SqlDeep/releases[Data Application Tire Packages (DacPac)] and run our optional pre-defined maintenace task scripts manually (named "Maintenance.Tasks.zip").

- Create new empty database named as "SqlDeep" and deploying all database objects by comparing SqlDeep github repository with your new empty database by https://www.red-gate.com/products/sql-development/sql-compare[Redgate SQL Compare] softeware and finally run our optional pre-defined maintenace task scripts manually (named "Maintenance.Tasks.zip").

- Or create new empty database named "SqlDeep" and deploying all https://github.com/SiavashGolchoobian/SqlDeep.git[github scripts] manually and finally run our optional pre-defined maintenace task scripts manually (named "Maintenance.Tasks.zip").
