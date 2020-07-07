
<#
    [-] AppX
    [-] Branding
        [-] 4K
            img0_768x1024.jpg
            img0_768x1366.jpg
            img0_1024x768.jpg
            img0_1200x1920.jpg
            img0_1280x1024.jpg
            img0_1366x768.jpg
            img0_1600x2560.jpg
            img0_2160x3840.jpg
            img0_2560x1600.jpg
            img0_3840x2160.jpg
       [-] Wallpaper
            img0.jpg
    [-] Drivers
    [-] Export
    [-] Mount_Image
    [-] Mount_REImage
    [-] SRC
        [-] [+]Windows10 ISO content
    [-] Updates
        AdobeFlashUpdate.msu
        ServicingUpdate.msu
        MonthlyCU.msu
    FeaturesUpdates.esd
    -> New.esd
#>

$DISMFile = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe"

$BaseEsd = Join-Path -Path $PSScriptRoot -ChildPath "BASE.esd"
$NewEsd = Join-Path -Path $PSScriptRoot -ChildPath "NEW.esd"

$AdobeFlashUpdate = Join-Path -Path $PsScriptRoot -ChildPath "Updates\AdobeFlashUpdate.msu"
$ServicingUpdate = Join-Path -Path $PsScriptRoot -ChildPath "Updates\ServicingUpdate.msu"
$MonthlyCU = Join-Path -Path $PsScriptRoot -ChildPath "Updates\MonthlyCU.msu"

$AppX = Join-Path -Path $PSScriptRoot -ChildPath "AppX"
$Sources = Join-Path -Path $PSScriptRoot -ChildPath "SRC"
$Drivers = Join-Path -Path $PSScriptRoot -ChildPath "Drivers"
$Export = Join-Path -Path $PSScriptRoot -ChildPath "Export"
$ImageMountFolder = Join-Path -Path $PSScriptRoot -ChildPath "Mount_Image"
$REImageMountFolder = Join-Path -Path $PSScriptRoot -ChildPath "Mount_REImage"

$TargetedIndex = 6

$IndexDic = @{

    1 = "Windows Setup Media"
    2 = "Microsoft Windows PE (x64)"
    3 = "Microsoft Windows Setup (x64)"
    4 = "Windows 10 Éducation"
    5 = "Windows 10 Éducation N"
    6 = "Windows 10 Entreprise"
    7 = "Windows 10 Entreprise N"
    8 = "Windows 10 Professionnel"
    9 = "Windows 10 Professionnel N"

}

$AppsToRemove = @(

    "Microsoft.3DBuilder"
    "Microsoft.BingWeather"
    "Microsoft.Getstarted"
    "Microsoft.Messaging"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.Office.OneNote"
    "Microsoft.OneConnect"
    "Microsoft.People"
    "Microsoft.SkypeApp"
    "Microsoft.StorePurchaseApp"
    "Microsoft.WindowsAlarms"
    "Microsoft.windowscommunicationsapps"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.Xbox.TCUI"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"

)

Write-Host "Start : $([datetime]::Now)" -ForegroundColor Yellow

for ($i = 1; $i -le $IndexDic.Count; $i++) {

    if ($i -in @(1, 2, 3, $TargetedIndex)) {

        Write-Host "`n$([datetime]::Now) Extracting $($IndexDic[$i]) Install.wim from $BaseEsd" -ForegroundColor Yellow

        & $DISMFile /Export-Image /SourceImageFile:$BaseEsd /SourceIndex:$i /DestinationImageFile:$Export\Install.wim /Compress:max /CheckIntegrity   

    }

    if ($i -eq $TargetedIndex) {

        Write-Host "`n$([datetime]::Now) Mounting $($IndexDic[$i]) Install.wim into $ImageMountFolder" -ForegroundColor Yellow

        & $DISMFile /Mount-Wim /WimFile:$Export\Install.wim /MountDir:$ImageMountFolder /index:1

        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name

        $Targets = @((Join-Path -Path $ImageMountFolder -ChildPath "Windows\Web\Wallpaper\Windows"), (Join-Path -Path $ImageMountFolder -ChildPath "Windows\Web\4K\Wallpaper\Windows"))

        foreach ($Target in $Targets) {

            if (Test-Path -Path $Target) {

                $Files = Get-ChildItem -Path $Target -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { [IO.Path]::GetExtension($_.fullName) -eq ".jpg" }

                if ($null -ne $Files) {

                    foreach ($File in $Files) {
                   
                        takeown /f $File.FullName

                        sleep -Seconds 1

                        icacls $File.FullName /Grant "$($CurrentUser):(F)"

                        sleep -Seconds 1

                        Try {

                            Remove-Item -Path $File.FullName -ErrorAction SilentlyContinue

                            if (!(Test-Path -Path "$($File.FullName)")) {

                                Write-Host "$($File.FullName) was successfully deleted"

                            } else {

                                Write-Host "Failed to delete $($File.FullName)" -ForegroundColor Red

                            }

                        } Catch {

                            Write-Host "Failed to delete $($File.FullName) : $($_.Exception.Message)" -ForegroundColor Red

                        }

                    }

                }

            } else {

                Write-Host "$Target does not exists"

            }   

        }

        $Targets = @{

            (Join-Path -Path $PSScriptRoot -ChildPath "Branding\Wallpaper") = (Join-Path -Path $ImageMountFolder -ChildPath "Windows\Web\Wallpaper\Windows")
            (Join-Path -Path $PSScriptRoot -ChildPath "Branding\4K") = (Join-Path -Path $ImageMountFolder -ChildPath "Windows\Web\4K\Wallpaper\Windows")
        }

        foreach ($Target in $Targets.GetEnumerator()) {

            $Files = Get-ChildItem -Path $Target.Key -Recurse -Force -ErrorAction SilentlyContinue  | Where-Object { [IO.Path]::GetExtension($_.fullName) -eq ".jpg" }

            if ($null -ne $Files) {

                foreach ($File in $Files) {

                    $DestFile = (Join-Path -Path $Target.Value -ChildPath $File.Name)

                    Try {

                        Copy-Item -Path $File.FullName -Destination $DestFile  -Force -ErrorAction SilentlyContinue

                        if (Test-Path -Path $DestFile) {

                            Write-Host  "$DestFile was successfully copied"

                        } else {

                            Write-Host "Failed to copy $DestFile" -ForegroundColor Red

                        }

                    } Catch {

                        Write-Host "Failed to copy $DestFile : $($_.Exception.Message)" -ForegroundColor Red

                    }

                }

            } else {

                Write-Host "No file was found into $($Target.Key)" -ForegroundColor Red

            }

        }

        Write-Host "`n$([datetime]::Now) Mount offline HKLM\SYSTEM into online HKLM\OFFLINE" -ForegroundColor Yellow

        reg load HKLM\OFFLINE $ImageMountFolder\Windows\System32\Config\SYSTEM

        Write-Host "`n$([datetime]::Now) Set RemoteRegistry service to autostart" -ForegroundColor Yellow

        Set-ItemProperty -Path "HKLM:\OFFLINE\ControlSet001\Services\RemoteRegistry" -Name "Start" -Value 2 -Force | Out-Null

        Write-Host "`n$([datetime]::Now) Unmount HKLM\OFFLINE" -ForegroundColor Yellow

        reg unload HKLM\OFFLINE

        Write-Host "`n$([datetime]::Now) Add drivers from $Drivers" -ForegroundColor Yellow

        & $DISMFile /Image:$ImageMountFolder /Add-Driver /Driver:$Drivers /Recurse

        Write-Host "`n$([datetime]::Now) Add HP Hotkeys AppX" -ForegroundColor Yellow

        & $DISMFile /Image:$ImageMountFolder /Add-ProvisionedAppxPackage /PackagePath:$AppX\HotKeys\54e424f990bf4d1791240c003ee9d48b.appxbundle /Region="all" /LicensePath:$AppX\HotKeys\54e424f990bf4d1791240c003ee9d48b_License1.xml /dependencypackagepath=$AppX\HotKeys\Microsoft.VCLibs.140.00_14.0.27323.0_arm__8wekyb3d8bbwe.appx /dependencypackagepath=$AppX\HotKeys\Microsoft.VCLibs.140.00_14.0.27323.0_arm64__8wekyb3d8bbwe.appx /DependencyPackagePath=$AppX\HotKeys\Microsoft.VCLibs.140.00_14.0.27323.0_x64__8wekyb3d8bbwe.appx /dependencypackagepath=$AppX\HotKeys\Microsoft.VCLibs.140.00_14.0.27323.0_x86__8wekyb3d8bbwe.appx

        Write-Host "`n$([datetime]::Now) Add the Servicing Update to the Windows 10 Enterprise image" -ForegroundColor Yellow

        & $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$ServicingUpdate

        Write-Host "`n$([datetime]::Now) Add the Adobe Flash Update to the Windows 10 Enterprise image" -ForegroundColor Yellow

        & $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$AdobeFlashUpdate

        Write-Host "`n$([datetime]::Now) Add the Monthly CU to the Windows 10 Enterprise image" -ForegroundColor Yellow

        & $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$MonthlyCU

        Write-Host "`n$([datetime]::Now) Cleanup the image BEFORE installing .NET" -ForegroundColor Yellow

        & $DISMFile /Image:$ImageMountFolder /Cleanup-Image /StartComponentCleanup /ResetBase

        Write-Host "`n$([datetime]::Now) Add .NET Framework 3.5.1 to the Windows 10 Enterprise image" -ForegroundColor Yellow

        & $DISMFile /Image:$ImageMountFolder /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"$Sources\sources\sxs"

        Write-Host "`n$([datetime]::Now) Re-apply CU because of .NET changes" -ForegroundColor Yellow

        & $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$MonthlyCU

        $Provisioned = Get-AppxProvisionedPackage -Path $ImageMountFolder

        foreach ($App in $AppsToRemove) {

            $Current = $Provisioned | Where-Object { $_.DisplayName -eq $App }

            if ($Current) {

                Remove-AppxProvisionedPackage -Path $ImageMountFolder -PackageName $Current.PackageName | Out-Null

                Write-Host "$($Current.PackageName) provisioned package was successfully removed"

            } else {

                Write-Host "Unable to find provisioned package $App" -ForegroundColor Red

            }

        }

        $TmpWinREImage = "$Export\tmp_winre.wim"

        Write-Host "`n$([datetime]::Now) Move WinRE Image to $Export\tmp_winre.wim" -ForegroundColor Yellow

        Move-Item -Path $ImageMountFolder\Windows\System32\Recovery\winre.wim -Destination $TmpWinREImage

        Write-Host "`n$([datetime]::Now) Mount the temp WinRE Image" -ForegroundColor Yellow

        & $DISMFile /Mount-Wim /WimFile:$TmpWinREImage /mountdir:$REImageMountFolder /index:1

        Write-Host "`n$([datetime]::Now) Add the Servicing Update to the WinRE image" -ForegroundColor Yellow

        & $DISMFile /Image:$REImageMountFolder /Add-Package /PackagePath:$ServicingUpdate

        Write-Host "`n$([datetime]::Now) Add the Monthly CU to the WinRE image" -ForegroundColor Yellow

        & $DISMFile /Image:$REImageMountFolder /Add-Package /PackagePath:$MonthlyCU

        Write-Host "`n$([datetime]::Now) Cleanup the WinRE image" -ForegroundColor Yellow

        & $DISMFile /Image:$REImageMountFolder /Cleanup-Image /StartComponentCleanup /ResetBase 

        Write-Host "`n$([datetime]::Now) Unmount the WinRE image" -ForegroundColor Yellow

        & $DISMFile /UnMount-Wim /MountDir:$REImageMountFolder /Commit

        Write-Host "`n$([datetime]::Now) Export new WinRE wim back to original location" -ForegroundColor Yellow

        & $DISMFile /Export-Image /SourceImageFile:$TmpWinREImage /SourceIndex:1 /DestinationImageFile:$Export\$ImageMountFolder\Windows\System32\Recovery\winre.wim

        Remove-Item -Path $TmpWinREImage -Force

        Write-Host "`n$([datetime]::Now) Unmounting $($IndexDic[$i]) Install.wim from $ImageMountFolder" -ForegroundColor Yellow

        & $DISMFile /UnMount-Wim /MountDir:$ImageMountFolder /Commit
      
    }


    if ($i -in @(1, 2, 3, $TargetedIndex)) {

        Write-Host "`n$([datetime]::Now) Importing $($IndexDic[$i]) Install.wim into $NewEsd" -ForegroundColor Yellow

        & $DISMFile /Export-Image /SourceImageFile:$Export\Install.wim /SourceIndex:1 /DestinationImageFile:$NewEsd /Compress:Recovery /CheckIntegrity

        Remove-Item -Path $Export\Install.wim -Force

    }

}

Write-Host "End : $([datetime]::Now)" -ForegroundColor Yellow
