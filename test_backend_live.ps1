$baseUrl = "https://kissanai-pkzn.onrender.com"

Write-Host "=== 1. Health Check ==="
try {
    $r = Invoke-RestMethod -Uri "$baseUrl/health" -TimeoutSec 30
    Write-Host "OK: $($r.status)"
} catch { Write-Host "FAIL: $($_.Exception.Message)" }

Write-Host ""
Write-Host "=== 2. Register Test User ==="
$testEmail = "test$(Get-Random -Max 9999)@test.com"
try {
    $r = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" -Method POST -ContentType "application/json" -Body (@{
        full_name = "Test Farmer"
        phone = "03001234567"
        email = $testEmail
        password = "Test@1234"
    } | ConvertTo-Json) -TimeoutSec 30
    Write-Host "OK: User created - $($r.email)"
    $userId = $r.id
} catch { Write-Host "FAIL: $($_.Exception.Message)" }

Write-Host ""
Write-Host "=== 3. Login ==="
try {
    $r = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" -Method POST -ContentType "application/json" -Body (@{
        email = $testEmail
        password = "Test@1234"
    } | ConvertTo-Json) -TimeoutSec 30
    Write-Host "OK: Token received - $($r.access_token.Substring(0,20))..."
    $token = $r.access_token
} catch { Write-Host "FAIL: $($_.Exception.Message)" }

Write-Host ""
Write-Host "=== 4. Create Plot ==="
try {
    $r = Invoke-RestMethod -Uri "$baseUrl/api/plots" -Method POST -ContentType "application/json" -Headers @{Authorization="Bearer $token"} -Body (@{
        name = "Test Farm"
        soil_type = "loamy"
        area_hectares = 5
    } | ConvertTo-Json) -TimeoutSec 30
    Write-Host "OK: Plot created - $($r.id)"
    $plotId = $r.id
} catch { Write-Host "FAIL: $($_.Exception.Message)" }

Write-Host ""
Write-Host "=== 5. Crop Recommendation ==="
try {
    $r = Invoke-RestMethod -Uri "$baseUrl/api/irrigation/recommend" -Method POST -ContentType "application/json" -Headers @{Authorization="Bearer $token"} -Body (@{
        plot_id = $plotId
    } | ConvertTo-Json) -TimeoutSec 30
    Write-Host "OK: Crops - $($r.recommended_crops)"
    Write-Host "Reasoning: $($r.reasoning)"
    $recId = $r.id
} catch { Write-Host "FAIL: $($_.Exception.Message)" }

Write-Host ""
Write-Host "=== 6. Irrigation Guide ==="
try {
    $r = Invoke-RestMethod -Uri "$baseUrl/api/irrigation/guide/$recId" -Headers @{Authorization="Bearer $token"} -TimeoutSec 30
    Write-Host "OK: Schedule - $($r.schedule)"
    Write-Host "Method: $($r.method)"
} catch { Write-Host "FAIL: $($_.Exception.Message)" }

Write-Host ""
Write-Host "=== 7. History ==="
try {
    $r = Invoke-RestMethod -Uri "$baseUrl/api/history" -Headers @{Authorization="Bearer $token"} -TimeoutSec 30
    Write-Host "OK: $($r.Count) history entries"
    foreach ($item in $r) {
        Write-Host "  - $($item.analysis_type): $($item.created_at)"
    }
} catch { Write-Host "FAIL: $($_.Exception.Message)" }

Write-Host ""
Write-Host "=== 8. OpenAPI Spec ==="
try {
    $r = Invoke-RestMethod -Uri "$baseUrl/openapi.json" -TimeoutSec 30
    Write-Host "OK: $($r.paths.PSObject.Properties.Count) endpoints"
    $r.paths.PSObject.Properties | ForEach-Object { Write-Host "  $($_.Name)" }
} catch { Write-Host "FAIL: $($_.Exception.Message)" }
