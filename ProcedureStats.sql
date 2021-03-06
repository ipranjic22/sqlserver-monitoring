/*
	sys.dm_exec_procedure_stats
	https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-procedure-stats-transact-sql

	Returns aggregate performance statistics for cached stored procedures. The view returns one row for each cached stored procedure plan
	and the lifetime of the row is as long as the stored procedure remains cached. When a stored procedure is removed from the cache, the corresponding row is eliminated from this view.

	plan_handle				varbinary(64)	Identifier for the in-memory plan. This identifier is transient and remains constant only while the plan remains in the cache.
											This value may be used with the sys.dm_exec_cached_plans dynamic management view.
											Will always be 0x000 when a natively compiled stored procedure queries a memory-optimized table.

	execution_count			bigint			The number of times that the stored procedure has been executed since it was last compiled.
	total_worker_time		bigint			The total amount of CPU time, in microseconds, that was consumed by executions of this stored procedure since it was compiled.
											For natively compiled stored procedures, total_worker_time may not be accurate if many executions take less than 1 millisecond.
	total_physical_reads	bigint			The total number of physical reads performed by executions of this stored procedure since it was compiled.
											Will always be 0 querying a memory-optimized table.
	total_logical_writes	bigint			The total number of logical writes performed by executions of this stored procedure since it was compiled.
											Will always be 0 querying a memory-optimized table.
	total_logical_reads		bigint			The total number of logical reads performed by executions of this stored procedure since it was compiled.
											Will always be 0 querying a memory-optimized table.
	total_elapsed_time		bigint			The total elapsed time, in microseconds, for completed executions of this stored procedure.

	sys.dm_exec_query_plan
	https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-plan-transact-sql

	Returns the Showplan in XML format for the batch specified by the plan handle. The plan specified by the plan handle can either be cached or currently executing.

	query_plan	xml		Contains the compile-time Showplan representation of the query execution plan that is specified with plan_handle.
						The Showplan is in XML format. One plan is generated for each batch that contains, for example ad hoc Transact-SQL statements, stored procedure calls, and user-defined function calls.
						Column is nullable.
*/

SELECT
	sysSP.[name] AS [Procedure]
,	DMV.execution_count
,	DMV.total_worker_time
,	DMV.total_physical_reads
,	DMV.total_logical_writes
,	DMV.total_logical_reads
,	DMV.total_elapsed_time
,	DMV.total_elapsed_time / DMV.execution_count AS avg_elapsed_time
,	DMV.plan_handle
,	QPLAN.query_plan AS QueryPlanXML
FROM
	sys.schemas AS sysSCH
	INNER JOIN sys.procedures AS sysSP
		ON sysSP.[schema_id] = sysSCH.[schema_id]
	INNER JOIN sys.dm_exec_procedure_stats AS DMV
		ON DMV.[object_id] = sysSP.[object_id]
		AND DMV.database_id = DB_ID()
	CROSS APPLY sys.dm_exec_query_plan(DMV.plan_handle) AS QPLAN