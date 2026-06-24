$email = "sofia.franco1@example.com"
$body = "username=$email&password=wrongpass"
$headers = @{"Content-Type" = "application/x-www-form-urlencoded"}

Write-Host "Ejecutando 5 intentos de login fallidos..." -ForegroundColor Green
Write-Host "Email: $email" -ForegroundColor Yellow
Write-Host "Contrasena: wrongpass (incorrecta)" -ForegroundColor Yellow
Write-Host ""

for ($i = 1; $i -le 5; $i++) {
    Write-Host "[$i/5] Intento..." -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8000/login" `
                                    -Method POST `
                                    -Body $body `
                                    -Headers $headers `
                                    -ErrorAction Stop
        Write-Host "    Respuesta: $($response.StatusCode)" -ForegroundColor Red
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "    Status: $statusCode" -ForegroundColor Red
        $errorContent = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()).ReadToEnd()
        Write-Host "    Respuesta: $errorContent" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 500
}

Write-Host ""
Write-Host "=== VERIFICACION EN REDIS ===" -ForegroundColor Green
Write-Host ""

