param(
    [switch]$SkipGatewayProbe
)

$ErrorActionPreference = 'Stop'
$cbOriginal = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

function Write-Step($msg) { Write-Host "[verify] $msg" }
function Assert($condition, $message) { if (-not $condition) { throw $message } }

try {
    Write-Step "Checking Docker availability"
    docker info | Out-Null

    Write-Step "Checking compose services"
    $services = docker compose ps --format json | ConvertFrom-Json
    $expected = @('apim','dmz-gateway-adapter','dmz-gateway-enforcer','dmz-gateway-router','backend')
    foreach ($name in $expected) {
        $svc = $services | Where-Object { $_.Name -eq $name }
        Assert $svc "Service '$name' not found (docker compose ps)"
        Assert ($svc.State -eq 'running') "Service '$name' not running (state: $($svc.State))"
    }

    Write-Step "TCP port reachability"
    $ports = @(
        @{ Label = 'Portal HTTPS'; Port = 9443 },
        @{ Label = 'Gateway listener'; Port = 9090 },
        @{ Label = 'Gateway admin'; Port = 9095 },
        @{ Label = 'Backend'; Port = 8081 }
    )
    foreach ($p in $ports) {
        $res = Test-NetConnection -ComputerName 'localhost' -Port $p.Port -WarningAction SilentlyContinue
        Assert $res.TcpTestSucceeded "Port $($p.Port) ($($p.Label)) not reachable"
    }

    Write-Step "HTTP probe: backend (http://localhost:8081/status/200)"
    $backendResp = Invoke-WebRequest -Uri 'http://localhost:8081/status/200' -UseBasicParsing
    Assert ($backendResp.StatusCode -eq 200) 'Backend probe failed'

    if (-not $SkipGatewayProbe) {
        Write-Step "HTTP probe: gateway route (http://localhost:9090/httpbin/status/200)"
        $gwResp = Invoke-WebRequest -Uri 'http://localhost:9090/httpbin/status/200' -UseBasicParsing
        Assert ($gwResp.StatusCode -eq 200) 'Gateway route probe failed'
    }

    Write-Step "Verification PASSED"
}
finally {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $cbOriginal
}
