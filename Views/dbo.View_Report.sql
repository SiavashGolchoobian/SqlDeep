SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [dbo].[View_Report]
AS
SELECT --TOP (100) PERCENT
		myCounters.CounterID,
		myCounters.ObjectName,
		myCounters.CounterName,
		[myCounters].[InstanceName],
		ISNULL(myCounters.ObjectName,N'') + '->' + ISNULL(myCounters.CounterName,N'')  + '->' + ISNULL([myCounters].[InstanceName],N'') AS IndexName,
		myData.RecordIndex,
		myData.CounterValue,
		CONVERT(DATETIME,LEFT(myData.CounterDateTime, 19), 120) AS CounterDateTime,
		CAST(CONVERT(DATETIME,LEFT(myData.CounterDateTime, 19), 120) AS DATE) AS CounterDate,
		CAST(CONVERT(DATETIME,LEFT(myData.CounterDateTime, 19), 120) AS TIME(0)) AS CounterTime
FROM	dbo.CounterDetails AS myCounters WITH(READPAST)
		INNER JOIN dbo.CounterData AS myData WITH(READPAST) ON myCounters.CounterID = myData.CounterID
--ORDER BY myCounters.CounterID, myCounters.ObjectName, myCounters.CounterName, CounterDateTime
GO
GRANT SELECT ON  [dbo].[View_Report] TO [role_kpi_select]
GO
EXEC sp_addextendedproperty N'Author', N'Siavash Golchoobian', 'SCHEMA', N'dbo', 'VIEW', N'View_Report', NULL, NULL
GO
EXEC sp_addextendedproperty N'Created Date', N'2013-12-15', 'SCHEMA', N'dbo', 'VIEW', N'View_Report', NULL, NULL
GO
EXEC sp_addextendedproperty N'Modified Date', N'2017-03-08', 'SCHEMA', N'dbo', 'VIEW', N'View_Report', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_DiagramPane1', N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = -96
      End
      Begin Tables = 
         Begin Table = "myCounters"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 178
               Right = 227
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "myData"
            Begin Extent = 
               Top = 13
               Left = 401
               Bottom = 166
               Right = 565
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 4635
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 2520
         Alias = 2040
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', 'SCHEMA', N'dbo', 'VIEW', N'View_Report', NULL, NULL
GO
DECLARE @xp int
SELECT @xp=1
EXEC sp_addextendedproperty N'MS_DiagramPaneCount', @xp, 'SCHEMA', N'dbo', 'VIEW', N'View_Report', NULL, NULL
GO
EXEC sp_addextendedproperty N'Version', N'3.0.0.0', 'SCHEMA', N'dbo', 'VIEW', N'View_Report', NULL, NULL
GO
