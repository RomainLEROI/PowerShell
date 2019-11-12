
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



Function Is-Online {


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
        
            System = "S-1-5-18"
            Administrators = "S-1-5-32-544"
            Users = "S-1-5-32-545"

        }


        [Hashtable] $LogonType = @{

            TaskLogonInteractiveToken = 3
            TaskLogonGroup = 4

        }


        [Hashtable] $RunLevel = @{

            TaskRunLevelLUA = 0
            TaskRunLevelHighest = 1

        }


        [Hashtable] $TaskCreation = @{
        
            TaskCreate = 2
            TaskUpdate = 4
            TaskCreateOrUpdate = 6

        }


        [Hashtable] $TaskState = @{

            Ready = 3
            Running = 4

        }


        [__ComObject] $Service = New-Object -ComObject ("Schedule.Service")

        [Void] $Service.Connect($ComputerName)


        [__ComObject] $TaskFolder = $Service.GetFolder("\")


        [__ComObject] $TaskDefinition = $Service.NewTask(0) 

        $TaskDefinition.RegistrationInfo.Description = [String]::Empty

        $TaskDefinition.Principal.GroupId = $Sid

        if ($Sid -eq $Id.System) {

            $TaskDefinition.Principal.LogonType = $LogonType.TaskLogonGroup

        } else {

            $TaskDefinition.Principal.LogonType = $LogonType.TaskLogonInteractiveToken

        }

        if ($Sid -eq $Id.Users) {

            $TaskDefinition.Principal.RunLevel = $RunLevel.TaskRunLevelLUA

        } else {

            $TaskDefinition.Principal.RunLevel = $RunLevel.TaskRunLevelHighest

        }

        $TaskDefinition.Settings.Enabled = $true

        $TaskDefinition.Settings.AllowDemandStart = $true

        $TaskDefinition.Settings.Hidden = $false

        $TaskDefinition.Settings.DisallowStartIfOnBatteries = $false


        [__ComObject] $Action = $TaskDefinition.Actions.Create(0)

        $Action.Path = $Path

        $Action.Arguments = $Arguments


        [Void] $TaskFolder.RegisterTaskDefinition($TaskName, $TaskDefinition, $TaskCreation.TaskCreateOrUpdate, $null, $null, $TaskDefinition.Principal.LogonType)


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

        Write-Output -InputObject "Task $TaskName finished with return code $ExitCode on $ComputerName"


    } Catch {


        Write-Output -InputObject "$($_.Exception.GetType())`n$($_.Exception.Message)"


    } Finally {


        foreach ($ComObject in @($Task, $TaskDefinition, $TaskFolder, $Service)) {

            if ($null -ne $ComObject) {

                [Void] [Runtime.Interopservices.Marshal]::ReleaseComObject($ComObject)

            }

        }

        [GC]::Collect()

    }


} else {


    Write-Output -InputObject "$ComputerName is not online"
 
}
