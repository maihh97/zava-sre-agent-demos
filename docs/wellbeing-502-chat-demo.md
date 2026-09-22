# Zava Wellbeing 502 Chat Demo

## Story

The Zava Wellbeing page loads personalized activity recommendations through the main API. The API acts as a gateway and calls a separate recommendations endpoint hosted by the Zava portal service.

A deployment introduces an invalid `WellbeingRecommendations__BaseUrl` App Service setting. The main application and database remain healthy, but the recommendations dependency cannot be resolved. Requests to `/api/wellbeing/recommendations` therefore return `502 Bad Gateway`.

This is a partial service degradation, not a total outage:

- `/health` remains `200`.
- The portal remains available.
- The recommendations panel shows a graceful unavailable message.
- Application Insights records failed outbound dependency calls and HTTP 502 requests.
- Azure Monitor records the failures through the App Service `Http5xx` metric.

## Control Model

This demo is intentionally chat-led.

- The Azure Monitor HTTP 5xx alert may fire and provide evidence.
- The Agent 1 `zava-http-5xx` response plan must remain disabled.
- The script does not call an SRE Agent HTTP trigger.
- Agent 1 starts investigating only when you ask in chat.
- Restoring the App Service setting is an Azure write and should require approval in Review mode.

## Prerequisites

1. Deploy the current main API and Zava portal code.
2. Confirm Agent 1 can read Application Insights and App Service configuration.
3. Keep Agent 1 in Review mode.
4. Confirm the HTTP 5xx metric alert is enabled.

## Check the Baseline

```powershell
./simulator/wellbeing-502.ps1 -Action Status
```

Expected result:

```text
HealthStatus        : 200
RecommendationsCode: 200
```

Open the portal and confirm the **Recommended today** section displays three recommendations:

```text
https://app-zava956235-itportal.azurewebsites.net
```

## Generate the Incident Evidence

```powershell
./simulator/wellbeing-502.ps1 -Action Break
```

The script:

1. Changes `WellbeingRecommendations__BaseUrl` to an unresolvable hostname.
2. Restarts the App Service and waits for the recommendations endpoint to return 502.
3. Sends eight requests to `/api/wellbeing/recommendations`.
4. Verifies every request returns HTTP 502.
5. Prints the Agent 1 chat prompts.

The script does not start an SRE investigation or repair the setting.

## Ask Agent 1 to Investigate

Open Agent 1 chat and send:

```text
Investigate why the Zava Wellbeing recommendations endpoint is returning HTTP 502.
App: app-zava956235
Endpoint: https://app-zava956235.azurewebsites.net/api/wellbeing/recommendations
Do not make changes. Check Application Insights requests, failed dependencies, exceptions,
and the current App Service setting WellbeingRecommendations__BaseUrl.
Explain the root cause and propose a fix.
```

Expected investigation:

1. Confirm `/health` is healthy while the recommendations route returns 502.
2. Find failed outbound HTTP dependency telemetry.
3. Identify DNS or connection failure for `wellbeing-recommendations.invalid`.
4. Inspect `WellbeingRecommendations__BaseUrl` on the App Service.
5. Explain that the API is healthy but its upstream recommendations service is unreachable.
6. Propose restoring the known-good portal URL.

## Ask Agent 1 to Repair

After reviewing the diagnosis, send:

```text
Restore WellbeingRecommendations__BaseUrl to
https://app-zava956235-itportal.azurewebsites.net.
Ask for approval before the write, then verify /health and
/api/wellbeing/recommendations.
```

Approve the proposed App Service configuration write. Agent 1 should verify:

- `/health` returns 200.
- `/api/wellbeing/recommendations` returns 200.
- The recommendations panel displays content again.

## Manual Recovery

If the agent cannot perform the write, restore the service with:

```powershell
./simulator/wellbeing-502.ps1 -Action Restore
```

The restore action restarts the App Service and waits until both `/health` and the recommendations endpoint return 200. App Service configuration propagation can take several minutes.

Always run `Restore` before ending the demo if the recommendations endpoint is still returning 502.

## Presenter Explanation

> The Zava Wellbeing application is available, but one feature depends on an upstream recommendations service. A deployment changed that service URL to an invalid hostname, so the gateway returns HTTP 502 while the rest of the application remains healthy. We ask Azure SRE Agent to investigate on demand. It correlates request failures, dependency telemetry, and App Service configuration, explains the partial outage, and proposes a governed configuration rollback in Review mode.