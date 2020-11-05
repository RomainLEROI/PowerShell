<#
Input.csv
ComputerName;Model
#>

Function Scan-PnpDevice {

    Param(
 
        [Parameter(Mandatory=$true)]
        [String]$ComputerName,
 
        [Parameter(Mandatory=$true)]
        [String]$ComputerModel
 
    )

    $Out = @()

    $NamesFilter = @(

        "Microsoft PS/2 Mouse"
        "Standard PS/2 Keyboard"
        "PS/2 Compatible Mouse"

    )

    $IDsFilter = @()

    $IsOnline = Try { Write-Output (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction SilentlyContinue) } Catch { Write-Output $false }

    if ($IsOnline) {

        Try {

            $FaultyDevices = Get-WmiObject -ComputerName $ComputerName -ClassName Win32_PNPEntity -ErrorAction SilentlyContinue | Where-Object { ($_.Status -ne "OK") -and !($_.Name -in $NamesFilter) -and !($_.PNPDeviceID -in $IDsFilter) } | Select-Object Name, PNPDeviceID, Status

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


                $FaultyDrivers = Get-WmiObject -ComputerName $ComputerName -ClassName Win32_PnPSignedDriver -ErrorAction SilentlyContinue | Where-Object { ($_.DeviceID -eq $FaultDevice.PNPDeviceID) } | Select-Object DeviceName, DriverVersion, InfName, Manufacturer

                if (($FaultyDrivers | Measure-Object).Count -gt 0) {

                    foreach ($FaultyDriver in $FaultyDrivers) {

                        if ($DeviceName -eq "Unknown Device") {

                            $DeviceName = $FaultyDriver.DeviceName

                        }

                        $Details = @{

                            Name = $ComputerName
                            Model = $ComputerModel
                            Status = "Online"
                            PnpErrorCount = $PnpErrorCount
                            DeviceName = $DeviceName
                            DeviceID = $FaultDevice.PNPDeviceID
                            DeviceSatus = $FaultDevice.Status
                            DriverManufacturer = $FaultyDriver.Manufacturer
                            DriverVersion = $FaultyDriver.DriverVersion
                            DriverInfName = $FaultyDriver.InfName

                        }

                        $Out += $Details

                    }

                } else {

                    $Details = @{

                        Name = $ComputerName
                        Model = $ComputerModel
                        Status = "Online"
                        PnpErrorCount = $PnpErrorCount
                        DeviceName = $DeviceName
                        DeviceID = $FaultDevice.PNPDeviceID
                        DeviceSatus = $FaultDevice.Status
                        DriverManufacturer = [String]::Empty
                        DriverVersion = [String]::Empty
                        DriverInfName = [String]::Empty

                    }

                    $Out += $Details

                }




            }

        } else {

            $Details = @{

                Name = $ComputerName
                Model = $ComputerModel
                Status = "Online"
                PnpErrorCount = $PnpErrorCount
                DeviceName = [String]::Empty
                DeviceID = [String]::Empty
                DeviceSatus = [String]::Empty
                DriverManufacturer = [String]::Empty
                DriverVersion = [String]::Empty
                DriverInfName = [String]::Empty

            }

            $Out += $Details

        }

    } else {

            $Details = @{

                Name = $ComputerName
                Model = $ComputerModel
                Status = "Offline"
                PnpErrorCount = [String]::Empty
                DeviceName = [String]::Empty
                DeviceID = [String]::Empty
                DeviceSatus = [String]::Empty
                DriverManufacturer = [String]::Empty
                DriverVersion = [String]::Empty
                DriverInfName = [String]::Empty

            }

            $Out += $Details

    }

    Return $Out

}



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
[Void] $DataTable.columns.add("DriverManufacturer", [String])
[Void] $DataTable.columns.add("DriverVersion", [String])
[Void] $DataTable.columns.add("DriverInfName", [String])


$Pool = New-Object -TypeName Collections.Generic.List[String]

$PoolLimit = 30


Do {


    if ($Pool.Count -eq 0) {

        if (($Count - $Done) -lt $PoolLimit) {

            $PoolCount = ($Count - $Done)

        } else {

            $PoolCount = $PoolLimit

        }
        
        $ArrJobs = @()     

        for ($i = $Done; $i -lt ($PoolCount + $Done); $i++) {

            Write-Host "Adding $($InputContent[$i].ComputerName) to pool"

            $Invoked = @{

                ComputerName = $InputContent[$i].ComputerName
                Job  = Start-Job -ScriptBlock ${function:Scan-PnpDevice} -ArgumentList @($InputContent[$i].ComputerName, $InputContent[$i].Model) -Name $InputContent[$i].ComputerName

            }

            $ArrJobs += $Invoked

            $Pool.Add($InputContent[$i].ComputerName)

        }

    }

    
    foreach ($Job in $ArrJobs) {


        if ($Pool.Contains($Job.ComputerName)) {
                  

            if (!((Get-Job -Name $Job.ComputerName).State).Contains("Running")) { 

                $PnPInformations = Receive-Job -Job $Job.Job

                foreach ($PnPInformation in $PnPInformations) {

                    $Row = $DataTable.NewRow()

                    $Row.Name = $PnPInformation.Name
                    $Row.Model = $PnPInformation.Model
                    $Row.Status = $PnPInformation.Status
                    $Row.PnpErrorCount = $PnPInformation.PnpErrorCount
                    $Row.DeviceName = $PnPInformation.DeviceName
                    $Row.DeviceID = $PnPInformation.DeviceID
                    $Row.DeviceSatus = $PnPInformation.DeviceSatus
                    $Row.DriverManufacturer = $PnPInformation.DriverManufacturer
                    $Row.DriverVersion = $PnPInformation.DriverVersion
                    $Row.DriverInfName = $PnPInformation.DriverInfName

                    $DataTable.Rows.Add($Row)

                }

                Write-Host "$($Job.ComputerName) completed"

                Remove-Job -Job $Job.Job

                $Pool.Remove($Job.ComputerName) | Out-Null

                $Done++

                $PercentDone = [Math]::Round((($Done / $Count) * 100), 1, [MidpointRounding]::AwayFromZero)

                Write-Progress -Activity ("$Done/$Count in progress") -Status "$PercentDone% done:" -PercentComplete $PercentDone

            }

        }

    }

    Start-Sleep -Seconds 1


} while ($Done -ne $Count) 


$DataTable | Export-Csv -Path $OutputContent -NoTypeInformation

