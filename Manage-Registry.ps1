
Param(
 
    [Parameter(ParameterSetName = "CheckKeyExists", Mandatory = $true)]
    [Switch] $CheckKeyExists,

    [Parameter(ParameterSetName = "CheckValueNameExists", Mandatory = $true)]
    [Switch] $CheckValueNameExists,

    [Parameter(ParameterSetName = "GetValue", Mandatory = $true)]
    [Switch] $GetValue,

    [Parameter(ParameterSetName = "GetValueKind", Mandatory = $true)]
    [Switch] $GetValueKind,

    [Parameter(ParameterSetName = "SetValue", Mandatory = $true)]
    [Switch] $SetValue,

    [Parameter(ParameterSetName = "DeleteValueName", Mandatory = $true)]
    [Switch] $DeleteValueName,

    [Parameter(ParameterSetName = "CreateKey", Mandatory = $true)]
    [Switch] $CreateKey,

    [Parameter(ParameterSetName = "DeleteKey", Mandatory = $true)]
    [Switch] $DeleteKey,

    [Parameter(Mandatory = $false)]
    [string] $ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $true)] 
    [Microsoft.Win32.RegistryView] $View,

    [Parameter(Mandatory = $true)] 
    [Microsoft.Win32.RegistryHive] $Hive,

    [Parameter(Mandatory = $true)] 
    [String] $Path,

    [Parameter(ParameterSetName = "DeleteKey", Mandatory = $false)]
    [Switch] $Recurse,

    [Parameter(ParameterSetName = "SetValue", Mandatory = $true)]
    [Parameter(ParameterSetName = "DeleteValue", Mandatory = $true)]
    [Parameter(ParameterSetName = "DeleteValueName", Mandatory = $true)]
    [Parameter(ParameterSetName = "CheckValueNameExists", Mandatory = $true)]
    [Parameter(ParameterSetName = "GetValue", Mandatory = $true)]
    [Parameter(ParameterSetName = "GetValueKind", Mandatory = $true)]
    [String] $ValueName,

    [Parameter(ParameterSetName = "SetValue", Mandatory = $true)]
    [Parameter(ParameterSetName = "AddValue", Mandatory = $true)]
    [Parameter(ParameterSetName = "DeleteValueName", Mandatory = $true)]
    $Value,

    [Parameter(ParameterSetName = "SetValue", Mandatory = $false)]
    [Microsoft.Win32.RegistryValueKind] $ForceValueKind = [Microsoft.Win32.RegistryValueKind]::None,

    [Parameter(Mandatory = $false)]
    [Switch] $Hidden

)


# Manage-Registry.ps1 -SetValue -View Registry64 -Hive LocalMachine -Path "SOFTWARE\Test" -ValueName "test" -Value $([char[]]"Test") -ForceValueKind Binary
# Manage-Registry.ps1 -SetValue -View Registry64 -Hive LocalMachine -Path "SOFTWARE\Test" -ValueName "test1" -Value @("Test1","Test2") -ForceValueKind MultiString
# Manage-Registry.ps1 -SetValue -View Registry64 -Hive LocalMachine -Path "SOFTWARE\Test" -ValueName "test3" -Value Test1,Test2 -ForceValueKind MultiString


Begin {

    Function Check-KeyExists {

        Param (

            [Parameter(Mandatory = $true)] 
            [Microsoft.Win32.RegistryKey] $Root,

            [Parameter(Mandatory = $true)] 
            [String] $KeyPath

        )

        $Key = $Root.OpenSubKey($KeyPath, $false)

        if ($null -ne $Key) {

            $Key.Close()
            $Key.Dispose()
            $Result = $true

        } else {

            $Result = $false

        }
      
        Return $Result

    }


    Function Check-ValueNameExists {

        Param (

            [Parameter(Mandatory = $true)] 
            [Microsoft.Win32.RegistryKey] $Root,

            [Parameter(Mandatory = $true)] 
            [String] $KeyPath,

            [Parameter(Mandatory = $true)] 
            [String] $ValueName

        )

        $Key = $Root.OpenSubKey($KeyPath, $false)

        if ($null -ne $Key) {

            if ($Key.GetValueNames().Contains($ValueName)) {

                $Result = $true

            } else {

                $Result = $false

            }

            $Key.Close()
            $Key.Dispose()
        

        } else {

            $Result = $false

        }
       
        Return $Result

    }


    Function Get-Value {

        Param (

            [Parameter(Mandatory = $true)] 
            [Microsoft.Win32.RegistryKey] $Root,

            [Parameter(Mandatory = $true)] 
            [String] $KeyPath,

            [Parameter(Mandatory = $true)] 
            [String] $ValueName

        )

        $Key = $Root.OpenSubKey($KeyPath, $false)

        if ($null -ne $Key) {

            $Result = $Key.GetValue($ValueName)

            $Key.Close()
            $Key.Dispose()      

        } else {

            $Result = $null

        }
       
        Return $Result

    }


    Function Get-ValueKind {

        Param (

            [Parameter(Mandatory = $true)] 
            [Microsoft.Win32.RegistryKey] $Root,

            [Parameter(Mandatory = $true)] 
            [String] $KeyPath,

            [Parameter(Mandatory = $true)] 
            [String] $ValueName

        )

        $Key = $Root.OpenSubKey($KeyPath, $false)

        if ($null -ne $Key) {

            $Result = $Key.GetValueKind($ValueName)

            $Key.Close()
            $Key.Dispose()      

        } else {

            $Result = $null

        }
       
        Return $Result

    }


    Function Set-Value {

        Param (

            [Parameter(Mandatory = $true)] 
            [Microsoft.Win32.RegistryKey] $Root,

            [Parameter(Mandatory = $true)] 
            [String] $KeyPath,

            [Parameter(Mandatory = $true)] 
            [String] $ValueName,

            [Parameter(Mandatory = $true)] 
            $Value,

            [Parameter(Mandatory = $false)] 
            [Microsoft.Win32.RegistryValueKind] $ForceValueKind

        )

        $Key = $Root.OpenSubKey($KeyPath, $true)

        Try {

            if ($null -ne $Key) {

                if (($ValueName -eq "@") -or ($ValueName -eq "default")) {

                    $ValueName = [String]::Empty

                }


                if ($ForceValueKind -ne [Microsoft.Win32.RegistryValueKind]::None) {
              
                    switch ($ForceValueKind) {

                        $([Microsoft.Win32.RegistryValueKind]::Binary) {

                            $Key.SetValue($ValueName, [Byte[]] $Value, $ForceValueKind)

                        } $([Microsoft.Win32.RegistryValueKind]::String) {

                            $Key.SetValue($ValueName, [String] $Value, $ForceValueKind)

                        } $([Microsoft.Win32.RegistryValueKind]::MultiString) {

                            $Key.SetValue($ValueName, [String[]] $Value, $ForceValueKind)

                        } $([Microsoft.Win32.RegistryValueKind]::ExpandString) {

                            $Key.SetValue($ValueName, [String] $Value, $ForceValueKind)

                        } $([Microsoft.Win32.RegistryValueKind]::QWord) {

                            $Key.SetValue($ValueName, [Int64] $Value, $ForceValueKind)

                        } $([Microsoft.Win32.RegistryValueKind]::DWord) {

                            $Key.SetValue($ValueName, [Int32] $Value, $ForceValueKind)

                        } Default {

                            $Key.SetValue($ValueName, $Value, [Microsoft.Win32.RegistryValueKind]::Unknown)

                        }

                    }

 
                } else {

                    $Key.SetValue($ValueName, $Value)

                }

            
                $Result = $true

            } else {

                $Result = $false

            }

        } Catch {

            $Result = $false

        } Finally {

            if ($null -ne $Key) {

                $Key.Close()
                $Key.Dispose()

            }
         
        }
  
        Return $Result

    }


    Function Create-Key {

        Param (

            [Parameter(Mandatory = $true)] 
            [Microsoft.Win32.RegistryKey] $Root,

            [Parameter(Mandatory = $true)] 
            [String] $KeyPath

        )

        $Key = $Root.OpenSubKey($KeyPath, $false)

        Try {

            if ($null -ne $Key) {

                $Result = $true

            } else {

                $Key = $Root.CreateSubKey($KeyPath)

                $Result = $true

            }

        } Catch {

            $Result = $false

        } Finally {

            if ($null -ne $Key) {

                $Key.Close()
                $Key.Dispose()

            }
                     
        }
  
        Return $Result   
    }


    Function Delete-ValueName {

        Param (

            [Parameter(Mandatory = $true)] 
            [Microsoft.Win32.RegistryKey] $Root,

            [Parameter(Mandatory = $true)] 
            [String] $KeyPath,

            [Parameter(Mandatory = $true)] 
            [String] $ValueName

        )


        $Key = $Root.OpenSubKey($KeyPath, $true)

        Try {

            if ($null -ne $Key) {

                $Key.DeleteValue($ValueName, $true)

            } else {

                $Result = $false

            }

        } Catch {

            $Result = $false

        } Finally {

            if ($null -ne $Key) {

                $Key.Close()
                $Key.Dispose()

            }
                
        }
       
        Return $Result

    }


    Function Delete-Key {

        Param (

            [Parameter(Mandatory = $true)] 
            [Microsoft.Win32.RegistryKey] $Root,

            [Parameter(Mandatory = $true)] 
            [String] $KeyPath,

            [Parameter(Mandatory = $true)] 
            [Bool] $Recurse
        )

        Try {

            if ($Recurse) {

                $Root.DeleteSubKeyTree($KeyPath, $true)

                $Result = $true

            } else {

                $Key = $Root.DeleteSubKey($KeyPath, $true)

                $Result = $true

            }

        } Catch {

            $Result = $false

        } 
  
        Return $Result   
    }


    $IsElevated = ([Security.Principal.WindowsPrincipal]::New([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    $IsLocalHost = (($ComputerName -eq $env:COMPUTERNAME) -or ($ComputerName -eq 'localhost') -or ($ComputerName -eq '.') -or (((Get-NetIPAddress).IPAddress).Contains($ComputerName)))

    if ($IsLocalHost) {

        $IsOnline = $true

    } else {

        $IsOnline = Try { Write-Output (Test-Connection -ComputerName $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue) } Catch { Write-Output $false }

    }

} Process {

    
    if ($IsOnline) {

        if ($Hidden) {

            $KeyPath = "`0`0$Path"

        } else {

            $KeyPath = "$Path"

        }

        if ($IsLocalHost) {

            $Root = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Hive, $View)

        } else {

            $Root = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Hive, $ComputerName,$View)

        }

        if ($CheckKeyExists) {
  
          $Result = Check-KeyExists -Root $Root -KeyPath $KeyPath 

        } 

        if ($CheckValueNameExists) {

           $Result = Check-ValueNameExists -Root $Root -KeyPath $KeyPath -ValueName $ValueName

        }

        if ($GetValue) {

            $Result = Get-Value -Root $Root -KeyPath $KeyPath -ValueName $ValueName

        }

        if ($GetValueKind) {

            $Result = Get-ValueKind -Root $Root -KeyPath $KeyPath -ValueName $ValueName
       
        }

        if ($SetValue) {

            $Result = Set-Value -Root $Root -KeyPath $KeyPath -ValueName $ValueName -Value $Value -ForceValueKind $ForceValueKind

        }

        if ($DeleteValueName) {

            $Result = Delete-ValueName -Root $Root -KeyPath $KeyPath -ValueName $ValueName

        }

        if ($CreateKey) {

            $Result = Create-Key -Root $Root -KeyPath $KeyPath

        }

        if ($DeleteKey) {

            $Result = Delete-Key -Root $Root -KeyPath $KeyPath -Recurse $Recurse.IsPresent

        }

    } else {

        Write-Warning -Message "$ComputerName is not online"

    }

} End {

    if ($null -ne $Root) {

        $Root.Close()
        $Root.Dispose()

    }

    Return $Result

}
