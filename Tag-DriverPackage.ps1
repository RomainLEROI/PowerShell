Param(

    [Parameter(Mandatory = $true)]
    [String] $SourcePath

)


$TagPath = New-Object -TypeName Collections.ArrayList
    
if (Test-Path $SourcePath) {

    Write-Host "Source Path $SourcePath exists"

    foreach ($DriverFolder in (Get-ChildItem -Path $SourcePath -Recurse -Directory -Force)) {

        foreach ($Driver in (Get-ChildItem -Path $($DriverFolder.FullName) -Filter "*.inf" -Recurse)) {

            $Path = (Get-Item -Path $Driver.FullName).Directory.FullName

            if (!($TagPath.Contains($Path))) {

                [Void] $TagPath.Add($Path)

            }

        }

    }

    $DriverCount = $TagPath.Count

    if ($DriverCount -gt 0) {

        Write-Host "Drivers count : $DriverCount"

        $Done = 0
        Write-Progress -Activity "Tagging drivers package" -Status "$Done% done:" -PercentComplete $Done

        foreach ($Path in $TagPath) {
   
            $Guid = [Guid]::NewGuid().guid
            $GuidPath = (Join-Path -Path $Path -ChildPath "{$Guid}")
            Write-Host "`t$GuidPath"
            New-Item -Path $GuidPath -ItemType File -Force | out-null

            $PercentDone = [System.Math]::Round((($Done / $DriverCount) * 100), 1, [MidpointRounding]::AwayFromZero)
            Write-Progress -Activity ("Tagging drivers package") -Status "$PercentDone% done:" -PercentComplete $PercentDone              

            $Done++

        }

    } else {

        Write-Host "[-] Drivers count : 0 `n" -ForegroundColor Red

    }

} else {

    Write-Host "[!] Source Path $SourcePath does not exists`n" -ForegroundColor Red

}
