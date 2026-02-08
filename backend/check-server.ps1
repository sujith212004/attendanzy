# Check if the backend server is running
Write-Host "Checking Attendanzy Backend Server Status..." -ForegroundColor Cyan
Write-Host ""

# Check if port 5000 is in use
$port = 5000
$connection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue

if ($connection) {
    Write-Host "✓ Server is running on port $port" -ForegroundColor Green
    Write-Host ""
    Write-Host "Testing API health..." -ForegroundColor Yellow
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:5000/api/health" -Method GET
        Write-Host "✓ API Health Check: $($response.message)" -ForegroundColor Green
        Write-Host "  Timestamp: $($response.timestamp)" -ForegroundColor Gray
    } catch {
        Write-Host "✗ API not responding" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Server is NOT running on port $port" -ForegroundColor Red
    Write-Host ""
    Write-Host "To start the server, run:" -ForegroundColor Yellow
    Write-Host "  npm start" -ForegroundColor White
    Write-Host "  or" -ForegroundColor Gray
    Write-Host "  .\start-server.ps1" -ForegroundColor White
}
