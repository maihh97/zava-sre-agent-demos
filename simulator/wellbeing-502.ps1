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
}

function Wait-ForHealthyApp {
    for ($attempt = 1; $attempt -le 18; $attempt++) {
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

function Get-RecommendationsStatus {
    $setting = az webapp config appsettings list `
        --resource-group $ResourceGroup `
        --name $AppName `
        --query "[?name=='$settingName'].value | [0]" `
        --output tsv

    $health = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 20 -SkipHttpErrorCheck
    $recommendations = Invoke-WebRequest -Uri $recommendationsUrl -TimeoutSec 20 -SkipHttpErrorCheck

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

        $results = for ($request = 1; $request -le $RequestCount; $request++) {
            $response = Invoke-WebRequest -Uri $recommendationsUrl -TimeoutSec 20 -SkipHttpErrorCheck
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