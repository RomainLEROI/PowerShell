
Param ( 

    [Parameter(Mandatory = $true)]
    [String] $Query
   
)


[Void] [Reflection.Assembly]::LoadFile("${env:ProgramFiles(x86)}\Microsoft Configuration Manager\AdminConsole\bin\AdminUI.WqlQueryEngine.dll")
[Void] [Reflection.Assembly]::LoadFile("${env:ProgramFiles(x86)}\Microsoft Configuration Manager\AdminConsole\bin\Microsoft.ConfigurationManagement.ManagementProvider.dll")

$WqlConnectionManager = New-Object -TypeName Microsoft.ConfigurationManagement.ManagementProvider.WqlQueryEngine.WqlConnectionManager 
$CmClient = New-Object -ComObject "Microsoft.SMS.Client"

if ($WqlConnectionManager.Connect($CmClient.GetCurrentManagementPoint())) { 

    Try {

        $Object = $WqlConnectionManager.QueryProcessor.ExecuteQuery($Query).GetEnumerator() | Select-Object -Index 0

        if ($null -ne $Object) {

            $DataTable = New-Object -TypeName Data.DataTable "WqlQueryResult" 

            if ($Object.OverridingObjectClass -eq "__GENERIC") {

                foreach ($WmiClass in $Object.PropertyNames) {

                    foreach ($Property in $Object.Generics[$WmiClass].PropertyNames) {  

                        [Void] $DataTable.Columns.Add("$WmiClass.$Property", [String])
                   
                    }

                }

                $QueryResults = $WqlConnectionManager.QueryProcessor.ExecuteQuery($Query) 

                $QueryResults.GetEnumerator() | ForEach-Object {  

                    $Row = $DataTable.NewRow()

                    foreach ($WmiClass in $_.PropertyNames) {

                        foreach ($Property in $Object.Generics[$WmiClass].PropertyNames) {

                            $Row."$WmiClass.$Property" = ($_.get_Item($WmiClass).ObjectValue).$Property

                        }

                    }

                    $DataTable.Rows.Add($Row)

                } 

            } else {

                foreach ($Property in $Object.PropertyNames) {
		    # TO DO : Cast types            		
                    [Void] $DataTable.Columns.Add($Property, [String])
                   
                }

                $QueryResults = $WqlConnectionManager.QueryProcessor.ExecuteQuery($Query) 

                $QueryResults.GetEnumerator() | ForEach-Object { 

                    $Row = $DataTable.NewRow()

                    foreach ($Item in ($_.PropertyList).GetEnumerator()) {
	
                        $Row.($Item.Key) = $Item.Value
	
                    }

                    $DataTable.Rows.Add($Row)

                }
    
            }
     
            $WqlResult = @{

                DataTable = $DataTable
                RecordCount = $DataTable.Rows.Count
                Exception = [String]::Empty

            }

        } else {

            $WqlResult = @{

                DataTable = $null
                RecordCount = 0
                Exception = "Failed to create columns"

            }

        }

    } Catch {

        $WqlResult = @{

            DataTable = $null
            RecordCount = 0
            Exception = $_.Exception.Message

        }

    } Finally {

        $WqlConnectionManager.Close()

    }

    if (![String]::IsNullOrEmpty($WqlResult.Exception)) {

        Write-Error -Message "[!] $($WqlResult.Exception)"

    } else {

        if ($WqlResult.RecordCount -gt 0) { 
    
            Return $WqlResult

        } else {

            Write-Warning -Message "[!] No match"

        }

    }

} else {

    Write-Error -Message "[!] Unable to access current management point"

}
