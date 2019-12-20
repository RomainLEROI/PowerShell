
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


$IsLocalHost = if (($ComputerName -eq $env:COMPUTERNAME) -or ($ComputerName -eq 'localhost') -or ($ComputerName -eq '.') -or (((Get-NetIPAddress).IPAddress).Contains($ComputerName))) { Write-Output $true } else { Write-Output $false }

if ($IsLocalHost) {

    $IsOnline = $true

} else {

    $IsOnline = Try { Write-Output (Test-Connection -ComputerName $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue) } Catch { Write-Output $false }

}

if ($IsOnline) {

    Try {

        $Id = @{
        
            System = "S-1-5-18"
            Administrators = "S-1-5-32-544"
            Users = "S-1-5-32-545"

        }

        $LogonType = @{

            TaskLogonInteractiveToken = 3
            TaskLogonGroup = 4

        }

        $RunLevel = @{

            TaskRunLevelLUA = 0
            TaskRunLevelHighest = 1

        }

        $TaskCreation = @{
        
            TaskCreate = 2
            TaskUpdate = 4
            TaskCreateOrUpdate = 6

        }

        $TaskState = @{

            Ready = 3
            Running = 4

        }

        $Service = New-Object -ComObject ("Schedule.Service")

        [Void] $Service.Connect($ComputerName)

        $TaskFolder = $Service.GetFolder("\")

        $TaskDefinition = $Service.NewTask(0) 

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

        $Action = $TaskDefinition.Actions.Create(0)

        $Action.Path = $Path

        $Action.Arguments = $Arguments

        [Void] $TaskFolder.RegisterTaskDefinition($TaskName, $TaskDefinition, $TaskCreation.TaskCreateOrUpdate, $null, $null, $TaskDefinition.Principal.LogonType)

        $Task = $TaskFolder.GetTask($TaskName)

        [Void] $Task.Run($null)


        While ($Task.State -eq $TaskState.Ready) {

            Sleep -Seconds 1

        }

        While ($Task.State -eq $TaskState.Running) {

            Sleep -Seconds 1

        }

        $Result = New-Object –TypeName PSObject –Prop @{
        
            Name = $Task.Name
            LastTaskResult = $Task.LastTaskResult
            LastRunTime = $Task.LastRunTime
            Xml = $Task.Xml
        }

        $TaskFolder.DeleteTask($TaskName, 0)

        Return $Result

    } Catch {

        Write-Error -Message "$($_.Exception.GetType())`n$($_.Exception.Message)"

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
