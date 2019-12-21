
Param (

    [Parameter(Mandatory = $true)]
    [String] $SqlServer,

    [Parameter(Mandatory = $true)]
    [String] $Database,

    [Parameter(Mandatory = $true)]
    [String] $Query
   
)

$ConnectionString = "Data Source=$SqlServer;Initial Catalog=$Database;Integrated Security=True"

$Connection = New-Object -TypeName Data.SqlClient.SqlConnection

$Connection.ConnectionString = $ConnectionString
    
Try {

    $Connection.Open()

    $IsAbleToConnect = ($Connection.State -eq "Open")

} Catch {

    $IsAbleToConnect =  $false

}


if ($IsAbleToConnect) {

    Try {

        $SqlCommand = New-Object -TypeName Data.SqlClient.SqlCommand($Query, $Connection)
                   
        $DataSet = New-Object -TypeName Data.DataSet

        $DataAdapter = New-Object -TypeName Data.SqlClient.SqlDataAdapter($SqlCommand)

        $SqlResult = @{

            DataSet = $DataSet
            RecordCount = $DataAdapter.Fill($DataSet)
            Exception = [String]::Empty

        }

    } Catch {

        $SqlResult = @{

            DataSet = $null
            RecordCount = 0
            Exception = $_.Exception.Message

        }

    } Finally {

        if ($Connection.State -eq "Open") {

            $Connection.Close()

        }

    }

    if (![String]::IsNullOrEmpty($SqlResult.Exception)) {

        Write-Error -Message "[!] $($SqlResult.Exception)"

    } else {

        if ($SqlResult.RecordCount -gt 0) { 
    
            Return $SqlResult.DataSet.Tables[0].Rows

        } else {

            Write-Warning -Message "[!] No match"

        }

    }

} else {

    Write-Error -Message "[!] Unable to access SQL database"

}
