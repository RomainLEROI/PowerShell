
Param (

  [Parameter(Mandatory = $true)] 
  [String] $ComputerName,

  [Parameter(Mandatory = $true)] 
  [ScriptBlock] $ScriptBlock

)


Function Is-Online {

    Param (

        [Parameter(Mandatory = $true)]
        [String] $ComputerName
   
    )

    Try {

   
        $Result = Test-Connection -ComputerName $Computername -Count 1 -Quiet -ErrorAction SilentlyContinue

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

        Try {


            $ServerBlock = {$PipeServer = New-Object -TypeName IO.Pipes.NamedPipeServerStream('ScriptBlock', [IO.Pipes.PipeDirection]::InOut); $PipeServer.WaitForConnection(); $PipeReader = [IO.StreamReader]::new($PipeServer); $PipeWriter = [IO.StreamWriter]::new($PipeServer); $PipeWriter.AutoFlush = $true; $Builder = [Text.StringBuilder]::new(); [Void]$Builder.AppendLine('Try {'); [Void]$Builder.AppendLine([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($PipeReader.ReadLine()))); [Void]$Builder.AppendLine('} Catch { $_.Exception.Message }'); $NewPowerShell = [PowerShell]::Create().AddScript([Scriptblock]::Create($Builder.ToString())); $NewRunspace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace(); $NewRunspace.ApartmentState = [Threading.ApartmentState]::STA; $NewPowerShell.Runspace = $NewRunspace; $NewPowerShell.Runspace.Open(); $Invoke = $NewPowerShell.BeginInvoke(); $PipeWriter.WriteLine([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes([Management.Automation.PSSerializer]::Serialize($NewPowerShell.EndInvoke($Invoke))))); $PipeWriter.Dispose(); $PipeReader.Dispose(); $PipeServer.Close(); $PipeServer.Dispose(); $NewPowerShell.Runspace.Close(); $NewPowerShell.Runspace.Dispose(); $NewRunspace.Close(); $NewRunspace.Dispose(); $NewPowerShell.Dispose()}

            $Command = "&{ $($ServerBlock.ToString()) }"

            $CmdLine = "PowerShell.exe -command $Command"

            $PipeServer = Invoke-WmiMethod -ComputerName $ComputerName -Class Win32_Process -Name Create -ArgumentList $CmdLine
        
        } Catch {


            Write-Error -Message "$($_.Exception.GetType())`n$($_.Exception.Message)"

            $PipeServer = $null

        
        }


        if ($null -ne $PipeServer) {

            Try {


                $PipeClient = New-Object -TypeName IO.Pipes.NamedPipeClientStream($ComputerName, 'ScriptBlock', [IO.Pipes.PipeDirection]::InOut)

                $PipeClient.Connect()

            } Catch {


                Write-Error -Message "$($_.Exception.GetType())`n$($_.Exception.Message)"
        
                $PipeClient = $null

        
            }


            if (($null -ne $PipeClient) -and ($PipeClient.IsConnected)) {  

                Try {

                    $PipeReader = New-Object -TypeName IO.StreamReader($PipeClient)

                    $PipeWriter = New-Object -TypeName IO.StreamWriter($PipeClient)

                    $PipeWriter.AutoFlush = $true

                    $PipeWriter.WriteLine([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ScriptBlock.ToString())))
           
                    $Result =  [Management.Automation.PSSerializer]::Deserialize([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($PipeReader.ReadLine())))

                    Return $Result

                } Catch {


                    Write-Error -Message "$($_.Exception.GetType())`n$($_.Exception.Message)"


                } Finally {


                    foreach ($Disposable in @($PipeWriter, $PipeReader, $PipeClient)) {

                        if ($null -ne $Disposable) {

                            [Void] $Disposable.Dispose()

                        }

                    }

                }

                

            }

        }

    }  else {

        Write-Warning -Message "$ComputerName is not online"

    }
    
} else {

    Write-Warning -Message "The requested operation requires elevation"

}
