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
>> Get-WindowsDriver -Online | Where-Object { $_.Driver -eq "oem91.inf" }
>> }


Driver           : oem91.inf
OriginalFileName : C:\Windows\System32\DriverStore\FileRepository\prnms009.inf_amd64_5887f9f923285dd6\prnms009.inf
Inbox            : False
ClassName        : Printer
BootCritical     : False
ProviderName     : Microsoft
Date             : 21/06/2006 00:00:00
Version          : 10.0.17134.1


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


        [IO.StreamReader] $PipeReader = [IO.StreamReader]::new($PipeClient)

        [IO.StreamWriter] $PipeWriter = [IO.StreamWriter]::new($PipeClient)

        $PipeWriter.AutoFlush = $true

        $PipeWriter.WriteLine([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ScriptBlock.ToString())))
           
        Return [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($PipeReader.ReadLine()))


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


        [IO.Pipes.NamedPipeClientStream] $PipeClient = [IO.Pipes.NamedPipeClientStream]::new($ComputerName, 'ScriptBlock', [IO.Pipes.PipeDirection]::InOut)

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


        [Management.ManagementOptions] $ConnectionOptions = [Management.ConnectionOptions]::new()
        
        $ConnectionOptions.Authentication = [Management.AuthenticationLevel]::Packet

        $ConnectionOptions.Impersonation = [Management.ImpersonationLevel]::Impersonate

        $ConnectionOptions.EnablePrivileges = $true

        [Management.ManagementScope] $ManagementScope = [Management.ManagementScope]::new()

        $ManagementScope.Path = "\\$ComputerName\root\cimV2"

        $ManagementScope.Options = $ConnectionOptions

        [Management.ObjectGetOptions] $ObjectGetOptions = [Management.ObjectGetOptions]::new()

        $ObjectGetOptions.Timeout = [TimeSpan]::MaxValue

        $ObjectGetOptions.UseAmendedQualifiers = $true

        [Management.ManagementClass] $ManagementClass = [Management.ManagementClass]::new()

        $ManagementClass.Scope = $ManagementScope

        $ManagementClass.Path = "\\$ComputerName\root\cimV2:Win32_Process"

        $ManagementClass.Options = $ObjectGetOptions

        [ScriptBlock] $ScriptBlock = {$PipeServer = [IO.Pipes.NamedPipeServerStream]::new('ScriptBlock', [IO.Pipes.PipeDirection]::InOut); $PipeServer.WaitForConnection(); $PipeReader = [IO.StreamReader]::new($PipeServer); $PipeWriter = [IO.StreamWriter]::new($PipeServer);$PipeWriter.AutoFlush = $true; $Builder = [Text.StringBuilder]::new(); [Void]$Builder.AppendLine('Try {'); [Void]$Builder.AppendLine([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($PipeReader.ReadLine()))); [Void]$Builder.AppendLine('} Catch { $_.Exception.Message }'); $NewPowerShell = [PowerShell]::Create().AddScript([Scriptblock]::Create($Builder.ToString())); $NewRunspace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace(); $NewRunspace.ApartmentState = [Threading.ApartmentState]::STA; $NewPowerShell.Runspace = $NewRunspace; $NewPowerShell.Runspace.Open(); $Invoke = $NewPowerShell.BeginInvoke(); $PipeWriter.WriteLine([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes([Management.Automation.PSSerializer]::Serialize($NewPowerShell.EndInvoke($Invoke))))); $PipeWriter.Dispose(); $PipeReader.Dispose(); $PipeServer.Close(); $PipeServer.Dispose(); $NewPowerShell.Runspace.Close(); $NewPowerShell.Runspace.Dispose(); $NewRunspace.Close(); $NewRunspace.Dispose(); $NewPowerShell.Dispose()}

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
