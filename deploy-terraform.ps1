# Terraform Quick Deploy Script for Proxmox PaaS
# This script helps you quickly deploy containers using Terraform

param(
    [Parameter(Mandatory=$false)]
    [string]$Action = "help",
    
    [Parameter(Mandatory=$false)]
    [string[]]$Frameworks = @(),
    
    [Parameter(Mandatory=$false)]
    [switch]$All,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove
)

$TerraformDir = "$PSScriptRoot\terraform"

function Show-Help {
    Write-Host @"
🚀 Terraform Proxmox PaaS Deployment Tool

USAGE:
    .\deploy-terraform.ps1 -Action <action> [options]

ACTIONS:
    init           Initialize Terraform (first time setup)
    plan           Show what will be deployed
    deploy         Deploy infrastructure
    destroy        Remove infrastructure
    output         Show deployment outputs
    status         Show Terraform state
    help           Show this help message

OPTIONS:
    -Frameworks    Specific frameworks to target (e.g., flask,django,express)
    -All           Target all frameworks
    -AutoApprove   Skip confirmation prompts

EXAMPLES:
    # Initialize Terraform
    .\deploy-terraform.ps1 -Action init

    # Plan deployment for all frameworks
    .\deploy-terraform.ps1 -Action plan -All

    # Deploy Flask and Django
    .\deploy-terraform.ps1 -Action deploy -Frameworks flask,django

    # Deploy all frameworks with auto-approve
    .\deploy-terraform.ps1 -Action deploy -All -AutoApprove

    # Show outputs
    .\deploy-terraform.ps1 -Action output

    # Destroy specific frameworks
    .\deploy-terraform.ps1 -Action destroy -Frameworks flask,django

AVAILABLE FRAMEWORKS:
    flask, django, fastapi, express, nextjs, laravel, go, rust, ruby, nginx

"@
}

function Initialize-Terraform {
    Write-Host "🔧 Initializing Terraform..." -ForegroundColor Cyan
    
    if (-not (Test-Path $TerraformDir)) {
        Write-Host "❌ Terraform directory not found: $TerraformDir" -ForegroundColor Red
        exit 1
    }
    
    Set-Location $TerraformDir
    
    # Check if terraform.tfvars exists
    if (-not (Test-Path "terraform.tfvars")) {
        Write-Host "⚠️  terraform.tfvars not found. Creating from example..." -ForegroundColor Yellow
        Copy-Item "terraform.tfvars.example" "terraform.tfvars"
        Write-Host "📝 Please edit terraform.tfvars with your Proxmox credentials before deploying" -ForegroundColor Yellow
    }
    
    terraform init
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Terraform initialized successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Terraform initialization failed!" -ForegroundColor Red
        exit 1
    }
}

function Build-TargetArgs {
    param($Frameworks)
    
    $targets = @()
    foreach ($fw in $Frameworks) {
        $targets += "-target=proxmox_lxc.app_container[`"$fw`"]"
    }
    return $targets -join " "
}

function Invoke-TerraformPlan {
    Write-Host "📋 Planning deployment..." -ForegroundColor Cyan
    Set-Location $TerraformDir
    
    $cmd = "terraform plan"
    
    if ($Frameworks.Count -gt 0) {
        $targetArgs = Build-TargetArgs $Frameworks
        $cmd += " $targetArgs"
        Write-Host "🎯 Targeting frameworks: $($Frameworks -join ', ')" -ForegroundColor Yellow
    } elseif ($All) {
        Write-Host "🎯 Targeting all frameworks" -ForegroundColor Yellow
    }
    
    Invoke-Expression $cmd
}

function Invoke-TerraformDeploy {
    Write-Host "🚀 Deploying infrastructure..." -ForegroundColor Cyan
    Set-Location $TerraformDir
    
    $cmd = "terraform apply"
    
    if ($Frameworks.Count -gt 0) {
        $targetArgs = Build-TargetArgs $Frameworks
        $cmd += " $targetArgs"
        Write-Host "🎯 Targeting frameworks: $($Frameworks -join ', ')" -ForegroundColor Yellow
    } elseif ($All) {
        Write-Host "🎯 Targeting all frameworks" -ForegroundColor Yellow
    }
    
    if ($AutoApprove) {
        $cmd += " -auto-approve"
    }
    
    Invoke-Expression $cmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Deployment completed successfully!" -ForegroundColor Green
        Write-Host "`n📊 Container URLs:" -ForegroundColor Cyan
        terraform output container_urls
    } else {
        Write-Host "`n❌ Deployment failed!" -ForegroundColor Red
        exit 1
    }
}

function Invoke-TerraformDestroy {
    Write-Host "🗑️  Destroying infrastructure..." -ForegroundColor Yellow
    Set-Location $TerraformDir
    
    $cmd = "terraform destroy"
    
    if ($Frameworks.Count -gt 0) {
        $targetArgs = Build-TargetArgs $Frameworks
        $cmd += " $targetArgs"
        Write-Host "🎯 Targeting frameworks: $($Frameworks -join ', ')" -ForegroundColor Yellow
    } elseif ($All) {
        Write-Host "🎯 Targeting all frameworks" -ForegroundColor Yellow
    }
    
    if ($AutoApprove) {
        $cmd += " -auto-approve"
    }
    
    Invoke-Expression $cmd
}

function Show-TerraformOutput {
    Write-Host "📊 Terraform Outputs:" -ForegroundColor Cyan
    Set-Location $TerraformDir
    terraform output
}

function Show-TerraformStatus {
    Write-Host "📊 Terraform State:" -ForegroundColor Cyan
    Set-Location $TerraformDir
    
    Write-Host "`n📦 Resources:" -ForegroundColor Yellow
    terraform state list
    
    Write-Host "`n📊 Summary:" -ForegroundColor Yellow
    terraform show -json | ConvertFrom-Json | Select-Object -ExpandProperty values | Select-Object -ExpandProperty root_module | Select-Object -ExpandProperty resources | Format-Table type, name, @{Label="Address";Expression={$_.address}} -AutoSize
}

# Main execution
switch ($Action.ToLower()) {
    "init" {
        Initialize-Terraform
    }
    "plan" {
        Invoke-TerraformPlan
    }
    "deploy" {
        Invoke-TerraformDeploy
    }
    "destroy" {
        Invoke-TerraformDestroy
    }
    "output" {
        Show-TerraformOutput
    }
    "status" {
        Show-TerraformStatus
    }
    "help" {
        Show-Help
    }
    default {
        Write-Host "❌ Unknown action: $Action" -ForegroundColor Red
        Show-Help
        exit 1
    }
}
