# Cleanup Script - Remove all backup files from repository
# Run this from: essential_homes/new_essentials/
# Usage: powershell -ExecutionPolicy Bypass -File cleanup_backup_files.ps1

Write-Host "Starting backup file cleanup..." -ForegroundColor Cyan
Write-Host ""

$rootPath = "otp_phone_auth/lib/screens"
$patterns = @("*.backup", "*.backup2", "*.backup_*")

$totalDeleted = 0

foreach ($pattern in $patterns) {
    Write-Host "Searching for: $pattern" -ForegroundColor Yellow
    $files = Get-ChildItem -Path $rootPath -Filter $pattern -Recurse -File
    
    if ($files.Count -gt 0) {
        Write-Host "   Found $($files.Count) files matching '$pattern'" -ForegroundColor Gray
        foreach ($file in $files) {
            try {
                Remove-Item $file.FullName -Force
                Write-Host "   Deleted: $($file.Name)" -ForegroundColor Green
                $totalDeleted++
            }
            catch {
                Write-Host "   Failed to delete: $($file.Name)" -ForegroundColor Red
                Write-Host "      Error: $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "   No files found matching '$pattern'" -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Host "Cleanup complete!" -ForegroundColor Green
Write-Host "Total files deleted: $totalDeleted" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "   1. Review changes: git status" -ForegroundColor White
Write-Host "   2. Stage deletions: git add -A" -ForegroundColor White
Write-Host "   3. Commit: git commit -m 'chore: remove backup files from source control'" -ForegroundColor White
Write-Host ""
