<#
    .SYNOPSIS
       Upload Install Sitecore Package
       
    .DESCRIPTION
        This script upload the Sitecore package and install it into Sitecore.
        By default, packages are saved to disk at C:\inetpub\wwwroot\App_Data\packages.
    
    .NOTES
        Akash Borkar 
#>



$filepath =  Receive-File -Path "C:\inetpub\wwwroot\App_Data\packages\"
Write-Host "Uploaded package Succesfully : " $filepath
# get file size in MB in PowerShell   
$size = (Get-Item -Path $filepath).Length/1MB
Write-Host $size "MB"
Write-Host "Installation Started......"
Install-Package -Path $filepath -InstallMode Merge -MergeMode Merge
Write-Host "Installation Completed - Package installed successfully"
