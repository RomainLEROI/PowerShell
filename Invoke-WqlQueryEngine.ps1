
Param ( 

    [Parameter(Mandatory = $true)]
    [String] $Query
   
)


[Void] [Reflection.Assembly]::LoadFile("${env:ProgramFiles(x86)}\Microsoft Configuration Manager\AdminConsole\bin\AdminUI.WqlQueryEngine.dll")
[Void] [Reflection.Assembly]::LoadFile("${env:ProgramFiles(x86)}\Microsoft Configuration Manager\AdminConsole\bin\Microsoft.ConfigurationManagement.ManagementProvider.dll")

$WqlConnectionManager = New-Object -TypeName Microsoft.ConfigurationManagement.ManagementProvider.WqlQueryEngine.WqlConnectionManager 
$CmClient = New-Object -ComObject "Microsoft.SMS.Client"

if ($WqlConnectionManager.Connect($CmClient.GetCurrentManagementPoint())) 
{ 

    Try {

        $Object = $WqlConnectionManager.QueryProcessor.ExecuteQuery($Query).GetEnumerator() | Select-Object -Index 0

        $DataTable = New-Object -TypeName Data.DataTable "WqlQueryResult" 

        if ($null -ne $Object) {

            foreach ($WmiClass in $Object.PropertyNames) {

                foreach ($Property in $Object.Generics[$WmiClass].PropertyNames) {
            
                       [Void] $DataTable.Columns.Add($Property, [String])
                   
                }

            }

        }

        $QueryResults = $WqlConnectionManager.QueryProcessor.ExecuteQuery($Query) 

        foreach ($QueryResult in $QueryResults.GetEnumerator()) {  

            $Row = $DataTable.NewRow()

            foreach ($WmiClass in $QueryResult.PropertyNames) {

                foreach ($Property in $Object.Generics[$WmiClass].PropertyNames) {

                    $Row.$Property = ($QueryResult.get_Item($WmiClass).ObjectValue).$Property

                }

            }

            $DataTable.Rows.Add($Row)

        } 

        $WqlResult = @{

            DataTable = $DataSet
            RecordCount = $DataTable.Rows.Count
            Exception = [String]::Empty

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
