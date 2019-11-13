
Param (

  [Parameter(Mandatory = $true)] 
  [String] $ComputerName,

  [Parameter(Mandatory = $true)] 
  [ScriptBlock] $ScriptBlock

)


Function Invoke-ScriptBlock {

    Param (

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


Function Create-PipeClient {

    Param (

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


Function Create-PipeServer {

    Param (

        [Parameter(Mandatory = $true)]
        [String] $ComputerName
   
    )

    Try {


        [ScriptBlock] $ScriptBlock = {$PipeServer = [IO.Pipes.NamedPipeServerStream]::new('ScriptBlock', [IO.Pipes.PipeDirection]::InOut); $PipeServer.WaitForConnection(); $PipeReader = [IO.StreamReader]::new($PipeServer); $PipeWriter = [IO.StreamWriter]::new($PipeServer); $PipeWriter.AutoFlush = $true; $Builder = [Text.StringBuilder]::new(); [Void]$Builder.AppendLine('Try {'); [Void]$Builder.AppendLine([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($PipeReader.ReadLine()))); [Void]$Builder.AppendLine('} Catch { $_.Exception.Message }'); $NewPowerShell = [PowerShell]::Create().AddScript([Scriptblock]::Create($Builder.ToString())); $NewRunspace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace(); $NewRunspace.ApartmentState = [Threading.ApartmentState]::STA; $NewPowerShell.Runspace = $NewRunspace; $NewPowerShell.Runspace.Open(); $Invoke = $NewPowerShell.BeginInvoke(); $PipeWriter.WriteLine([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes([Management.Automation.PSSerializer]::Serialize($NewPowerShell.EndInvoke($Invoke))))); $PipeWriter.Dispose(); $PipeReader.Dispose(); $PipeServer.Close(); $PipeServer.Dispose(); $NewPowerShell.Runspace.Close(); $NewPowerShell.Runspace.Dispose(); $NewRunspace.Close(); $NewRunspace.Dispose(); $NewPowerShell.Dispose()}

        [String] $Command = "&{ $($ScriptBlock.ToString()) }"

        [String] $CmdLine = "PowerShell.exe -command $Command"

        [Management.ManagementBaseObject] $Process = Invoke-WmiMethod -ComputerName $ComputerName -Class Win32_Process -Name Create -ArgumentList $CmdLine
        
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


Function Is-Online {

    Param (

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


Function Is-LocalHost {

    Param (

        [Parameter(Mandatory = $true)]
        [String] $ComputerName

    
    )

    switch ($true) {

        ($ComputerName -eq $env:COMPUTERNAME) {

            Return $true

        } ($ComputerName -eq 'localhost') {

            Return $true

        } ($ComputerName -eq '.') {

            Return $true

        } Default {

            Return $false

        }

    }

}


if (([Security.Principal.WindowsPrincipal]::New([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {


    if ((Is-LocalHost -ComputerName $ComputerName) -or (Is-Online -ComputerName $ComputerName)) {


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
