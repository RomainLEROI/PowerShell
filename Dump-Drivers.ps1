Param(

    [Parameter(Mandatory = $true)]
    [ValidateScript({ ($_ -match "^[a-zA-Z]:\\") })]
    [String] $DriverPackagePath

)




Function Copy-Driver() {

    Param(

        [Parameter(Mandatory = $true)]
        [String] $SourcePath,

        [Parameter(Mandatory = $true)]
        [String] $DestinationPath

    )


    [Object[]] $Files = Get-ChildItem $SourcePath -Recurse

    [Int] $Count = 1

    [String] $CurrentPath = [String]::Empty


    foreach ($File in $Files) {

        $CurrentPath = $File.FullName.Replace("$SourcePath\", [String]::Empty)

        Write-Progress -Id 1 -Activity "Files copy" -Status "$Count/$(($Files | Measure-Object).Count): $CurrentPath"

        if ($File.PSIsContainer)  {

            New-Item -ItemType Directory "$DestinationPath\$CurrentPath" | Out-Null 

        }  else {

            Copy-Item -Path $File.FullName -Destination "$DestinationPath\$CurrentPath" -Force | Out-Null 

        } 
               
        $Count++  

    }

}




Function Build-DriverPackage() {

    Param(

        [Parameter(Mandatory = $true)]
        [String] $SourcePath,

        [Parameter(Mandatory = $true)]
        [String] $DriverPackagePath,

        [Parameter(Mandatory = $true)]
        [Int] $DriverCount

    )

    

    Write-Output -InputObject "`nBuilding driver package..."

    [Int] $Done = 0
    [Int] $Point = 0

    Write-Progress -Activity "Building drivers package" -Status "$Done% done:" -PercentComplete $Done;

    foreach ($DriverFolder in (Get-ChildItem -Path $SourcePath -Recurse -Directory -Force)) {

	    foreach ($Driver in (Get-ChildItem -Path $($DriverFolder.FullName) -Filter "*.inf" -Recurse)) {

            foreach ($DriverInfos in (Get-WindowsDriver -Online -Driver $($Driver.FullName))) {
      
                [String] $DriverPackageFolder = [IO.Path]::Combine($DriverPackagePath, "$($DriverInfos.ClassName)\$($DriverInfos.ProviderName)\$($DriverFolder.Name)")

                [String] $ParentDir = $(Get-Item $Driver.FullName).Directory.Name

                [String] $ParentPath = $(Get-Item $Driver.FullName).Directory.FullName
      
                if ($DriverFolder.Name -ne $ParentDir) {

                    $DriverPackageFolder = [IO.Path]::Combine($DriverPackageFolder, $ParentDir)

                } 
 
                if (-not (Test-Path $DriverPackageFolder)) {

                    New-Item -Path $DriverPackageFolder -ItemType Directory -Force | Out-Null 

                    [String] $Guid = [Guid]::NewGuid().guid

                    New-Item -Path ([IO.Path]::Combine($DriverPackageFolder, "{$Guid}")) -ItemType File -Force | Out-Null 

                    Copy-Driver -SourcePath $ParentPath -DestinationPath $DriverPackageFolder

                    [Decimal] $PercentDone = [System.Math]::Round((($Done / $DriverCount) * 100), 1, [MidpointRounding]::AwayFromZero)

                    Write-Progress -Activity ("Building driver package" + "." * $Point) -Status "$PercentDone% done:" -PercentComplete $PercentDone;

                }

                $Done++
                $Point++

                if ($Point -gt 3) {
                    $Point = 1
                }

                break

            }

	    }

    }

    Write-Output -InputObject "Driver package built"

}




Function Dump-Driver() {

    Param(

        [Parameter(Mandatory = $true)]
        [String] $TempPath

    )

    Try {

        [PowerShell] $Job = [powershell]::Create()

        [Void] $Job.AddCommand("Export-WindowsDriver")

        [Void] $Job.AddParameter("Online")

        [Void] $Job.AddParameter("Destination", $TempPath)

        [Object] $Invoke = $Job.BeginInvoke()

        Write-Host "Dumping drivers, please wait" -NoNewline

        Do {

            Write-Host "." -NoNewline

            Start-Sleep -Seconds 1

        } While ( $Invoke.IsCompleted -contains $false)

        [Object[]] $Dump = $Job.EndInvoke($Invoke)

        Return $Dump 


    } Catch {

        Write-Output -InputObject "$($_.Exception.GetType())`n$($_.Exception.Message)"

        Return $null

    }

}



[String] $TempPath = [IO.Path]::Combine($DriverPackagePath, "TempDump")

if (!(Test-Path ($TempPath))) { 

    New-Item ($TempPath) -ItemType Directory -Force | Out-Null 

}

$Dump = Dump-Driver -TempPath $TempPath

if ($null -ne $Dump) {

    Build-DriverPackage -SourcePath $TempPath -DriverPackagePath $DriverPackagePath -DriverCount $Dump.Count

}

Remove-Item -Path $TempPath -Force -Recurse
