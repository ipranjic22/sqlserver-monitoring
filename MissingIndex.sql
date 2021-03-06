/*	
	Important!!!
	The result set for this DMV is limited to 600 rows. Each row contains one missing index.
	If you have more than 600 missing indexes, you should address the existing missing indexes so you can then view the newer ones.
	Missing index information is kept only until SQL Server is restarted.
		
	Equality columns should be put before the inequality columns, and together they should make the key of the index.
	Included columns should be added to the CREATE INDEX statement using the INCLUDE clause.
	To determine an effective order for the equality columns, order them based on their selectivity: list the most selective columns first (leftmost in the column list).

	sys.dm_db_missing_index_details
	https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-details-transact-sql

	Returns detailed information about missing indexes, excluding spatial indexes.
	index_handle		int				Identifies a particular missing index. The identifier is unique across the server. index_handle is the key of this table.
	database_id			smallint		Identifies the database where the table with the missing index resides.
	object_id			int				Identifies the table where the index is missing.
	equality_columns	nvarchar(4000)	Comma-separated list of columns that contribute to equality predicates of the form: table.column =constant_value
	inequality_columns	nvarchar(4000)	Comma-separated list of columns that contribute to inequality predicates, for example, predicates of the form: table.column > constant_value
										Any comparison operator other than "=" expresses inequality.
	included_columns	nvarchar(4000)	Comma-separated list of columns needed as covering columns for the query.
	
	sys.dm_db_missing_index_groups
	https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-groups-transact-sql

	This DMV returns information about indexes that are missing in a specific index group, except for spatial indexes.
	index_group_handle	int		Identifies a missing index group.
	index_handle		int		Identifies a missing index that belongs to the group specified by index_group_handle. An index group contains only one index.

	sys.dm_db_missing_index_group_stats
	https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-group-stats-transact-sql

	Returns summary information about groups of missing indexes, excluding spatial indexes.
	group_handle			int		Identifies a group of missing indexes. This identifier is unique across the server.
									The other columns provide information about all queries for which the index in the group is considered missing. An index group contains only one index.
	unique_compiles			bigint	Number of compilations and recompilations that would benefit from this missing index group.
									Compilations and recompilations of many different queries can contribute to this column value.
	user_seeks				bigint	Number of seeks caused by user queries that the recommended index in the group could have been used for.
	user_scans				bigint	Number of scans caused by user queries that the recommended index in the group could have been used for.
	avg_total_user_cost		float	Average cost of the user queries that could be reduced by the index in the group.
	avg_user_impact			float	Average percentage benefit that user queries could experience if this missing index group was implemented.
									The value means that the query cost would on average drop by this percentage if this missing index group was implemented.
*/

SELECT
	MID.database_id AS DatabaseID
,	OBJ.[object_id] AS sysObjectID
,	SCH.[schema_id] AS sysSchemaID
,	QUOTENAME(SCH.[name]) + '.' + QUOTENAME(OBJ.[name]) AS ObjectName
,	MID.equality_columns
,	MID.inequality_columns
,	MID.included_columns
,	MIGS.unique_compiles
,	MIGS.user_seeks
,	MIGS.user_scans
,	CONVERT(DECIMAL(10,2), MIGS.avg_total_user_cost) AS avg_total_user_cost
,	MIGS.avg_user_impact
,	CONVERT(DECIMAL(20,2), (MIGS.user_seeks + MIGS.user_scans + MIGS.unique_compiles) * MIGS.avg_total_user_cost * (MIGS.avg_user_impact / 100.0)) AS AnticipatedImprovement
,	'CREATE NONCLUSTERED INDEX ' + REPLACE(STUFF(COALESCE(MID.equality_columns, MID.inequality_columns), 2, 0, 'IX_'), '], [', '_')
	+ ' ON ' + QUOTENAME(SCH.[name]) + '.' + QUOTENAME(OBJ.[name])
	+ ' (' + COALESCE(MID.equality_columns,'') + CASE WHEN MID.equality_columns IS NOT NULL AND MID.inequality_columns IS NOT NULL THEN ',' ELSE '' END + COALESCE(MID.inequality_columns, '')
	+ ') ' + COALESCE('INCLUDE (' + MID.included_columns + ')', '') AS CreateScript
FROM
	sys.dm_db_missing_index_details AS MID
	INNER JOIN sys.dm_db_missing_index_groups AS MIG
		ON MIG.index_handle = MID.index_handle
	INNER JOIN sys.dm_db_missing_index_group_stats AS MIGS
		ON MIGS.group_handle = MIG.index_group_handle
	INNER JOIN sys.objects AS OBJ
		ON OBJ.[object_id] = MID.[object_id]
	INNER JOIN sys.schemas AS SCH
		ON SCH.[schema_id] = OBJ.[schema_id]
WHERE
	MID.database_id = DB_ID()
	AND SCH.[name] NOT IN ('cdc')