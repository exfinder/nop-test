$temp = "temp"
$mediaPath = Join-Path (Convert-Path .) $temp
$initialFile = Join-Path $mediaPath "SQLServer2017-SSEI-Expr.exe"
$latestUpdateFile = Join-Path $mediaPath "SQLServer2017-KB4515579-x64.exe"
$mediaFile = Join-Path $mediaPath "SQLEXPRADV_x64_ENU.exe"
$extractedMediaPath = Join-Path $mediaPath "SQLEXPRADV_x64_ENU"
$setupFile = Join-Path $extractedMediaPath "SETUP.EXE"

mkdir $temp -ea 0

Import-Module BitsTransfer

# download SQL Expr installer
$url = "https://download.microsoft.com/download/5/E/9/5E9B18CC-8FD5-467E-B5BF-BADE39C51F73/SQLServer2017-SSEI-Expr.exe"
Start-BitsTransfer -Source $url -Destination $mediaPath

# download SQL Expr latest cumulative update installer
$url = "https://download.microsoft.com/download/C/4/F/C4F908C9-98ED-4E5F-88D5-7D6A5004AEBD/SQLServer2017-KB4515579-x64.exe"
Start-BitsTransfer -Source $url -Destination $mediaPath

# download full SQL Expr  media archive
& $initialFile Action=Download /Quiet /HideProgressBar /Verbose /ENU /Language=en-US /MediaType=Advanced /MediaPath=$mediaPath | Out-Default

# extract SQL Expr media archive
& $mediaFile /u /x:$extractedMediaPath | Out-Default

# run SQL Expr setup: SQLEngine and FullText features only
& $setupFile /QS /ACTION=Install /FEATURES=SQLEngine,FullText /INSTANCENAME=MSSQLSERVER /ENU /UpdateEnabled=1 /SQLSVCACCOUNT="NT AUTHORITY\Network Service" /ADDCURRENTUSERASSQLADMIN /SECURITYMODE=SQL /SAPWD="Ghjuhfvvth)81" /INSTALLSQLDATADIR="c:\data" /TCPENABLED=1 /INDICATEPROGRESS /IACCEPTSQLSERVERLICENSETERMS

# run SQL Expr latest patch
& $latestUpdateFile /QS /ACTION=Patch /INSTANCENAME=MSSQLSERVER /INDICATEPROGRESS /IACCEPTSQLSERVERLICENSETERMS | Out-Default

# delete temporary install files
Remove-Item -Recurse -Force $mediaPath

# restart SQL related services
Set-Service -Name SQLBrowser -StartupType Automatic
Set-Service -Name MSSQLFDLauncher -StartupType Automatic
Start-Service MSSQLSERVER
Start-Service SQLBrowser
Start-Service MSSQLFDLauncher

# new firewall rule: allow inbound connection for MSSQLSERVER service
New-NetFirewallRule -DisplayName "MSSQLSERVER" -Direction Inbound -Service MSSQLSERVER -Action Allow

# install web related features: IIS web server, web management service, etc.
Install-WindowsFeature -Name Web-Server, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Dyn-Compression, Web-Basic-Auth, Web-Windows-Auth, Web-Mgmt-Service

# enable remote management for web mgmt service
Set-ItemProperty -Path  HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name EnableRemoteManagement  -Value 1

# new firewall rule: allow inbound connection for web management service
New-NetFirewallRule -DisplayName "Web Management Service" -Direction Inbound -Service wmsvc -Action Allow

# install Chocolatey package manager https://chocolatey.org/
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# install Microsoft .NET Core Runtime - Windows Server Hosting 2.2.7
choco install dotnetcore-windowshosting --version=2.2.7 -y

# install Web Deploy
choco install webdeploy -y

# restart web related services
Restart-Service MsDepSvc
Restart-Service wmsvc
Restart-Service w3svc

# create IIS app pool
New-WebAppPool AspNetCoreAppPool
Set-ItemProperty IIS:\AppPools\AspNetCoreAppPool managedRuntimeVersion ""
Set-ItemProperty IIS:\AppPools\AspNetCoreAppPool enable32BitAppOnWin64 true
Set-ItemProperty IIS:\AppPools\AspNetCoreAppPool startMode AlwaysRunning
Set-ItemProperty "IIS:\Sites\Default Web Site" applicationPool AspNetCoreAppPool
Remove-WebAppPool DefaultAppPool

# download and run this script from github
# Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/exfinder/nop-test/master/script.ps1'))