/*
	dbo.sysjobhistory
	https://docs.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobhistory-transact-sql

	Contains information about the execution of scheduled jobs by SQL Server Agent.

	job_id			Job ID.
	step_id			ID of the step in the job.
	step_name		Name of the step.
	run_status		Status of the job execution:
						0 = Failed
						1 = Succeeded
						2 = Retry
						3 = Canceled
						4 = In Progress.
	run_date		Date the job or step started execution. For an In Progress history, this is the date/time the history was written.
	run_time		Time the job or step started in HHMMSS format.
	run_duration	Elapsed time in the execution of the job or step in HHMMSS format.

	dbo.sysjobs
	https://docs.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobs-transact-sql

	Stores the information for each scheduled job to be executed by SQL Server Agent. This table is stored in the msdb database.

	job_id			Unique ID of the job.
	name			Name of the job.
	category_id		ID of the job category.

	dbo.syscategories
	https://docs.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-syscategories-transact-sql

	Contains the categories used by SQL Server Management Studio to organize jobs, alerts, and operators. This table is stored in the msdb database.

	category_id		ID of the category
	category_class	Type of item in the category:
						1 = Job
						2 = Alert
						3 = Operator
	category_type	Type of category:
						1 = Local
						2 = Multiserver
						3 = None
	name			Name of the category.

	dbo.sysjobsteps
	https://docs.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobsteps-transact-sql

	Contains the information for each step in a job to be executed by SQL Server Agent. This table is stored in the msdb database.

	job_id			ID of the job.
	step_id			ID of the step in the job.
	step_name		Name of the job step.
	subsystem		Name of the subsystem used by SQL Server Agent to execute the job step.
	command			Command to be executed by subsystem.

	catalog.operation_messages (SSISDB Database)
	https://docs.microsoft.com/en-us/sql/integration-services/system-views/catalog-operation-messages-ssisdb-database

	Displays messages that are logged during operations in the Integration Services catalog.

	operation_id	The unique ID of the operation.
	message_type	The type of message displayed:
						-1	Unknown
						120	Error
						110	Warning
						70	Information
						10	Pre-validate
						20	Post-validate
						30	Pre-execute
						40	Post-execute
						60	Progress
						50	StatusChange
						100	QueryCancel
						130	TaskFailed
						90	Diagnostic
						200	Custom
						140	DiagnosticEx.
	message			The text of the message.
*/
	
SELECT
	DS.JobID
,	DS.JobName
,	DS.StepID
,	DS.StepName
,	DS.SubSystem
,	DS.RunStatus
,	DS.RunDate
,	DS.RunTime
,	DS.RunDurationDDHHMMSS
,	DS.ExecutionID
,	DS.JobErrorMessage
,	MSG.[Message] AS SSISErrorMessage
FROM
	(
		SELECT
			HIST.job_id AS JobID
		,	JOB.[name] AS JobName
		,	HIST.step_id AS StepID
		,	HIST.step_name AS StepName
		,	STEP.subsystem AS SubSystem
		,	CASE
				WHEN HIST.run_status = 0 THEN 'Failed'
				WHEN HIST.run_status = 1 THEN 'Succeeded'
				WHEN HIST.run_status = 2 THEN 'Retry'
				WHEN HIST.run_status = 3 THEN 'Canceled'
				WHEN HIST.run_status = 4 THEN 'In Progress'
			END AS RunStatus
		,	CONVERT(DATE, CONVERT(VARCHAR(30), HIST.run_date)) AS RunDate
		,	CONVERT(TIME(0), STUFF(STUFF(RIGHT(REPLICATE('0', 6) + CONVERT(VARCHAR(6), HIST.run_time), 6), 3, 0, ':'), 6, 0, ':'))  AS RunTime
		,	STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + CONVERT(VARCHAR(8), HIST.run_duration), 8), 3, 0, ':'), 6, 0, ':'), 9, 0, ':') AS RunDurationDDHHMMSS
		,	CASE
				WHEN STEP.subsystem = 'SSIS' AND HIST.run_status = 0 AND HIST.[message] LIKE '%Execution ID: %'
				THEN
					SUBSTRING
					(
						HIST.[message]
					,	PATINDEX('%Execution ID: %', HIST.[message]) + 14
					,	PATINDEX('%, Execution Status:%', HIST.[message]) -	(PATINDEX('%Execution ID: %', HIST.[message]) + 14)
					)
				ELSE
					NULL
			END AS ExecutionID
		,	CASE
				WHEN HIST.run_status = 0 THEN HIST.[message]
				ELSE NULL
			END AS JobErrorMessage
		FROM
			msdb.dbo.sysjobs AS JOB
			INNER JOIN msdb.dbo.syscategories AS CTG
				ON CTG.category_id = JOB.category_id
			INNER JOIN msdb.dbo.sysjobhistory AS HIST
				ON HIST.job_id = JOB.job_id
			LEFT JOIN msdb.dbo.sysjobsteps AS STEP
				ON STEP.job_id = HIST.job_id
				AND STEP.step_id = HIST.step_id
		WHERE
			/* Remove jobs like CDC */
			CTG.category_id NOT BETWEEN 10 AND 19
	) AS DS
	LEFT JOIN SSISDB.[catalog].operation_messages as MSG
		ON MSG.operation_id = DS.ExecutionID
		AND MSG.message_type = 120 /* Error */