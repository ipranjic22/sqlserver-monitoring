/*	
	sys.dm_db_index_usage_stats
	https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-usage-stats-transact-sql

	Every individual seek, scan, lookup, or update on the specified index by one query execution is counted as a use of that index and increments the corresponding counter in this view.
	Information is reported both for operations caused by user-submitted queries, and for operations caused by internally generated queries, such as scans for gathering statistics.
		
	The user_updates counter indicates the level of maintenance on the index caused by insert, update, or delete operations on the underlying table or view. 
	You can use this view to determine which indexes are used only lightly by your applications. You can also use the view to determine which indexes are incurring maintenance overhead.
	You may want to consider dropping indexes that incur maintenance overhead, but are not used for queries, or are only infrequently used for queries.
		
	The counters are initialized to empty whenever the SQL Server (MSSQLSERVER) service is started.
	In addition, whenever a database is detached or is shut down (for example, because AUTO_CLOSE is set to ON), all rows associated with the database are removed.
	When an index is used, a row is added to sys.dm_db_index_usage_stats if a row does not already exist for the index. When the row is added, its counters are initially set to zero.
				
	database_id		smallint	ID of the database on which the table or view is defined.
	object_id		int			ID of the table or view on which the index is defined
	index_id		int			ID of the index.
	user_seeks		bigint		Number of seeks by user queries.
	user_scans		bigint		Number of scans by user queries that did not use 'seek' predicate.
	user_lookups	bigint		Number of bookmark lookups by user queries.
	user_updates	bigint		Number of updates by user queries. This includes Insert, Delete, and Updates representing number of operations done not the actual rows affected. 
								For example, if you delete 1000 rows in one statement, this count increments by 1.

	sys.dm_db_index_physical_stats
	https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-physical-stats-transact-sql

	Returns size and fragmentation information for the data and indexes of the specified table or view in SQL Server.
	For an index, one row is returned for each level of the B-tree in each partition. For a heap, one row is returned for the IN_ROW_DATA allocation unit of each partition. 
	For large object (LOB) data, one row is returned for the LOB_DATA allocation unit of each partition. 
	If row-overflow data exists in the table, one row is returned for the ROW_OVERFLOW_DATA allocation unit in each partition. 
	Does not return information about xVelocity memory optimized columnstore indexes.

	Important!!!
	If you query sys.dm_db_index_physical_stats on a server instance that is hosting an Always On readable secondary replica, 
	you might encounter a REDO blocking issue. This is because this dynamic management view acquires an IS lock on the specified user table 
	or view that can block requests by a REDO thread for an X lock on that user table or view.

	database_id						smallint		Database ID of the table or view.
	object_id						int				Object ID of the table or view that the index is on.
	index_id						int				Index ID of an index. 0 = Heap.
	partition_number				int				1-based partition number within the owning object; a table, view, or index. 1 = Nonpartitioned index or heap.
	index_type_desc					nvarchar(60)	Description of the index type: HEAP, CLUSTERED INDEX, NONCLUSTERED INDEX, PRIMARY, XML INDEX, EXTENDED INDEX,
													XML INDEX, COLUMNSTORE MAPPING INDEX (internal), COLUMNSTORE DELETEBUFFER INDEX (internal),
													COLUMNSTORE DELETEBITMAP INDEX (internal).
	index_depth						tinyint			Number of index levels. 1 = Heap, or LOB_DATA or ROW_OVERFLOW_DATA allocation unit.
	avg_fragmentation_in_percent	float			Logical fragmentation for indexes, or extent fragmentation for heaps in the IN_ROW_DATA allocation unit.
													The value is measured as a percentage and takes into account multiple files. For definitions of logical and extent fragmentation.
													0 for LOB_DATA and ROW_OVERFLOW_DATA allocation units. NULL for heaps when mode = SAMPLED.
	page_count						bigint			Total number of index or data pages.
													For an index, the total number of index pages in the current level of the b-tree in the IN_ROW_DATA allocation unit.
													For a heap, the total number of data pages in the IN_ROW_DATA allocation unit.
													For LOB_DATA or ROW_OVERFLOW_DATA allocation units, total number of pages in the allocation unit.
*/

IF OBJECT_ID('tempdb..#IndexUsageStats') IS NOT NULL DROP TABLE #IndexUsageStats;
IF OBJECT_ID('tempdb..#Index_physical_stats') IS NOT NULL DROP TABLE #Index_physical_stats;

SELECT
	IUS.database_id
,	IUS.[object_id]
,	IUS.index_id
,	IUS.user_seeks
,	IUS.user_scans
,	IUS.user_lookups
,	IUS.user_updates
INTO
	#IndexUsageStats
FROM
	sys.dm_db_index_usage_stats AS IUS
WHERE
	IUS.database_id = DB_ID()

SELECT 
	[object_id]
,	index_id
,	index_depth AS Index_depth
,	case when page_count < 500 then 0 ELSE avg_fragmentation_in_percent END AS avg_fragmentation_in_percent
,	page_count AS page_count
,	partition_number AS Partition_number
,	database_id
INTO
	#Index_physical_stats
FROM
	sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, 'LIMITED')
	
SELECT
	QUOTENAME(SCH.[name]) + '.' + QUOTENAME(OBJ.[name]) AS ObjectName
,	QUOTENAME(IND.[name]) AS IndexName
,	IPS.database_id AS DatabaseID
,	OBJ.[object_id] AS sysObjectID
,	SCH.[schema_id] AS sysSchemaID
,	IND.index_id AS sysIndexID
,	IPS.Partition_number AS PartitionNumber
,	IND.[type_desc] AS IndexType
,	IND.is_primary_key AS IsPrimaryKey
,	IND.is_unique_constraint AS IsUniqueConstraint
,	IND.is_unique AS IsUnique
,	IPS.Index_depth AS IndexDepth
,	CONVERT(DECIMAL(5,2), IPS.avg_fragmentation_in_percent) AS AVGFragmentationInPercent
,	IPS.page_count AS [PageCount]
,	ISNULL(IUS.user_seeks, 0) AS UserSeek
,	ISNULL(IUS.user_scans, 0) AS UserScans
,	ISNULL(IUS.user_lookups, 0) AS UserLookups
,	ISNULL(IUS.user_updates, 0) AS UserUpdates
,	PART.TableRows
,	PART.TotalSpaceKB
,	PART.UsedSpaceKB
,	PART.TotalSpaceKB - PART.UsedSpaceKB as UnusedSpaceKB
FROM
	#Index_physical_stats AS IPS
	INNER JOIN sys.indexes AS IND
		ON IND.index_id = IPS.index_id
		AND IND.[object_id] = IPS.[object_id]
	INNER JOIN sys.objects AS OBJ
		ON OBJ.[object_id] = IND.[object_id]
	INNER JOIN sys.schemas AS SCH
		ON SCH.[schema_id] = OBJ.[schema_id]
	INNER JOIN 
	(
		SELECT
			PART.[object_id]
		,	PART.index_id
		,	PART.partition_number
		,	SUM(PART.[rows]) AS TableRows
		,	SUM(ALUN.total_pages) * 8 AS TotalSpaceKB
		,	SUM(ALUN.used_pages) * 8 AS UsedSpaceKB
		FROM 
			sys.partitions AS PART
			INNER JOIN sys.allocation_units AS ALUN 
				ON ALUN.container_id = PART.[partition_id]
		GROUP BY
			PART.object_id
		,	PART.index_id
		,	PART.partition_number
	) AS PART
		ON PART.[object_id] = IPS.[object_id]
		AND PART.index_id = IPS.index_id 
		AND PART.partition_number = IPS.Partition_number
	LEFT JOIN #IndexUsageStats AS IUS
		ON IUS.database_id = IPS.database_id
		AND IUS.[object_id] = IPS.[object_id]
		AND IUS.index_id = IPS.index_id
WHERE
	OBJ.[type] = 'U'
	AND OBJ.[name] NOT IN ('sysdiagrams', '__RefactorLog')
	AND OBJ.is_ms_shipped = 0
	AND SCH.[name] NOT IN ('cdc')