
<#

.SYNOPSIS

this script creates, runs and deletes scheduled task on remote computer and gets exit code back


.NOTES

Script must be executed with an account that has the adminstrator privileges on both local and remote computers
No need to elevate process on local machine
Scheduled task can't execute things from network if system account is used


.EXAMPLE

Windows PowerShell
Copyright (C) 2016 Microsoft Corporation. All rights reserved.

PS C:\Users\POKEDEX> .\Scripts\Invoke-ScheduledTask.ps1 -ComputerName SALAMESH -Sid S-1-5-18 -TaskName Test -Path C:\Test\Test.vbs
Task Test finished with return code 0 on SALAMESH
PS C:\Users\POKEDEX>

#>



Param (

    [Parameter(Mandatory = $false)]
    [String] $ComputerName = "localhost",

    [Parameter(Mandatory = $true)]
    [ValidateSet("S-1-5-18", "S-1-5-32-544", "S-1-5-32-545")]
    [String] $Sid,

    [Parameter(Mandatory = $true)]
    [String] $TaskName,

    [Parameter(Mandatory = $true)]
    [String] $Path,

    [Parameter(Mandatory = $false)]
    [String] $Arguments = [String]::Empty

)



Function Is-Online() {


    Param(

        [Parameter(Mandatory = $true)]
        [String] $ComputerName
   
    )

    Try {
     
        [Bool] $Result = Test-Connection -ComputerName $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue

        Return $Result

    } Catch {

        Return $false

    }

}



if (Is-Online -ComputerName $ComputerName) {


    Try {


        [Hashtable] $Id = @{
        
            SYSTEM = "S-1-5-18"
            ADMINISTRATORS = "S-1-5-32-544"
            USERS = "S-1-5-32-545"

        }


        [Hashtable] $LogonType = @{

            TASK_LOGON_INTERACTIVE_TOKEN = 3
            TASK_LOGON_GROUP = 4

        }


        [Hashtable] $RunLevel = @{

            TASK_RUNLEVEL_LUA = 0
            TASK_RUNLEVEL_HIGHEST = 1

        }


        [Hashtable] $TaskCreation = @{
        
            TASK_CREATE = 2
            TASK_UPDATE = 4
            TASK_CREATE_OR_UPDATE = 6

        }


        [Hashtable] $TaskState = @{

            Ready = 3
            Running = 4

        }


        [Int] $TaskLogon = $LogonType.TASK_LOGON_INTERACTIVE_TOKEN

        if ($Sid -eq $Id.SYSTEM) {

          $TaskLogon = $LogonType.TASK_LOGON_GROUP
    
        }


        [__ComObject] $Service = New-Object -ComObject ("Schedule.Service")

        [Void] $Service.Connect($ComputerName)


        [__ComObject] $TaskFolder = $Service.GetFolder("\")


        [__ComObject] $TaskDefinition = $Service.NewTask(0) 

        $TaskDefinition.RegistrationInfo.Description = [String]::Empty

        $TaskDefinition.Principal.GroupId = $Sid

        $TaskDefinition.Principal.LogonType = $TaskLogon

        $TaskDefinition.Principal.RunLevel = $RunLevel.TASK_RUNLEVEL_HIGHEST

        $TaskDefinition.Settings.Enabled = $true

        $TaskDefinition.Settings.AllowDemandStart = $true

        $TaskDefinition.Settings.Hidden = $false

        $TaskDefinition.Settings.DisallowStartIfOnBatteries = $false


        [__ComObject] $Action = $TaskDefinition.Actions.Create(0)

        $Action.Path = $Path

        $Action.Arguments = $Arguments


        [Void] $TaskFolder.RegisterTaskDefinition($TaskName, $TaskDefinition, $TaskCreation.TASK_CREATE_OR_UPDATE, $null, $null, $TaskDefinition.Principal.LogonType)


        [__ComObject] $Task = $TaskFolder.GetTask($TaskName)

        [Void] $Task.Run($null)


        While ($Task.State -eq $TaskState.Ready) {

            Sleep -Seconds 1

        }

        While ($Task.State -eq $TaskState.Running) {

            Sleep -Seconds 1

        }


        [Int] $ExitCode = $Task.LastTaskResult

        $TaskFolder.DeleteTask($TaskName, 0)

        Write-Host "Task $TaskName finished with return code $ExitCode on $ComputerName"

        #Return $ExitCode


    } Catch {


        Write-Host "$($_.Exception.GetType())`n$($_.Exception.Message)" -ForegroundColor Red

        #Return $_.Exception.HResult


    } Finally {


        foreach ($ComObject in @($Task, $TaskDefinition, $TaskFolder, $Service)) {

            if ($null -ne $ComObject) {

                [Void] [Runtime.Interopservices.Marshal]::ReleaseComObject($ComObject)

            }

        }

        [GC]::Collect()

    }


} else {

    Write-Host "$ComputerName is not online" -ForegroundColor Yellow

}

