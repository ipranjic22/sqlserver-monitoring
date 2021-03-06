/*
	sys.dm_os_ring_buffers

	Not fully documented. Every one minute dm_os_ring_buffers is logging CPU status. Max. 256 rows.

	ProcessUtilization	Percent			Indicates the amount of CPU SQL Server was using at the time of the snapshot.
	SystemIdle			Percent			Amount of Idle CPU that nothing is using. Available for any process that requires CPU.
	OtherUtilization	Percent			100 - ProcessUtilization - System Idle. Used by processes other than SQL Server.
	UserModeTime		Nanoseconds		Indicates the amount of CPU worker thread (Running in user mode) used during the period it did not yield. You need to divide this value by 10,000 to get time in milliseconds
	KernelModeTime		Nanoseconds		Indicates the amount of CPU worker thread (Running in Windows kernel) used during the period it did not yield. You need to divide this value by 10,000 to get time in milliseconds.
	PageFaults			int				Number of page faults at the time of the snapshot. A page fault occurs when a program requests an address on a page that is not in the current set of memory-resident pages.

	CPU is consumed in two different modes: User Mode and Kernel Mode.
	User Mode Time		If “% User Time” is high then there is something consuming the user mode of SQL Server.
	Kernel Mode Time	If you observe  consistent  system time greater than 15%, or the system time cosnsistently is greater than usermodetime, analyse what is running on the Operating System to cause the overutilization.
						The consequence is application (SQL Server ) threads won’t be able to use the CPU .
	Page Faults			A page fault occurs when a program requests an address on a page that is not in the current set of memory resident pages.
						The program is set to a Wait State when a page fault occurs. The OS searches for the address on the disk. When it finds the address it moves it to some free RAM.
						When completed, the program continues its execution.
		
	CPU Cores * 60s = Max. CPU time => UserModeTime(s) / Max. CPU time = ProcessUtilization

	sys.dm_os_sys_info
	https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-sys-info-transact-sql

	Returns a miscellaneous set of useful information about the computer, and about the resources available to and consumed by SQL Server.

	ms_ticks	bigint	Specifies the number of milliseconds since the computer started. Not nullable. ==> //Record/@time)[1] - ms_ticks = Crete date for dm_os_ring_buffers data.

	LINKS:
	https://www.sqlserver-dba.com/2015/10/how-to-understand-the-ring_buffer_schedule_monitor.html
	https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/sql-high-cpu-scenario-troubleshooting-using-sys-dm-exec-query/ba-p/370314
	https://sqlworldwide.com/ring-buffer-monitoring-cpu-what-do-those-values-mean/
	https://mssqlwiki.com/2013/03/29/inside-sys-dm_os_ring_buffers/
	https://www.mssqltips.com/sqlservertip/5724/monitor-cpu-and-memory-usage-for-all-sql-server-instances-using-powershell/
	https://techcommunity.microsoft.com/t5/azure-sql/monitor-cpu-usage-on-sql-server-and-azure-sql/ba-p/680777
	https://docs.microsoft.com/en-us/sql/relational-databases/performance-monitor/monitor-resource-usage-system-monitor?view=sql-server-2017

	SELECT TOP (1)
		CONVERT(XML, record) AS x
	FROM
		sys.dm_os_ring_buffers 
	WHERE
		ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
		
	XML:
	<Record id="27" type="RING_BUFFER_SCHEDULER_MONITOR" time="1141221648">
		<SchedulerMonitorEvent>
		<SystemHealth>
			<ProcessUtilization>0</ProcessUtilization>
			<SystemIdle>99</SystemIdle>
			<UserModeTime>0</UserModeTime>
			<KernelModeTime>0</KernelModeTime>
			<PageFaults>63</PageFaults>
			<WorkingSetDelta>12288</WorkingSetDelta>
			<MemoryUtilization>100</MemoryUtilization>
		</SystemHealth>
		</SchedulerMonitorEvent>
	</Record>
*/

SELECT
	DS.[Timestamp]
,	DATEADD(MILLISECOND, DS.RecordTime - OSINFO.ms_ticks, GETDATE()) AS SnapshotDate
,	DS.ProcessUtilization AS SQLServerProcessUtilization
,	100 - DS.ProcessUtilization - DS.SystemIdle AS SystemProcessUtilization
,	DS.SystemIdle
,	DS.UserModeTime / 10000 AS UserModeTime
,	DS.KernelModeTime / 10000 AS KernelModeTime
FROM
	(
		SELECT
			x.value('(//Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS [ProcessUtilization]
		,	x.value('(//Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS [SystemIdle]
		,	x.value('(//Record/SchedulerMonitorEvent/SystemHealth/UserModeTime)[1]', 'bigint') AS [UserModeTime]
		,	x.value('(//Record/SchedulerMonitorEvent/SystemHealth/KernelModeTime)[1]', 'bigint') AS [KernelModeTime]
		,	x.value('(//Record/@time)[1]', 'bigint') AS [RecordTime]
		,	R.[timestamp]
		FROM
			(
				SELECT
					CONVERT(XML, record) AS x
				,	[Timestamp]
				FROM
					sys.dm_os_ring_buffers
				WHERE
					ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'
			) AS R
	) AS DS
	CROSS JOIN sys.dm_os_sys_info AS OSINFO