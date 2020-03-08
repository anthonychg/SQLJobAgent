SELECT
   --Job Information
   a.job_id
   ,a.name
   ,a.[description]
   --SSIS package Information
   ,b.name
   ,b.id
   ,b.[description]
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
--WHERE CHARINDEX('CIF Refresh',js.command)>0
ORDER BY a.name,
   js.step_id
SELECT TOP 100 * FROM msdb.dbo.sysjobs
SELECT TOP 100 * FROM msdb.dbo.sysjobactivity
SELECT TOP 100 * FROM msdb.dbo.sysjobhistory
---------------------------------------------------------
SELECT TOP 100 * FROM sysjobhistory
SELECT TOP 100 * FROM agent_datetime
GO
----------------------------------------------------------
USE   master -- DLPSSIS01
GO
SELECT
   --Job Information
   j.job_id AS JobId,
   j.name AS JobName,
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
WHERE  jh.run_date = 20200302
AND   jh.run_status = 2
AND   j.[enabled] = 1
--WHERE CHARINDEX('CIF Refresh',js.command)>0
ORDER BY j.name,
   js.step_id
----------------------------------------------------------
USE   master -- DLPSSIS01
GO
IF OBJECT_ID('dbo.uspGetJobStepStatus', 'P') IS NOT NULL
 DROP PROC dbo.uspGetJobStepStatus
GO
CREATE PROC dbo.uspGetJobStepStatus @strJobStatus VARCHAR(25)
AS 
BEGIN
DECLARE  @intJobStatus INT,
   @intCurrDate INT
SET @intCurrDate =  (DATEPART("yy",GETDATE()) * 10000 + DATEPART("mm",GETDATE()) * 100 + DATEPART("dd",GETDATE()))
SET   @intJobStatus =
   CASE
   WHEN  @strJobStatus = 'Failed'
   THEN  0
   WHEN  @strJobStatus = 'Succeeded'
   THEN  1
   WHEN  @strJobStatus = 'Retry'
   THEN  2
   WHEN  @strJobStatus = 'Cancelled'
   THEN  3
   ELSE  -1
   END
SELECT  x.JobInfoStatus
FROM
(
SELECT  ' JobName' + REPLICATE(CHAR(9),2) + 
   'StepId' + REPLICATE(CHAR(9),2) + 
   'StepName' + REPLICATE(CHAR(9),2) +  
   'RunDateTime' + REPLICATE(CHAR(9),2) + 
   'RunDurationMinutes' + REPLICATE(CHAR(9),2) + 
   'JobOutcome' AS JobInfoStatus
UNION ALL
SELECT   
   j.name + REPLICATE(CHAR(9),2) + 
   CAST(js.step_id AS VARCHAR(2)) + REPLICATE(CHAR(9),3) +
   js.step_name + REPLICATE(CHAR(9),3) +   
   CONVERT(VARCHAR, msdb.dbo.agent_datetime(run_date, run_time),120) + REPLICATE(CHAR(9),3) +
   CAST(((jh.run_duration/10000*3600 + (jh.run_duration/100)%100*60 + jh.run_duration%100 + 31 ) / 60) AS VARCHAR(25)) + REPLICATE(CHAR(9),3) +
   (CASE 
   WHEN jh.run_status=0 THEN 'Failed'
            WHEN jh.run_status=1 THEN 'Succeeded'
            WHEN jh.run_status=2 THEN 'Retry'
            WHEN jh.run_status=3 THEN 'Cancelled'
            ELSE 'Unknown'  
   END) AS JobInfoStatus
    
FROM  msdb.dbo.sysjobs  j 
LEFT JOIN msdb.dbo.sysjobsteps js 
ON   js.job_id=j.job_id
LEFT JOIN msdb.dbo.sysssispackages s
ON   j.name=s.name
LEFT JOIN msdb.dbo.sysjobhistory jh
ON   js.job_id = jh.job_id
AND   js.step_id = jh.step_id
WHERE  j.[enabled] = 1
AND   CHARINDEX('PeopleS0ft',j.name)=0
AND   CHARINDEX('PeopleSoft',j.name)=0
AND   jh.run_date = @intCurrDate
AND   jh.run_status = @intJobStatus
) x
ORDER BY x.JobInfoStatus
END
GO
GRANT EXECUTE ON dbo.uspGetJobStepStatus TO PUBLIC
GO 


EXEC uspGetJobStepStatus 'Retry'
EXEC uspGetJobStepStatus 'Failed'

-----------------------------------------------------------------------------------
SELECT DISTINCT run_status
FROM  msdb.dbo.sysjobhistory  
-----------------------------------------------------------------------------------
IF OBJECT_ID('dbo.uspGetJobStatus', 'P') IS NOT NULL
 DROP PROC dbo.uspGetJobStatus
GO
CREATE PROC dbo.uspGetJobStatus @strJobStatus VARCHAR(25)
AS 
BEGIN
DECLARE  @intJobStatus INT,
   @intCurrDate INT
SET @intCurrDate =  (DATEPART("yy",GETDATE()) * 10000 + DATEPART("mm",GETDATE()) * 100 + DATEPART("dd",GETDATE()))
SET   @intJobStatus =
   CASE
   WHEN  @strJobStatus = 'Failed'
   THEN  0
   WHEN  @strJobStatus = 'Succeeded'
   THEN  1
   WHEN  @strJobStatus = 'Retry'
   THEN  2
   WHEN  @strJobStatus = 'Cancelled'
   THEN  3
   ELSE  -1
   END

;WITH CTE_MostRecentJobRun AS  
 (  
 -- For each job get the most recent run (this will be the one where Rnk=1)  
 SELECT  job_id,
   run_status,
   run_date,
   run_time,
   msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',   
   ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60) as 'RunDurationMinutes',
   (CASE 
   WHEN run_status=0 THEN 'Failed'
            WHEN run_status=1 THEN 'Succeeded'
            WHEN run_status=2 THEN 'Retry'
            WHEN run_status=3 THEN 'Cancelled'
            ELSE 'Unknown'  
   END) AS JobInfoStatus,
   RANK() OVER (PARTITION BY job_id ORDER BY run_date DESC,run_time DESC) AS Rnk  
 FROM  msdb.dbo.sysjobhistory
 WHERE  step_id=0  
 )  
SELECT  x.JobInfoStatus
FROM
(
SELECT  ' JobName' + REPLICATE(CHAR(9),2) + 
   'RunDateTime' + REPLICATE(CHAR(9),2) + 
   'RunDurationMinutes' + REPLICATE(CHAR(9),2) + 
   'JobOutcome' AS JobInfoStatus
UNION ALL
SELECT   
   j.name + REPLICATE(CHAR(9),2) +    
   CONVERT(VARCHAR, mrjr.RunDateTime,120) + REPLICATE(CHAR(9),3) +
   CAST(mrjr.RunDurationMinutes AS VARCHAR(25)) + REPLICATE(CHAR(9),3) +      
   mrjr.JobInfoStatus
    
FROM  msdb.dbo.sysjobs  j
INNER JOIN  CTE_MostRecentJobRun mrjr
ON   j.job_id = mrjr.job_id
WHERE  j.[enabled] = 1
AND   CHARINDEX('PeopleS0ft',j.name)=0
AND   CHARINDEX('PeopleSoft',j.name)=0
AND      mrjr.Rnk = 1
AND   mrjr.run_date = @intCurrDate
AND   mrjr.run_status = @intJobStatus
) x
ORDER BY x.JobInfoStatus
END
GO
GRANT EXECUTE ON dbo.uspGetJobStatus TO PUBLIC
GO 
EXEC uspGetJobStatus 'Failed'
--------------------------------------------------------------------------------------------------------------
-- Listing "Problem" Jobs
;WITH CTE_MostRecentJobRun AS  
 (  
 -- For each job get the most recent run (this will be the one where Rnk=1)  
 SELECT job_id,run_status,run_date,run_time  
 ,RANK() OVER (PARTITION BY job_id ORDER BY run_date DESC,run_time DESC) AS Rnk  
 FROM msdb.dbo.sysjobhistory  
 WHERE step_id=0  
 )  
SELECT   
  name  AS [Job Name]
 ,CONVERT(VARCHAR,DATEADD(S,(run_time/10000)*60*60 /* hours */  
  +((run_time - (run_time/10000) * 10000)/100) * 60 /* mins */  
  + (run_time - (run_time/100) * 100)  /* secs */,  
  CONVERT(DATETIME,RTRIM(run_date),113)),100) AS [Time Run] 
 ,CASE WHEN enabled=1 THEN 'Enabled'  
     ELSE 'Disabled'  
  END [Job Status]
FROM     CTE_MostRecentJobRun MRJR  
JOIN     msdb.dbo.sysjobs SJ  
ON       MRJR.job_id=sj.job_id  
WHERE    Rnk=1  
AND      run_status=0 -- i.e. failed  
ORDER BY name  

-- Listing Running Jobs
IF OBJECT_ID('tempdb.dbo.#RunningJobs') IS NOT NULL
      DROP TABLE #RunningJobs
CREATE TABLE #RunningJobs (   
Job_ID UNIQUEIDENTIFIER,   
Last_Run_Date INT,   
Last_Run_Time INT,   
Next_Run_Date INT,   
Next_Run_Time INT,   
Next_Run_Schedule_ID INT,   
Requested_To_Run INT,   
Request_Source INT,   
Request_Source_ID VARCHAR(100),   
Running INT,   
Current_Step INT,   
Current_Retry_Attempt INT,   
State INT )     
      
INSERT INTO #RunningJobs EXEC master.dbo.xp_sqlagent_enum_jobs 1,garbage   
  
SELECT     
  name AS [Job Name]
 ,CASE WHEN next_run_date=0 THEN '[Not scheduled]' ELSE
   CONVERT(VARCHAR,DATEADD(S,(next_run_time/10000)*60*60 /* hours */  
  +((next_run_time - (next_run_time/10000) * 10000)/100) * 60 /* mins */  
  + (next_run_time - (next_run_time/100) * 100)  /* secs */,  
  CONVERT(DATETIME,RTRIM(next_run_date),112)),100) END AS [Start Time]
FROM     #RunningJobs JSR  
JOIN     msdb.dbo.sysjobs  
ON       JSR.Job_ID=sysjobs.job_id  
WHERE    Running=1 -- i.e. still running  
ORDER BY name,next_run_date,next_run_time  
