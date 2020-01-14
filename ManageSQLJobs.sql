-----------------------------------------------------------------------
-- Managing SQL Jobs
-----------------------------------------------------------------------
USE	MSDB
GO
SELECT	a.job_id,
	a.name, 
	a.[enabled],
	b.schedule_id, 
	c.name, 
	c.[enabled] AS enabled_job,
	c.freq_type,
	c.freq_interval,
	c.active_start_time

FROM	sysjobs a
LEFT JOIN	sysjobschedules b
ON	a.job_id = b.job_id
LEFT JOIN	sysschedules c
ON	b.schedule_id = c.schedule_id
WHERE a.name NOT IN
(
'ODS_WB & ODS_Banking',
'SD_Staging &DW_Master_Part_00',
'CRM_UCID_Integration',
'DW_Master_Part_01',
'RedFrogMonthlyRefresh',
'CRMReferralsLoad',
'FTP_IWB_UAT',
'ODS_SigXP & DW_dfactCustCounts', 
'PeopleSoft_FI',
'TopNotchTest'
)
AND c.active_start_time IS NOT NULL
AND	a.[enabled] = 1
ORDER BY	freq_type,
			active_start_time

--WHERE	a.name IN ('ODS_SigXP & DW_dfactCustCounts', 'ODS_WB & ODS_Banking')
--


SELECT TOP 100 *
FROM		sysschedules


--------------------------------------------------------------------
-- SQL Job Steps
--------------------------------------------------------------------

USE		MSDB
GO
Select sJob.Name As Job_Name
  ,sJob.Description
  --,sJob.Originating_Server
  ,sJob.Start_Step_ID As Start_At_Step
  ,Case
     When sJob.Enabled = 1
       Then 'Enabled'
     When sJob.Enabled = 0
       Then 'Not Enabled'
     Else 'Unknown Status'
   End As Job_Status
  ,Replace(Replace(sCat.Name,'[',''),']','') As Category
  ,sJStp.Step_ID As Step_No
  ,sJStp.step_name AS StepName
  ,Case sJStp.SubSystem
     When 'ActiveScripting'
       Then 'ActiveX Script'
     When 'CmdExec'
       Then 'Operating system (CmdExec)'
     When 'PowerShell'
       Then 'PowerShell'
     When 'Distribution'
       Then 'Replication Distributor'
     When 'Merge'
       Then 'Replication Merge'
     When 'QueueReader'
       Then 'Replication Queue Reader'
     When 'Snapshot'
       Then 'Replication Snapshot'
     When 'LogReader'
       Then 'Replication Transaction-Log Reader'
     When 'ANALYSISCOMMAND'
       Then 'SQL Server Analysis Services Command'
     When 'ANALYSISQUERY'
       Then 'SQL Server Analysis Services Query'
     When 'SSIS'
       Then 'SQL Server Integration Services Package'
     When 'TSQL'
       Then 'Transact-SQL script (T-SQL)'
     Else sJStp.SubSystem
   End As Step_Type
  ,sJStp.database_name AS Database_Name
  ,sJStp.command AS ExecutableCommand
  ,Case sJStp.on_success_action
     When 1
       Then 'Quit the job reporting success'
     When 2
       Then 'Quit the job reporting failure'
     When 3
       Then 'Go to the next step'
     When 4
       Then 'Go to Step: '
         + QuoteName(Cast(sJStp.On_Success_Step_ID As Varchar(3)))
         + ' '
         + sOSSTP.Step_Name
   End As On_Success_Action
  ,sJStp.retry_attempts AS RetryAttempts
  ,sJStp.retry_interval AS RetryInterval_Minutes
  ,Case sJStp.on_fail_action
     When 1
       Then 'Quit the job reporting success'
     When 2
       Then 'Quit the job reporting failure'
     When 3
       Then 'Go to the next step'
     When 4
       Then 'Go to Step: '
         + QuoteName(Cast(sJStp.On_Fail_Step_ID As Varchar(3)))
         + ' '
         + sOFSTP.step_name
   End As On_Failure_Action
  ,GetDate() As Date_List_Generated
From MSDB.dbo.SysJobSteps As sJStp
  Inner Join MSDB.dbo.SysJobs As sJob
    On sJStp.Job_ID = sJob.Job_ID
  Left Join MSDB.dbo.SysJobSteps As sOSSTP
    On sJStp.Job_ID = sOSSTP.Job_ID
      And sJStp.On_Success_Step_ID = sOSSTP.Step_ID
  Left Join MSDB.dbo.SysJobSteps As sOFSTP
    On sJStp.Job_ID = sOFSTP.Job_ID
      And sJStp.On_Fail_Step_ID = sOFSTP.Step_ID
  Inner Join MSDB..SysCategories sCat
    On sJob.Category_ID = sCat.Category_ID
WHERE CHARINDEX('RunFTP', sJStp.command) > 0
--
--WHERE	sJob.Enabled = 1
--AND		CHARINDEX('PeopleSoft', sJob.Name) = 0
--AND		CHARINDEX('EI', sJob.Name) = 0
Order By Job_Status
  ,Job_Name;

-------------------------------------------------------------------------
-- SQL Job Connection String
-------------------------------------------------------------------------

USE		SSISDB
GO
SELECT	DISTINCT name
FROM		internal.packages
WHERE		name LIKE 'WB%'

--select * from dbo.sysssispackages

select  prj.name                 as 'ProjectName',
        op.object_name          as 'SSISPackageName',
        op.parameter_name       as 'ParamaterName',
		/*
		CASE
		WHEN	CHARINDEX('Email', op.parameter_name) > 0
		THEN	'notificationrecipient@firstwestcu.ca'
		ELSE	op.design_default_value
		END
		*/
		op.design_default_value	as 'ConnectionString'
from    catalog.object_parameters op
        join catalog.projects prj
            on op.project_id = prj.project_id
where   --op.parameter_name like '%ConnectionString%'
        --and 
		op.object_name in  --('WBFullDiffLogRefresh.dtsx')
		(
			SELECT	DISTINCT name
			FROM		internal.packages
		)
AND		prj.name = 'SSIS'
AND		CHARINDEX('Original', prj.name) = 0
AND		CHARINDEX('password', op.parameter_name) = 0
--AND		op.design_default_value LIKE '\\%'
ORDER BY	prj.name,
			op.[object_name]
------------------------------------------------------------------------
USE		master
GO


declare @MyJobTable table 
(
JobName nvarchar(255)
,StepName nvarchar(255)
,StepID int
,SSIDName nvarchar(255)
,StepCommand nvarchar(1024)
)

declare @MyCursor as cursor
declare @MyName as nvarchar(255)

set @MyCursor = CURSOR for select name from msdb.dbo.sysssispackages

open @mycursor
fetch next from @MyCursor into @MyName

while @@FETCH_STATUS = 0
begin 

insert into @MyJobTable
(JobName,StepName,StepID,SSIDName,StepCommand)
(select
jobs.name as JobName
,steps.step_name as StepName
,steps.step_id as StepID
,@MyName as SSIDName
,steps.command as StepCommand
from msdb.dbo.sysjobs as jobs
join msdb.dbo.sysjobsteps as steps
on jobs.job_id = steps.job_id)
--where steps.subsystem = 'SSIS'
--and steps.command like '%'+@MyName+'%')
fetch next from @MyCursor into @MyName

end

select * from @MyJobTable
order by JobName,StepID        

-------------------------
-- Use this
------------------------
USE		msdb
GO

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

FROM		msdb.dbo.sysjobs  a 
LEFT JOIN	msdb.dbo.sysjobsteps js 
ON			js.job_id=a.job_id 
LEFT JOIN	msdb.dbo.sysssispackages b
ON			a.name=b.name
--WHERE CHARINDEX('CIF Refresh',js.command)>0
ORDER BY	a.name,
			js.step_id

--------------

SELECT [sJSTP].[step_id], Name, sJSTP.Command FROM [msdb].[dbo].[sysjobs] [sJOB]
  LEFT JOIN [msdb].[dbo].[sysjobsteps] AS [sJSTP]
    ON [sJOB].[job_id] = [sJSTP].[job_id]
    AND [sJOB].[start_step_id] = [sJSTP].[step_id]
WHERE		Name = 'BlackLine - Import Central1 and WB Files'
ORDER BY Name, step_id