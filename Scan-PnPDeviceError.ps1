<#
Input.csv
ComputerName;Model
#>


$InputContent = Import-Csv -Path (Join-Path -Path $PsScriptRoot -ChildPath "Input.csv") -Delimiter ";"

$OutputContent = Join-Path -Path $PsScriptRoot -ChildPath "Output.csv"

foreach ($csv in $OutputContents) {

    if (Test-Path -Path "$PsScriptRoot\$csv") {

        Remove-Item -Path "$PsScriptRoot\$csv" -Force

    }

}


$Count = ($InputContent | Measure-Object).Count

$Done = 0

[Data.DataTable] $DataTable = [Data.DataTable]::new("PnpErrorCount")
[Void] $DataTable.columns.add("Name", [String])
[Void] $DataTable.columns.add("Model", [String])
[Void] $DataTable.columns.add("Status", [String])
[Void] $DataTable.columns.add("PnpErrorCount", [String])
[Void] $DataTable.columns.add("DeviceName", [String])
[Void] $DataTable.columns.add("DeviceID", [String])
[Void] $DataTable.columns.add("DeviceSatus", [String])


$NamesFilter = @(

    "Microsoft PS/2 Mouse"
    "Standard PS/2 Keyboard"
    "PS/2 Compatible Mouse"

)

$IDsFilter = @()

                 
foreach ($Obj in $InputContent) {

    $IsOnline = Try { Write-Output (Test-Connection -ComputerName $Obj.ComputerName -Count 1 -Quiet -ErrorAction SilentlyContinue) } Catch { Write-Output $false }

    if ($IsOnline) {

        Try {

            $FaultyDevices = Get-WmiObject -ComputerName $Obj.ComputerName -ClassName Win32_PNPEntity -ErrorAction SilentlyContinue | Where-Object { ($_.Status -ne "OK") -and !($_.Name -in $NamesFilter) -and !($_.PNPDeviceID -in $IDsFilter) } | Select-Object Name, PNPDeviceID, Status

            $PnpErrorCount = (($FaultyDevices | Measure-Object).Count).ToString()

        } Catch {

            $FaultyDevices = $null

            $PnpErrorCount = "Unknown"
           
        }
    
        if (($FaultyDevices | Measure-Object).Count -gt 0) {

            foreach ($FaultDevice in $FaultyDevices) {

                if ([String]::IsNullOrEmpty($FaultDevice.Name)) {

                    $DeviceName = "Unknown Device"

                } else {

                    $DeviceName = $FaultDevice.Name

                }

                $Row = $DataTable.NewRow()

                $Row.Name = $Obj.ComputerName
                $Row.Model = $Obj.Model
                $Row.Status = "Online"
                $Row.PnpErrorCount = $PnpErrorCount
                $Row.DeviceName = $DeviceName
                $Row.DeviceID = $FaultDevice.PNPDeviceID
                $Row.DeviceSatus = $FaultDevice.Status

                $DataTable.Rows.Add($Row)

            }

        } else {

            $Row = $DataTable.NewRow()

            $Row.Name = $Obj.ComputerName
            $Row.Model = $Obj.Model
            $Row.Status = "Online"
            $Row.PnpErrorCount = $PnpErrorCount
            $Row.DeviceName = [String]::Empty
            $Row.DeviceID = [String]::Empty
            $Row.DeviceSatus = [String]::Empty

            $DataTable.Rows.Add($Row)

        }

    } else {

            $Row = $DataTable.NewRow()

            $Row.Name = $Obj.ComputerName
            $Row.Model = $Obj.Model
            $Row.Status = "Offline"
            $Row.PnpErrorCount = [String]::Empty
            $Row.DeviceName = [String]::Empty
            $Row.DeviceID = [String]::Empty
            $Row.DeviceSatus = [String]::Empty

            $DataTable.Rows.Add($Row)

    }

    $Done++

    $PercentDone = [Math]::Round((($Done / $Count) * 100), 1, [MidpointRounding]::AwayFromZero)

    Write-Progress -Activity ("$Done/$Items in progress") -Status "$PercentDone% done:" -PercentComplete $PercentDone

}


$DataTable | Export-Csv -Path $OutputContent -NoTypeInformation

