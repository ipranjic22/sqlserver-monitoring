/*
	SQL Server blocked access to procedure 'sys.xp_cmdshell' of component 'xp_cmdshell' because this component is turned off as part of the security configuration for this server. 
	A system administrator can enable the use of 'xp_cmdshell' by using sp_configure. For more information about enabling 'xp_cmdshell'.

	-- To allow advanced options to be changed.  
	EXECUTE sp_configure 'show advanced options', 1;  
	GO  
	-- To update the currently configured value for advanced options.  
	RECONFIGURE;  
	GO  
	-- To enable the feature.  
	EXECUTE sp_configure 'xp_cmdshell', 1;  
	GO  
	-- To update the currently configured value for this feature.  
	RECONFIGURE;  
	GO

*/

IF OBJECT_ID('tempdb..#logicaldisk') IS NOT NULL DROP TABLE #logicaldisk;

CREATE TABLE #logicaldisk
(
	line	VARCHAR(255)
)

INSERT #logicaldisk
EXECUTE xp_cmdshell 'wmic logicaldisk get name,freespace,size,volumename'

;WITH GetPoints AS
(
	SELECT
		CHARINDEX('FreeSpace', line) AS [1]
	,	CHARINDEX('Name', line) AS [2]
	,	CHARINDEX('Size', line) AS [3]
	,	CHARINDEX('VolumeName', line) AS [4]
	,	LEN(line) AS [5]
	FROM
		#logicaldisk
	WHERE
		line LIKE 'FreeSpace%'
)
, DataSet AS
(
	SELECT
		CONVERT(BIGINT, RTRIM(LTRIM(SUBSTRING(DS.line, GP.[1], GP.[2] - GP.[1])))) AS FreeSpace
	,					RTRIM(LTRIM(SUBSTRING(DS.line, GP.[2], GP.[3] - GP.[2]))) AS [Disk]
	,	CONVERT(BIGINT, RTRIM(LTRIM(SUBSTRING(DS.line, GP.[3], GP.[4] - GP.[3])))) AS Size
	,	NULLIF('',		RTRIM(LTRIM(SUBSTRING(DS.line, GP.[4], GP.[5] - GP.[4])))) AS VolumeName
	FROM
		#logicaldisk AS DS
		CROSS APPLY GetPoints AS GP
	WHERE
		line LIKE '%:%'
)
SELECT
	[Disk]
,	VolumeName
,	CONVERT(DECIMAL(8,2), Size / 1073741824.00) AS SizeGB
,	CONVERT(DECIMAL(8,2), Size / 1073741824.00) - CONVERT(DECIMAL(8,2), FreeSpace / 1073741824.00) AS UsedSpaceGB
,	CONVERT(DECIMAL(8,2), FreeSpace / 1073741824.00) AS FreeSpaceGB
,	CONVERT(DECIMAL(5,2), CONVERT(DECIMAL(8,2), FreeSpace / 1073741824.00) / CONVERT(DECIMAL(8,2), Size / 1073741824.00) * 100) AS FreeSpacePercent
FROM
	DataSet
WHERE
	VolumeName IS NOT NULL