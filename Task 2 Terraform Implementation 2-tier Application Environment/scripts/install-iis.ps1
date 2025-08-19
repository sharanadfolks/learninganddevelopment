# install-iis.ps1
# Run as Administrator

Write-Output "=== Starting IIS installation ==="

# Install IIS and required features (reboot if needed)
Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools 

# Optional: ASP.NET & .NET (many apps need this)
Install-WindowsFeature Web-Asp-Net45
Install-WindowsFeature NET-Framework-Features

# Define path for default site
$sitePath = "C:\inetpub\wwwroot"

# Create index.html
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Sharan's Server</title>
</head>
<body style="font-family:Arial; text-align:center; margin-top:100px;">
    <h1>This is Sharan's server</h1>
</body>
</html>
"@

Set-Content -Path "$sitePath\index.html" -Value $htmlContent -Encoding UTF8 -Force

Write-Output "=== IIS installed and sample page deployed at http://localhost ==="

exit 0
