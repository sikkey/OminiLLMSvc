$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir '..\apps\config\test.ini'

function Read-TestIni {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Missing test config: $Path"
    }

    $currentSection = ''
    $result = @{}

    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith(';') -or $line.StartsWith('#')) {
            return
        }

        if ($line -match '^\[(.+)\]$') {
            $currentSection = $matches[1].Trim()
            return
        }

        if ($line -match '^([^=]+?)\s*=\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ($currentSection -eq 'proxy') {
                $result[$key] = $value
            }
        }
    }

    return $result
}

$cfg = Read-TestIni -Path $configPath

$proxyBaseUrl = $cfg['PROXY_BASE_URL']
$model = $cfg['MODEL']
$apiKey = $cfg['API_KEY']

if ([string]::IsNullOrWhiteSpace($proxyBaseUrl)) {
    throw "Missing PROXY_BASE_URL in $configPath"
}
if ([string]::IsNullOrWhiteSpace($model)) {
    throw "Missing MODEL in $configPath"
}
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "Missing API_KEY in $configPath"
}

Write-Host "[INFO] Proxy base URL: $proxyBaseUrl"
Write-Host "[INFO] Model: $model"

$healthUri = "$proxyBaseUrl/health"
$resp = Invoke-WebRequest -UseBasicParsing -Uri $healthUri -Method Get -ErrorAction Stop
Write-Host "[STEP 1/3] Health check..."
Write-Host "HTTP $($resp.StatusCode)"
if ($resp.StatusCode -ne 200) {
    throw "Health check failed: $healthUri"
}

function Invoke-TestCase {
    param(
        [string]$Name,
        [string]$Url,
        [hashtable]$Payload
    )

    Write-Host ""
    Write-Host "[STEP $Name]..."

    $headers = @{
        Authorization = "Bearer $apiKey"
        'Content-Type' = 'application/json'
    }

    $body = $Payload | ConvertTo-Json -Depth 10 -Compress
    $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -Method Post -Headers $headers -Body $body -ErrorAction Stop

    Write-Host "HTTP $($response.StatusCode)"
    $content = $response.Content
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "Empty response for $Name"
    }
    if ($content.Length -lt 20) {
        throw "Response too short for $Name"
    }

    Write-Host ($content.Substring(0, [Math]::Min(220, $content.Length)))
    Write-Host "[PASS] $Name succeeded."
}

$tests = @(
    @{
        Name = 'Code Completion'
        Url = "$proxyBaseUrl/v1/completions"
        Payload = @{
            model = $model
            prompt = "function add(a, b) {`r`n  return a + b;`r`n}`r`n`r`nadd(1,"
            max_tokens = 80
            temperature = 0.2
        }
    },
    @{
        Name = 'Chat Assistant'
        Url = "$proxyBaseUrl/v1/chat/completions"
        Payload = @{
            model = $model
            messages = @(
                @{
                    role = 'user'
                    content = "Explain this JavaScript function in simple terms: function greet(name){ return 'Hello ' + name; }"
                }
            )
            max_tokens = 120
            temperature = 0.3
        }
    },
    @{
        Name = 'Quick Refactor'
        Url = "$proxyBaseUrl/v1/chat/completions"
        Payload = @{
            model = $model
            messages = @(
                @{
                    role = 'user'
                    content = "Refactor this function to be cleaner and more idiomatic JavaScript. Keep the logic the same.`r`n`r`nfunction compute(x,y){if(x==null){return 0} if(y==null){return 0} return x+y}`r`n"
                }
            )
            max_tokens = 200
            temperature = 0.2
        }
    }
)

$failed = $false
foreach ($test in $tests) {
    try {
        Invoke-TestCase -Name $test.Name -Url $test.Url -Payload $test.Payload
    }
    catch {
        $failed = $true
        Write-Host "[FAIL] $($test.Name) request failed."
        Write-Host $_.Exception.Message
    }
}

if ($failed) {
    Write-Host ""
    Write-Host "[SUMMARY] One or more OpenAI-compatible tests failed."
    exit 1
}

Write-Host ""
Write-Host "[SUMMARY] All three OpenAI-compatible tests passed."
exit 0
