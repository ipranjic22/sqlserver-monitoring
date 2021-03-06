/*
	sys.master_files
	https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-master-files-transact-sql

	Contains a row per file of a database as stored in the master database. This is a single, system-wide view.

	file_id			int				ID of the file within database. The primary file_id is always 1.
	type_desc		nvarchar(60)	Description of the file type: ROWS, LOG, FILESTREAM, FULLTEXT (Full-text catalogs earlier than SQL Server 2008.)
	name			sysname			Logical name of the file in the database.
	physical_name	nvarchar(260)	Operating-system file name.
	size			int				Current file size, in 8-KB pages. For a database snapshot, size reflects the maximum space that the snapshot can ever use for the file.
									Note: This field is populated as zero for FILESTREAM containers. Query the sys.database_files catalog view for the actual size of FILESTREAM containers.
*/

SELECT
	DB.[name] AS [Database]
,	MF.[file_id] AS sysFileID
,	MF.[type_desc] AS [Type]
,	MF.[name] AS LogicalName
,	MF.physical_name AS PhysicalName
,	MF.size * 8 / 1024 AS SizeMB
,	CONVERT(DECIMAL(10,2), CONVERT(DECIMAL(10,2), MF.size) * 8 / 1024 / 1024) AS SizeGB
FROM
	sys.master_files AS MF
	INNER JOIN sys.databases AS DB
		ON DB.database_id = MF.database_id