# Proxmox PaaS Helper Functions
# Load with: . .\paas-helpers.ps1

$PaasApiUrl = "http://192.168.171.140:5000"

function Deploy-PaasApp {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Repo,
        
        [string]$Framework = "python"
    )
    
    $body = @{
        name = $Name
        repo = $Repo
        framework = $Framework
    } | ConvertTo-Json
    
    Write-Host "[*] Deploying $Name from $Repo..." -ForegroundColor Cyan
    
    $result = Invoke-RestMethod -Uri "$PaasApiUrl/deploy" `
        -Method POST `
        -ContentType "application/json" `
        -Body $body
    
    Write-Host "[+] Deployment initiated!" -ForegroundColor Green
    Write-Host "    Container ID: $($result.ctid)" -ForegroundColor Yellow
    Write-Host "    IP Address: $($result.ip)" -ForegroundColor Yellow
    Write-Host "    URL: $($result.url)" -ForegroundColor Yellow
    
    Write-Host "`n[*] Waiting 60 seconds for installation..." -ForegroundColor Cyan
    Start-Sleep -Seconds 60
    
    Write-Host "[*] Testing deployment..." -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest -Uri $result.url -TimeoutSec 10
        Write-Host "[+] App is running! Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "`nResponse:" -ForegroundColor Yellow
        Write-Host $response.Content
    } catch {
        Write-Host "[!] App not responding yet. Wait a bit longer or check logs." -ForegroundColor Yellow
        Write-Host "    Try: Test-PaasApp -ContainerId $($result.ctid)" -ForegroundColor Gray
    }
    
    return $result
}

function Get-PaasContainers {
    Write-Host "[*] Fetching containers..." -ForegroundColor Cyan
    $result = Invoke-RestMethod -Uri "$PaasApiUrl/list"
    Write-Host $result.containers
}

function Get-PaasStatus {
    param(
        [Parameter(Mandatory=$true)]
        [int]$ContainerId
    )
    
    Write-Host "[*] Checking status of container $ContainerId..." -ForegroundColor Cyan
    $result = Invoke-RestMethod -Uri "$PaasApiUrl/status/$ContainerId"
    $color = if($result.status -match "running"){"Green"}else{"Yellow"}
    Write-Host "Status: $($result.status)" -ForegroundColor $color
}

function Remove-PaasApp {
    param(
        [Parameter(Mandatory=$true)]
        [int]$ContainerId
    )
    
    $confirm = Read-Host "Are you sure you want to delete container $ContainerId? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "[!] Cancelled" -ForegroundColor Yellow
        return
    }
    
    Write-Host "[*] Deleting container $ContainerId..." -ForegroundColor Red
    $result = Invoke-RestMethod -Uri "$PaasApiUrl/delete/$ContainerId" -Method DELETE
    Write-Host "[+] Container deleted!" -ForegroundColor Green
}

function Test-PaasApp {
    param(
        [Parameter(Mandatory=$true)]
        [int]$ContainerId
    )
    
    $ip = "192.168.171.$($ContainerId - 100)"
    $url = "http://${ip}:8000"
    
    Write-Host "[*] Testing app at $url..." -ForegroundColor Cyan
    
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 5
        Write-Host "[+] Success! Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "`nResponse:" -ForegroundColor Yellow
        Write-Host $response.Content
    } catch {
        Write-Host "[!] Failed to connect" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Show-PaasHelp {
    Write-Host "`n=== Proxmox PaaS Helper Commands ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Deploy-PaasApp" -ForegroundColor Yellow -NoNewline
    Write-Host " -Name my-app -Repo https://github.com/user/repo"
    Write-Host "  Deploy a new application from GitHub`n"
    
    Write-Host "Get-PaasContainers" -ForegroundColor Yellow
    Write-Host "  List all deployed containers`n"
    
    Write-Host "Get-PaasStatus" -ForegroundColor Yellow -NoNewline
    Write-Host " -ContainerId 301"
    Write-Host "  Check container status`n"
    
    Write-Host "Test-PaasApp" -ForegroundColor Yellow -NoNewline
    Write-Host " -ContainerId 301"
    Write-Host "  Test if app is responding`n"
    
    Write-Host "Remove-PaasApp" -ForegroundColor Yellow -NoNewline
    Write-Host " -ContainerId 301"
    Write-Host "  Delete a container`n"
    
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  Deploy-PaasApp -Name my-flask-app -Repo https://github.com/mouones/test"
    Write-Host "  Get-PaasContainers"
    Write-Host "  Test-PaasApp -ContainerId 301"
    Write-Host ""
}

Write-Host "`n[+] Proxmox PaaS helpers loaded!" -ForegroundColor Green
Write-Host "Type " -NoNewline
Write-Host "Show-PaasHelp" -ForegroundColor Yellow -NoNewline
Write-Host " to see available commands`n"
