/*	sys.dm_db_partition_stats
	https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-partition-stats-transact-sql
		
	Returns page and row-count information for every partition in the current database.

	partition_id					bigint		ID of the partition. This is unique within a database. This is the same value as the partition_id in the sys.partitions catalog view.
	object_id						int			Object ID of the table or indexed view that the partition is part of.
	index_id						int			ID of the heap or index the partition is part of. 0 = Heap, 1 = Clustered index, > 1 = Nonclustered index.
	partition_number				int			1-based partition number within the index or heap.
	in_row_data_page_count			bigint		Number of pages in use for storing in-row data in this partition.
												If the partition is part of a heap, the value is the number of data pages in the heap.
												If the partition is part of an index, the value is the number of pages in the leaf level.
												(Nonleaf pages in the B-tree are not included in the count.) IAM (Index Allocation Map) pages are not included in either case.
												Always 0 for an xVelocity memory optimized columnstore index. Always 0 for a columnstore index.
	lob_used_page_count				bigint		Number of pages in use for storing and managing out-of-row text, ntext, image, varchar(max), nvarchar(max), varbinary(max)
												and xml columns within the partition. IAM pages are included.
												Total number of LOBs used to store and manage columnstore index in the partition.
	row_overflow_used_page_count	bigint		Number of pages in use for storing and managing row-overflow varchar, nvarchar, varbinary, and sql_variant columns within the partition.
												IAM pages are included. Always 0 for a columnstore index.
	used_page_count					bigint		Total number of pages used for the partition. Computed as in_row_used_page_count + lob_used_page_count + row_overflow_used_page_count.
	reserved_page_count				bigint		Total number of pages reserved for the partition.
												Computed as in_row_reserved_page_count + lob_reserved_page_count + row_overflow_reserved_page_count.
	row_count						bigint		The approximate number of rows in the partition.
*/

SELECT
	SCH.[name] AS SchemaName
,	OBJ.[name] AS TableName
,	SCH.[schema_id] AS sysSchemaID
,	OBJ.[object_id] AS sysObjectID
,	SPS.TotalRows
,	SPS.TotalReserved * 8 AS TotalReservedKB
,	SPS.[Data] * 8 AS DataKB
,	(CASE WHEN SPS.Used > SPS.[Data] THEN SPS.Used - SPS.[Data] ELSE 0 END) * 8 AS IndexKB
,	(CASE WHEN SPS.TotalReserved > SPS.Used THEN SPS.TotalReserved - SPS.Used ELSE 0 END) * 8 AS UnusedKB
FROM
	(
		SELECT
			PS.[object_id]
		,	SUM(CASE WHEN PS.index_id < 2 THEN row_count ELSE 0 END) AS TotalRows
		,	SUM(PS.reserved_page_count) AS TotalReserved
		,	SUM
			(
				CASE
					WHEN PS.index_id < 2 THEN PS.in_row_data_page_count + PS.lob_used_page_count + PS.row_overflow_used_page_count
					ELSE PS.lob_used_page_count + PS.row_overflow_used_page_count
				END
			) AS [Data]
		,	SUM(PS.used_page_count) AS Used
		FROM
			sys.dm_db_partition_stats AS PS
		WHERE
			PS.[object_id] NOT IN (SELECT [object_id] FROM sys.tables WHERE is_memory_optimized = 1)
		GROUP BY
			PS.[object_id]
	) AS SPS
	INNER JOIN sys.all_objects AS OBJ
		ON OBJ.[object_id] = SPS.[object_id]
	INNER JOIN sys.schemas AS SCH
		ON SCH.[schema_id] = OBJ.[schema_id]
WHERE
	OBJ.[type] IN ('U')
	AND OBJ.[name] NOT IN ('sysdiagrams', '__RefactorLog')
	AND OBJ.is_ms_shipped = 0
	AND SCH.[name] <> 'cdc'