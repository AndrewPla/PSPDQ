function Get-PDQComputerApplications {
    <#
    .SYNOPSIS
        Returns applications installed on target machine or all machines with application installed
    
    .DESCRIPTION
        Returns applications installed on target machine or all machines with application installed
        
    .EXAMPLE
        Get-PDQComputerApplications -Computer WK01
        Returns applications installed on WK01

    .EXAMPLE
        Get-PDQComputerApplications -Application Chrome
        Returns a list of machines with an application installed matching "Chrome"
    
    .NOTES
        Author: Chris Bayliss
        Version: 1.0
        Date: 12/05/2019
    #>
    
    [CmdletBinding(SupportsShouldProcess = $True)]
    param (
        # Target computer to return applications for
        [Parameter(Mandatory = $false, 
        ValueFromPipelineByPropertyName, 
        ParameterSetName = 'Comp',
        Position = 0)] 
        [string[]][alias('Name')]$Computer,

        # Application to search for
        [Parameter(Mandatory = $false, 
        ValueFromPipelineByPropertyName,
        ParameterSetName = 'App')]
        [string[]][alias('PackageName')]$Application
    )

    process {
        if (!(Test-Path -Path "$($env:AppData)\pspdq\config.json")) {
            Throw "PSPDQ Configuration file not found in `"$($env:AppData)\pspdq\config.json`", please run Set-PSPDQConfig to configure module settings."
        } else {
            $config = Get-Content "$($env:AppData)\pspdq\config.json" | ConvertFrom-Json

            $Server = $config.Server.PDQInventoryServer
            $DatabasePath = $config.DBPath.PDQInventoryDB
        }

        $results = @()

        if ($PSCmdlet.ParameterSetName -eq 'Comp') {
            foreach ($Comp in $Computer) {
                $sql = "SELECT Applications.ComputerId, Computers.Name, Applications.Name, Applications.Publisher, Applications.Version, Applications.InstallDate, Applications.Uninstall
                FROM Applications
                INNER JOIN Computers ON Computers.ComputerId = Applications.ComputerId
                WHERE Applications.ComputerId IN (
                SELECT ComputerId
                FROM Computers
                WHERE Name LIKE '%%$Comp%%'
                )"

                $results += Invoke-Command -Computer $Server -ScriptBlock { $args[0] | sqlite3.exe $args[1] } -ArgumentList $sql, $DatabasePath
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'App') {
            foreach ($App in $Application) {
                $sql = "SELECT Applications.ComputerId, Computers.Name, Applications.Name, Applications.Publisher, Applications.Version, Applications.InstallDate, Applications.Uninstall 
                FROM Applications
                INNER JOIN Computers ON Computers.ComputerId = Applications.ComputerId
                WHERE Applications.Name LIKE '%%$App%%'"
                
                $results += Invoke-Command -Computer $Server -ScriptBlock { $args[0] | sqlite3.exe $args[1] } -ArgumentList $sql, $DatabasePath
            }
        }
        
        $results | ForEach-Object {
                $p = $_ -split '\|'
                [PSCustomObject]@{
                    ComputerId   = $p[0]
                    ComputerName = $p[1]
                    AppName      = $p[2]
                    Publisher    = $p[3]
                    Version      = $p[4]
                    InstallDate  = $p[5]
                    Uninstall    = $p[6]
                }            
        }

        return $appsParsed
    }
}
