<#

.SYNOPSIS

This script is just a POC that demonstrates that powershell can be executed remotely without PSRemoting


.NOTES

Script must be executed with an account that has the adminstrator privileges on both local and remote computers
The local machine process must be elevated


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


PS C:\Users\POKEDEX>.\Scripts\Invoke-ScriptBlock.ps1 -ComputerName SALAMESH -ScriptBlock { Get-Service | Where-Object { $_.Name -eq "WinRM" } } | Format-List


Name                : WinRM
DisplayName         : Gestion à distance de Windows (Gestion WSM)
Status              : Stopped
DependentServices   : {}
ServicesDependedOn  : {RPCSS, HTTP}
CanPauseAndContinue : False
CanShutdown         : False
CanStop             : False
ServiceType         : Win32ShareProcess



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

        [Parameter(Mandatory = $true)]
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


        Write-Output -InputObject "$($_.Exception.GetType())`n$($_.Exception.Message)"

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

        [Parameter(Mandatory = $true)]
        [String] $ComputerName
   
    )


    Try {


        [IO.Pipes.NamedPipeClientStream] $PipeClient = new-object System.IO.Pipes.NamedPipeClientStream($ComputerName, 'ScriptBlock', [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::None, [Security.Principal.TokenImpersonationLevel]::Anonymous)

        $PipeClient.Connect()

        Return $PipeClient


    } Catch {


        Write-Output "$($_.Exception.GetType())`n$($_.Exception.Message)"
        
        Return $null

        
    }

}




Function Create-PipeServer() {

    Param(

        [Parameter(Mandatory = $true)]
        [String] $ComputerName
   
    )


    Try {


        [Management.ManagementOptions] $ConnectionOptions = New-Object System.Management.ConnectionOptions
        
        $ConnectionOptions.Authentication = [Management.AuthenticationLevel]::Packet

        $ConnectionOptions.Impersonation = [Management.ImpersonationLevel]::Impersonate

        $ConnectionOptions.EnablePrivileges = $true

        [Management.ManagementScope] $ManagementScope = New-Object System.Management.ManagementScope

        $ManagementScope.Path = "\\$ComputerName\root\cimV2"

        $ManagementScope.Options = $ConnectionOptions

        [Management.ObjectGetOptions] $ObjectGetOptions = New-Object System.Management.ObjectGetOptions

        $ObjectGetOptions.Timeout = [TimeSpan]::MaxValue

        $ObjectGetOptions.UseAmendedQualifiers = $true

        [Management.ManagementClass] $ManagementClass = New-Object System.Management.ManagementClass

        $ManagementClass.Scope = $ManagementScope

        $ManagementClass.Path = "\\$ComputerName\root\cimV2:Win32_Process"

        $ManagementClass.Options = $ObjectGetOptions

        [ScriptBlock] $ScriptBlock = {$PipeServer = New-Object System.IO.Pipes.NamedPipeServerStream('ScriptBlock', [IO.Pipes.PipeDirection]::InOut); $PipeServer.WaitForConnection(); $PipeReader = New-Object System.IO.StreamReader($PipeServer); $PipeWriter = New-Object System.IO.StreamWriter($PipeServer); $PipeWriter.AutoFlush = $true; $Builder = [Text.StringBuilder]::new(); [Void]$Builder.AppendLine('Try {'); While ( ($Incoming = $PipeReader.ReadLine()) -ne '---EOS---') {  [Void]$Builder.AppendLine($Incoming) }; [Void]$Builder.AppendLine('} Catch { $_.Exception.Message }'); $NewPowerShell = [PowerShell]::Create().AddScript([Scriptblock]::Create($Builder.ToString())); $NewRunspace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace(); $NewRunspace.ApartmentState = [Threading.ApartmentState]::STA; $NewPowerShell.Runspace = $NewRunspace; $NewPowerShell.Runspace.Open(); $Invoke = $NewPowerShell.BeginInvoke(); $Result = $NewPowerShell.EndInvoke($Invoke); $Serialized = [Management.Automation.PSSerializer]::Serialize($result); $PipeWriter.WriteLine($Serialized); $PipeWriter.WriteLine('---EOS---'); $PipeWriter.Dispose(); $PipeReader.Dispose(); $PipeServer.Close(); $PipeServer.Dispose()}

        [String] $Command = "&{ $($ScriptBlock.ToString()) }"

        [String] $CmdLine = "PowerShell.exe -command $Command"

        [Management.ManagementBaseObject] $Process = $ManagementClass.Create($CmdLine)
        
        Return $Process


    } Catch {


        Write-Output -InputObject "$($_.Exception.GetType())`n$($_.Exception.Message)"

        Return $null

        
    } Finally {


        foreach ($Disposable in @($ManagementClass, $Process)) {

            if ($null -ne $Disposable) {
   
                [Void] $Disposable.Dispose() 
                    
            }

        }

    }

}




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




if (([Security.Principal.WindowsPrincipal]::New([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {


    if (Is-Online -ComputerName $ComputerName) {


        if ($null -ne (Create-PipeServer -ComputerName $ComputerName)) {


            [IO.Pipes.NamedPipeClientStream] $PipeClient = Create-PipeClient -ComputerName $ComputerName


            if (($null -ne $PipeClient) -and ($PipeClient.IsConnected)) {  
           

                $Return = [Management.Automation.PSSerializer]::Deserialize((Invoke-ScriptBlock -PipeClient $PipeClient -ScriptBlock $ScriptBlock))


                [Void] $PipeClient.Dispose()


                Return $Return


            } else {


                Return $null


            }


        } else {


            Return $null

        }


    }  else {

        Write-Output -InputObject "$ComputerName is not online"

    }
    

} else {

    Write-Output -InputObject "The requested operation requires elevation"

}
