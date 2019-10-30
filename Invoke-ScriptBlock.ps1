

<#

.SYNOPSIS

Just a POC that demonstrate Powershell could be run remotely without WinRM & PSSession


.NOTES

Script must be executed with administrator privileges on local machine
Account used to execute this script must have administrator privileges on targeted machine  


.EXAMPLE

Windows PowerShell
Copyright (C) 2016 Microsoft Corporation. All rights reserved.

PS C:\Users\POKEDEX> .\Scripts\Invoke-ScriptBlock.ps1 -ComputerName SALAMESH -ScriptBlock {
>> Get-Service | Where-Object { $_.Name -eq "WinRM" } | Format-Table
>> Get-Process | Where-Object { $_.ProcessName -eq "Powershell" } | Format-Table
>> }

Status   Name               DisplayName
------   ----               -----------
Stopped  WinRM              Gestion à distance de Windows (Gest...



Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    530      36    74988      69712       0,50  16748   0 powershell
    571      38    61488      74200       1,05  22132   2 powershell


PS C:\Users\POKEDEX>.\Scripts\Invoke-ScriptBlock.ps1 -ComputerName SALAMESH -ScriptBlock {
>> Get-Service | Where-Object { $_.Name -eq "WinRM" } | Format-List
>> Get-Process | Where-Object { $_.ProcessName -eq "Powershell" } | Format-List
>> }


Name                : WinRM
DisplayName         : Gestion à distance de Windows (Gestion WSM)
Status              : Stopped
DependentServices   : {}
ServicesDependedOn  : {RPCSS, HTTP}
CanPauseAndContinue : False
CanShutdown         : False
CanStop             : False
ServiceType         : Win32ShareProcess





Id      : 12492
Handles : 533
CPU     : 0,46875
SI      : 0
Name    : powershell

Id      : 22132
Handles : 571
CPU     : 1,046875
SI      : 2
Name    : powershell



PS C:\Users\POKEDEX>

#>




Param(

  [Parameter(Mandatory = $true)] 
  [String] $ComputerName,

  [Parameter(Mandatory = $true)] 
  [ScriptBlock] $ScriptBlock

)




Function Invoke-ScriptBlock() {

    Param(

        [Parameter(Mandatory=$true)]
        [IO.Pipes.NamedPipeClientStream] $PipeClient,

        [Parameter(Mandatory = $true)] 
        [ScriptBlock] $ScriptBlock
   
    )

    Try {


        [IO.StreamReader] $PipeReader = New-Object System.IO.StreamReader($PipeClient)

        [IO.StreamWriter] $PipeWriter = New-Object System.IO.StreamWriter($PipeClient)
        $PipeWriter.AutoFlush = $true

        $PipeWriter.WriteLine($ScriptBlock.ToString())
        $PipeWriter.WriteLine("---EOS---")

        [Text.StringBuilder] $Builder = [Text.StringBuilder]::new()

        While ( ($Incoming = $PipeReader.ReadLine()) -ne "---EOS---") { 

            [Void]$Builder.AppendLine($Incoming) 
    
        }

        Return $Builder.ToString()


    } Catch {


        Write-Host "$($_.Exception.GetType())`n$($_.Exception.Message)" -ForegroundColor Red

        Return $null


    } Finally {


        foreach ($Disposable in @($PipeWriter, $PipeReader, $PipeClient)) {

            if ($null -ne $Disposable) {

                [Void] $Disposable.Dispose()

            }

        }

    }

}




Function Create-PipeClient() {

    Param(

        [Parameter(Mandatory=$true)]
        [String]$ComputerName
   
    )


    Try {


        [IO.Pipes.NamedPipeClientStream] $PipeClient = new-object System.IO.Pipes.NamedPipeClientStream($ComputerName, 'ScriptBlock', [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::None, [System.Security.Principal.TokenImpersonationLevel]::Anonymous)

        $PipeClient.Connect()

        Return $PipeClient


    } Catch {

        Write-Host "$($_.Exception.GetType())`n$($_.Exception.Message)" -ForegroundColor Red
        
        Return $null
        
    }

}




Function Create-PipeServer() {

    Param(

        [Parameter(Mandatory=$true)]
        [String] $ComputerName
   
    )


    Try {


        [Management.ManagementOptions] $ConnectionOptions = New-Object System.Management.ConnectionOptions

        $ConnectionOptions.Authentication = [System.Management.AuthenticationLevel]::Packet

        $ConnectionOptions.Impersonation = [System.Management.ImpersonationLevel]::Impersonate

        $ConnectionOptions.EnablePrivileges = $true

        [Management.ManagementScope] $ManagementScope = New-Object System.Management.ManagementScope("\\$ComputerName\root\cimV2", $ConnectionOptions)

        [Management.ObjectGetOptions] $ObjectGetOptions = New-Object System.Management.ObjectGetOptions($null, [System.TimeSpan]::MaxValue, $true)

        [Management.ManagementClass] $ManagementClass = New-Object System.Management.ManagementClass($ManagementScope, "\\$ComputerName\root\cimV2:Win32_Process", $ObjectGetOptions)

        [ScriptBlock] $ScriptBlock = {$PipeServer = New-Object System.IO.Pipes.NamedPipeServerStream('ScriptBlock', [System.IO.Pipes.PipeDirection]::InOut) ; $PipeServer.WaitForConnection() ; $PipeReader = New-Object System.IO.StreamReader($PipeServer) ; $PipeWriter = New-Object System.IO.StreamWriter($PipeServer) ; $PipeWriter.AutoFlush = $true ; $Builder = [Text.StringBuilder]::new() ; [Void]$Builder.AppendLine('Try {') ; While ( ($Incoming = $PipeReader.ReadLine()) -ne '---EOS---') {  [Void]$Builder.AppendLine($Incoming) } ; [Void]$Builder.AppendLine('} Catch { $_.Exception.Message }') ; $NewPowerShell = [PowerShell]::Create().AddScript([Scriptblock]::Create($Builder.ToString())) ; $NewRunspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace() ; $NewRunspace.ApartmentState = [System.Threading.ApartmentState]::STA ; $NewPowerShell.Runspace = $NewRunspace ; $NewPowerShell.Runspace.Open() ; $Invoke = $NewPowerShell.BeginInvoke() ; $Result = $NewPowerShell.EndInvoke($Invoke) ; $Ser = [System.Management.Automation.PSSerializer]::Serialize($result) ; $PipeWriter.WriteLine($Ser) ; $PipeWriter.WriteLine('---EOS---') ; $PipeWriter.dispose() ; $PipeReader.Dispose() ; $PipeServer.Close() ; $PipeServer.Dispose()}

        [String] $Command = "&{ $($ScriptBlock.ToString()) }"

        [String] $CmdLine = "PowerShell.exe -command $Command"

        [Management.ManagementBaseObject] $Process = $ManagementClass.Create($CmdLine)
        
        Return $Process


    } Catch {


        Write-Host "$($_.Exception.GetType())`n$($_.Exception.Message)" -ForegroundColor Red

        Return $null

        
    } Finally {


        foreach ($Disposable in @($Process, $ManagementClass)) {

            if ($null -ne $Disposable) {

                [Void] $Disposable.Dispose()

            }

        }


    }

}




Function Is-Online() {


    Param(

        [Parameter(Mandatory=$true)]
        [String]$ComputerName
   
    )


    Try {
   
        [Bool] $Result = Test-Connection -ComputerName $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue

        Return $Result

    } Catch {

        Return $false

    }

}




if (Is-Online -ComputerName $ComputerName) {


    if ((Create-PipeServer -ComputerName $ComputerName) -ne $null) {


        [IO.Pipes.NamedPipeClientStream] $PipeClient = Create-PipeClient -ComputerName $ComputerName


        if ($null -ne $PipeClient) {  
           

            if ($PipeClient.IsConnected) {


                $Return = [Management.Automation.PSSerializer]::Deserialize((Invoke-ScriptBlock -PipeClient $PipeClient -ScriptBlock $ScriptBlock))

            }

            [Void] $PipeClient.Dispose()


            Return $Return


        } else {


            Return $null


        }


    } else {


            Return $null

    }


}  else {

    Write-Host "$ComputerName is not online" -ForegroundColor Yellow

}


