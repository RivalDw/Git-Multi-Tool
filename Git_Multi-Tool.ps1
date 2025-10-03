# Git Multi-Tool - PowerShell Version

function Show-Menu {
    param([string]$Title, [string[]]$Options)
    Write-Host "`n===== $Title =====" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Options.Length; $i++) {
        Write-Host "$($i+1). $($Options[$i])"
    }
}

function Get-UserChoice {
    param([string]$Prompt, [int]$Default = 1, [int]$MaxChoice)
    $choice = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($choice)) { return $Default }
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $MaxChoice) {
        return [int]$choice
    } else {
        Write-Host "Invalid choice!" -ForegroundColor Red
        return $null
    }
}

function Initialize-Config {
    $configPath = "git_tool_config.txt"
    if (Test-Path $configPath) { return Get-Content $configPath | Select-Object -First 1 }

    $username = $env:USERNAME
    $defaultReposPath = "C:\Users\$username\OneDrive\Documents\rep"

    Write-Host "`nFirst time setup: Enter your repositories folder" -ForegroundColor Yellow
    Write-Host "Detected user: $username" -ForegroundColor Gray
    Write-Host "Default path: $defaultReposPath" -ForegroundColor Gray

    Show-Menu "Path Selection" @("Use default path", "Enter custom path")
    $pathChoice = Get-UserChoice "Enter choice" 1 2
    if ($pathChoice -eq 1) { $reposFolder = $defaultReposPath } else { $reposFolder = Read-Host "Enter custom repositories path" }

    if ([string]::IsNullOrWhiteSpace($reposFolder)) {
        Write-Host "Path cannot be empty!" -ForegroundColor Red
        pause; exit
    }

    $reposFolder | Out-File $configPath -Encoding UTF8
    Write-Host "Path saved for future use." -ForegroundColor Green
    return $reposFolder
}

function Test-ReposFolder {
    param([string]$ReposFolder)
    if (-not (Test-Path $ReposFolder)) {
        Write-Host "`nERROR: Folder does not exist: $ReposFolder" -ForegroundColor Red
        Show-Menu "Options" @("Create folder", "Change path", "Exit")
        $folderChoice = Get-UserChoice "Enter choice" 1 3
        switch ($folderChoice) {
            1 { New-Item -ItemType Directory -Path $ReposFolder -Force | Out-Null; Write-Host "Folder created: $ReposFolder" -ForegroundColor Green }
            2 { Remove-Item "git_tool_config.txt" -ErrorAction SilentlyContinue; Write-Host "Configuration reset. Please restart the tool." -ForegroundColor Yellow; pause; exit }
            3 { exit }
        }
    }
}

function Scan-Repositories {
    param([string]$ScanPath)
    Write-Host "`n===== Scan Folder for Repositories =====" -ForegroundColor Cyan
    Write-Host "Scanning: $ScanPath" -ForegroundColor Gray

    $repos = @()
    $folders = Get-ChildItem -Path $ScanPath -Directory -ErrorAction SilentlyContinue
    foreach ($folder in $folders) {
        if (Test-Path (Join-Path $folder.FullName ".git")) { $repos += $folder }
    }

    if ($repos.Count -eq 0) {
        Write-Host "No git repositories found in $ScanPath" -ForegroundColor Yellow
        return $null
    }

    Write-Host "`nFound repositories:" -ForegroundColor Green
    for ($i = 0; $i -lt $repos.Count; $i++) { Write-Host "$($i+1). $($repos[$i].Name)" -ForegroundColor White }

    $repoSelect = Get-UserChoice "`nSelect repository" 1 $repos.Count
    if ($repoSelect) { return $repos[$repoSelect - 1].FullName } else { return $null }
}

function Initialize-NewRepository {
    param([string]$ReposFolder)
    Write-Host "`n===== Initialize New Repository =====" -ForegroundColor Cyan
    Write-Host "Repositories folder: $ReposFolder" -ForegroundColor Gray

    $repoName = Read-Host "`nEnter repository name"
    if ([string]::IsNullOrWhiteSpace($repoName)) { Write-Host "Repository name cannot be empty!" -ForegroundColor Red; return $false }

    $defaultPath = Join-Path $ReposFolder $repoName
    $repoPath = Read-Host "`nRepository path (Enter for default: $defaultPath)"
    if ([string]::IsNullOrWhiteSpace($repoPath)) { $repoPath = $defaultPath }

    try { New-Item -ItemType Directory -Path $repoPath -Force | Out-Null; Set-Location $repoPath } 
    catch { Write-Host "ERROR: Cannot create or access directory: $repoPath" -ForegroundColor Red; return $false }

    git init
    "# $repoName`nRepository created with Git Multi-Tool" | Out-File "README.md" -Encoding UTF8
    (Get-Date).ToString() | Add-Content "README.md"
    git add README.md
    git commit -m "first commit"
    git branch -M main

    $githubUsername = Read-Host "Enter GitHub username (or Enter to skip)"
    if (-not [string]::IsNullOrWhiteSpace($githubUsername)) {
        $remoteUrl = "https://github.com/$githubUsername/$repoName.git"
        Write-Host "`nRepository will be created at: $remoteUrl" -ForegroundColor Gray
        Write-Host "`nCreate empty repository on GitHub first!" -ForegroundColor Yellow
        Read-Host "Press Enter after creation"
        git remote add origin $remoteUrl
        git push -u origin main
    }

    Write-Host "`nRepository created at $repoPath" -ForegroundColor Green
    return $true
}

function Simple-Commit {
    git status --short
    $msg = Read-Host "`nEnter commit message"; if ([string]::IsNullOrWhiteSpace($msg)) { $msg="Auto commit $(Get-Date)"; Write-Host "Using default commit message" -ForegroundColor Yellow }
    git add .; git commit -m $msg; git push
    return $true
}

function Force-Resolver {
    git rebase --abort 2>$null; git merge --abort 2>$null
    git reset --hard HEAD; git push --force
    return $true
}

function Check-Status {
    git branch --show-current; git log --oneline -5; git status
    return $true
}

function Push-ExistingRepository {
    try { git status --short 2>$null; if ($LASTEXITCODE -ne 0) { throw "Not a git repo" } } 
    catch { Write-Host "ERROR: Not a git repository!" -ForegroundColor Red; return $false }

    $remoteUrl = Read-Host "Enter remote URL"; if ([string]::IsNullOrWhiteSpace($remoteUrl)) { Write-Host "URL cannot be empty!" -ForegroundColor Red; return $false }
    git remote add origin $remoteUrl; git branch -M main; git push -u origin main
    return $true
}

function Ask-Continue {
    Show-Menu "Continue?" @("Return to main menu", "Exit")
    $c = Get-UserChoice "Enter choice" 1 2
    if ($c -eq 1) { return $true } else { Write-Host "`nThank you!" -ForegroundColor Green; return $false }
}

# === MAIN LOOP ===
do {
    Clear-Host
    Write-Host "===== Git Multi-Tool =====" -ForegroundColor Cyan
    $reposFolder = Initialize-Config; Test-ReposFolder -ReposFolder $reposFolder

    Show-Menu "Main Menu" @("Scan repositories","Custom path","Current directory","Init new repository")
    $repoChoice = Get-UserChoice "Enter choice" 1 4
    if (-not $repoChoice) { break }

    $opResult = $false
    switch ($repoChoice) {
        1 { $sel = Scan-Repositories -ScanPath $reposFolder; if ($sel) { Set-Location $sel; $opResult=$true } }
        2 { $path=Read-Host "Enter full repo path"; if ($path) { Set-Location $path; $opResult=$true } }
        3 { $opResult=$true }
        4 { $opResult=Initialize-NewRepository -ReposFolder $reposFolder }
    }

    if (-not $opResult) { if (-not (Ask-Continue)) { break }; continue }

    if ($repoChoice -ne 4) {
        Show-Menu "Mode Selection" @("Simple commit","Force resolver","Check status","Push existing")
        $mode = Get-UserChoice "Enter choice" 1 4
        switch ($mode) {
            1 { Simple-Commit }
            2 { Force-Resolver }
            3 { Check-Status }
            4 { Push-ExistingRepository }
        }
    }

} while (Ask-Continue)

Write-Host "`nScript terminated." -ForegroundColor Yellow
