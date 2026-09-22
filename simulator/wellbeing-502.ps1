param(
    [ValidateSet('Break', 'Status', 'Restore')]
    [string]$Action = 'Status',

    [string]$ResourceGroup = 'rg-zava',
    [string]$AppName = 'app-zava956235',
    [string]$PortalName = 'app-zava956235-itportal',

    [ValidateRange(6, 50)]
    [int]$RequestCount = 8
)

$ErrorActionPreference = 'Stop'
$settingName = 'WellbeingRecommendations__BaseUrl'
$healthyUpstream = "https://$PortalName.azurewebsites.net"
$brokenUpstream = 'https://wellbeing-recommendations.invalid'
$appBaseUrl = "https://$AppName.azurewebsites.net"
$recommendationsUrl = "$appBaseUrl/api/wellbeing/recommendations"
$healthUrl = "$appBaseUrl/health"

function Set-RecommendationsUpstream {
    param([Parameter(Mandatory)][string]$Url)

    az webapp config appsettings set `
        --resource-group $ResourceGroup `
        --name $AppName `
        --settings "$settingName=$Url" `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set $settingName on $AppName."
    }

    az webapp restart `
        --resource-group $ResourceGroup `
        --name $AppName `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to restart $AppName after updating $settingName."
    }
}

function Wait-ForHealthyApp {
    for ($attempt = 1; $attempt -le 36; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 20 -SkipHttpErrorCheck
            if ([int]$response.StatusCode -eq 200) {
                return
            }
        }
        catch {
            # App settings restart the web app; transient connection failures are expected.
        }

        Start-Sleep -Seconds 5
    }

    throw "The app did not become healthy after updating $settingName."
}

function Invoke-RecommendationsRequest {
    $cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    Invoke-WebRequest `
        -Uri "${recommendationsUrl}?ts=$cacheBuster" `
        -Headers @{ 'Cache-Control' = 'no-cache' } `
        -TimeoutSec 20 `
        -SkipHttpErrorCheck
}

function Wait-ForRecommendationsStatus {
    param([Parameter(Mandatory)][int]$ExpectedStatus)

    for ($attempt = 1; $attempt -le 36; $attempt++) {
        try {
            $response = Invoke-RecommendationsRequest
            if ([int]$response.StatusCode -eq $ExpectedStatus) {
                return
            }
        }
        catch {
            # App settings restart the web app; transient connection failures are expected.
        }

        Start-Sleep -Seconds 5
    }

    throw "The recommendations endpoint did not return HTTP $ExpectedStatus after updating $settingName."
}

function Get-RecommendationsStatus {
    $setting = az webapp config appsettings list `
        --resource-group $ResourceGroup `
        --name $AppName `
        --query "[?name=='$settingName'].value | [0]" `
        --output tsv

    $health = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 20 -SkipHttpErrorCheck
    $recommendations = Invoke-RecommendationsRequest

    [pscustomobject]@{
        UpstreamUrl          = $setting
        HealthStatus        = [int]$health.StatusCode
        RecommendationsCode = [int]$recommendations.StatusCode
        RecommendationsBody = [string]$recommendations.Content
    }
}

switch ($Action) {
    'Break' {
        Write-Host 'Simulating a bad deployment of the wellbeing recommendations URL...' -ForegroundColor Yellow
        Set-RecommendationsUpstream -Url $brokenUpstream
        Wait-ForHealthyApp
        Wait-ForRecommendationsStatus -ExpectedStatus 502

        $results = for ($request = 1; $request -le $RequestCount; $request++) {
            $response = Invoke-RecommendationsRequest
            [pscustomobject]@{
                Request = $request
                Status  = [int]$response.StatusCode
            }
        }

        $results | Format-Table -AutoSize
        if (@($results | Where-Object Status -ne 502).Count -gt 0) {
            throw 'One or more recommendations requests did not return the expected HTTP 502.'
        }

        Write-Host "Generated $RequestCount HTTP 502 responses while /health remains healthy." -ForegroundColor Green
        Write-Host ''
        Write-Host 'Ask Agent 1 in chat:' -ForegroundColor Cyan
        Write-Host @"
Investigate why the Zava Wellbeing recommendations endpoint is returning HTTP 502.
App: $AppName
Endpoint: $recommendationsUrl
Do not make changes. Check Application Insights requests, failed dependencies, exceptions,
and the current App Service setting $settingName. Explain the root cause and propose a fix.
"@
        Write-Host 'After reviewing the diagnosis, ask:' -ForegroundColor Cyan
        Write-Host @"
Restore $settingName to $healthyUpstream.
Ask for approval before the write, then verify /health and /api/wellbeing/recommendations.
"@
    }

    'Restore' {
        Write-Host 'Restoring the wellbeing recommendations dependency...' -ForegroundColor Yellow
        Set-RecommendationsUpstream -Url $healthyUpstream
        Wait-ForHealthyApp
        Wait-ForRecommendationsStatus -ExpectedStatus 200
        $status = Get-RecommendationsStatus
        $status | Format-List
        if ($status.RecommendationsCode -ne 200) {
            throw 'The recommendations endpoint did not recover.'
        }
        Write-Host 'The Zava Wellbeing recommendations experience is healthy.' -ForegroundColor Green
    }

    'Status' {
        Get-RecommendationsStatus | Format-List
    }
}