USE msdb
GO
CREATE VIEW dbo.vSQLJobSteps AS 
SELECT
   --Job Information
   a.job_id
   ,a.name AS SQLJobName
   ,a.[description] AS SQLJobDesc
   --SSIS package Information
   ,b.name AS SSISPackageName
   ,b.id
   ,b.[description] AS SSISPackageDesc
   --Job steps Information
   ,js.step_id
   ,js.step_name
   ,js.subsystem
   ,js.command
FROM  msdb.dbo.sysjobs  a 
LEFT JOIN msdb.dbo.sysjobsteps js 
ON   js.job_id=a.job_id
LEFT JOIN msdb.dbo.sysssispackages b
ON   a.name=b.name
GO
--ORDER BY a.name,
--js.step_id
-------------------------------------------------------------------------
USE msdb
GO
CREATE VIEW dbo.vSQLJobStepsHistory AS 
SELECT
   --Job Information
   j.job_id AS JobId,
   j.name AS SQLJobName,
   --j.[description],
   --SSIS package Information
   --s.name,
   --s.id,
   --s.[description],
   --Job steps Information
   js.step_id AS StepId,
   js.step_name AS StepName,
   js.subsystem AS SubSystem,
   js.command AS Command,
   --jh.run_date,
   --jh.run_time,
   CAST(CONVERT(VARCHAR(10),msdb.dbo.agent_datetime(run_date, run_time),112) AS DATETIME) AS RunDate,
   msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',
   --jh.run_duration,
   ((jh.run_duration/10000*3600 + (jh.run_duration/100)%100*60 + jh.run_duration%100 + 31 ) / 60) 
    as 'RunDurationMinutes',
   --jh.run_status,
   jh.[message] AS [Message],
   jh.[server] AS [Server],
   CASE 
   WHEN j.[enabled]=1 THEN 'Enabled'  
   ELSE 'Disabled'  
   END [JobStatus],
   CASE 
   WHEN jh.run_status=0 THEN 'Failed'
            WHEN jh.run_status=1 THEN 'Succeeded'
            WHEN jh.run_status=2 THEN 'Retry'
            WHEN jh.run_status=3 THEN 'Cancelled'
            ELSE 'Unknown'  
   END 
    AS [JobOutcome]
FROM  msdb.dbo.sysjobs  j 
LEFT JOIN msdb.dbo.sysjobsteps js 
ON   js.job_id=j.job_id
LEFT JOIN msdb.dbo.sysssispackages s
ON   j.name=s.name
LEFT JOIN msdb.dbo.sysjobhistory jh
ON   js.job_id = jh.job_id
AND   js.step_id = jh.step_id
WHERE  CAST(CONVERT(VARCHAR(10),msdb.dbo.agent_datetime(run_date, run_time),112) AS DATETIME) = CAST(CONVERT(VARCHAR(10),GETDATE(),112) AS DATETIME)
GO
--ORDER BY j.name,
--   js.step_id