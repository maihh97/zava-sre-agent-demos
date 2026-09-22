# Wellbeing App - Azure SRE Agent Demo

**A complete, deployable lab for demonstrating Azure SRE Agent investigation, governance, and remediation workflows.**

> Deploy a non-clinical employee wellbeing portal with a supporting operational API, introduce controlled failures, and use Azure SRE Agent to investigate the evidence and propose bounded remediation.

The public experience is **Zava Wellbeing**. The supporting API and synthetic catalog database provide repeatable SQL, health-check, deployment, and alert scenarios for the SRE demonstration.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Azure Resource Group (rg-zava)                │
│                                                                        │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐               │
│  │app-zava956235 │   │app-zava956235│   │app-zava956235│               │
│  │  (.NET 8)     │   │ itportal     │   │ warranty     │               │
│  │  Main API     │   │ (Node 20)    │   │ (Python 3.12)│               │
│  │  /health      │   │ Wellbeing    │   │ FastAPI      │               │
│  │  /api/products│   │              │   │ /warranty/*  │               │
│  └──────┬───────┘   └──────────────┘   └──────────────┘               │
│         │                                                              │
│         ▼                                                              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐               │
│  │sql-zava956235 │   │law-zava956235│   │ai-zava956235 │               │
│  │  SQL Server   │   │  Log         │   │  Application │               │
│  │  ┌──────────┐ │   │  Analytics   │   │  Insights    │               │
│  ││sqldb-      │ │   │  Workspace   │   │              │               │
│  ││zava956235  │ │   └──────────────┘   └──────────────┘               │
│  │  │ Basic 5  │ │   └──────────────┘   └──────────────┘               │
│  │  │ DTU      │ │                                                     │
│  │  └──────────┘ │   ┌──────────────────────────────────┐              │
│  └──────────────┘   │  Azure Monitor Alert Rules        │              │
│                      │  • DTU > 80%                      │              │
│                      │  • HTTP 5xx errors                │              │
│                      │  • Health check failures          │              │
│                      └──────────────────────────────────┘              │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                ▼                ▼
           ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
           │  SRE Agent 1 │ │  SRE Agent 2 │ │  ServiceNow  │
           │  SQL & App   │ │  IT Support  │ │  PDI          │
           │  Performance │ │  & SNOW      │ │  (Incidents)  │
           │              │ │              │ │               │
           │  MCP:        │ │  MCP:        │ └──────────────┘
           │  • mssql-mcp │ │  • (none)    │
           │  • github-mcp│ │              │
           └──────────────┘ └──────────────┘

           ┌──────────────────────────────────────────┐
           │         Demo Simulator (Python)          │
           │  simulator/demo.py                       │
           │  Triggers scenarios 1-5 via SQL & HTTP   │
           └──────────────────────────────────────────┘
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| **Azure subscription** | N/A | [Free account](https://azure.microsoft.com/free/) |
| **Azure CLI** | 2.60+ | `winget install Microsoft.AzureCLI` |
| **.NET SDK** | 8.0+ | `winget install Microsoft.DotNet.SDK.8` |
| **Python** | 3.11+ | `winget install Python.Python.3.12` |
| **Node.js** | 18+ | `winget install OpenJS.NodeJS.LTS` |
| **Azure SRE Agent portal** | current | [sre.azure.com](https://sre.azure.com) |
| **ServiceNow PDI** | N/A | [Free instance](https://developer.servicenow.com/) |

> **Optional:** SQL Server Management Studio (SSMS) or Azure Data Studio for database inspection.

---

## Quick Start (5 minutes)

```bash
# 1. Clone the repo
git clone https://github.com/maihh97/wellbeing-app-sre-agent.git
cd wellbeing-app-sre-agent

# 2. Log into Azure
az login

# 3. Deploy everything with one command
./infra/deploy.ps1 -ResourceGroup rg-zava -Location westus2 -SqlLocation westeurope -Prefix zava956235

# The script deploys infrastructure, publishes all three apps, and lets the
# main API initialize the private database through its managed identity.
```

This subscription enforces Microsoft Entra-only authentication and private Azure SQL networking. The deployment therefore uses:

- System-assigned managed identity for the main API
- A SQL private endpoint and App Service VNet integration
- No SQL passwords or public SQL firewall rules
- West US 2 for apps and West Europe for SQL, based on subscription availability

After deployment, verify:

```bash
curl https://app-zava956235.azurewebsites.net/health
# → {"status":"healthy","database":"connected"}

curl https://app-zava956235.azurewebsites.net/api/products
# → [{"id":1,"name":"Zava UltraBoost Running Shoe",...}, ...]

curl https://app-zava956235-warranty.azurewebsites.net/health
# → {"status":"healthy"}
```

---

## Project Structure

```
wellbeing-app-sre-agent/
├── infra/                          # Infrastructure-as-Code
│   ├── main.bicep                  # All Azure resources (SQL, Apps, Monitoring)
│   ├── main.bicepparam             # Default parameter values
│   ├── deploy.ps1                  # One-click deployment script
│   └── seed-database.sql           # Products, Orders, OrderItems seed data
│
├── src/                            # Main .NET 8 operational demo API
│   ├── Program.cs                  # Minimal API: /health, /api/products
│   ├── ZavaWellbeingApp.csproj     # .NET project (SQL Client, App Insights)
│   └── appsettings.json            # Connection string config
│
├── laptop-request-site/            # Wellbeing portal (Node.js static site)
│   ├── wellbeing.html              # Non-clinical wellbeing home page
│   ├── wellbeing.css               # Wellbeing portal styling
│   ├── index.html                  # Legacy laptop request form for Scenario 4
│   ├── server.js                   # Simple HTTP file server
│   ├── style.css                   # Legacy request form styling
│   └── package.json                # Node project
│
├── warranty-tool/                  # Warranty Lookup API (Python FastAPI)
│   ├── app.py                      # FastAPI app: /warranty/{serial}, /devices
│   ├── check_warranty.py           # Standalone CLI tool for SRE Agent
│   ├── requirements.txt            # fastapi, uvicorn, gunicorn
│   └── startup.sh                  # App Service startup command
│
├── simulator/                      # Demo scenario simulator
│   ├── demo.py                     # Interactive CLI with 5 scenarios
│   └── requirements.txt            # rich, requests, pymssql
│
├── sre-config/                     # SRE Agent Builder definitions
│   ├── agent1/                     # SQL & App Performance Agent
│   │   ├── agents/
│   │   │   ├── deployment-validator/       # Post-deploy health checks
│   │   │   └── sql-performance-investigator/ # SQL perf analysis
│   │   ├── hooks/
│   │   │   ├── change-risk-assessor.yaml   # Assess risk before changes
│   │   │   └── sql-write-guard.yaml        # Guard SQL write operations
│   │   ├── skills/
│   │   │   ├── sql-blocking-diagnosis/     # Diagnose blocking chains
│   │   │   ├── sql-blocking-fix/           # Resolve blocking chains
│   │   │   ├── sql-performance-fix/        # Fix slow queries (indexes)
│   │   │   └── sql-query-diagnosis/        # Identify slow queries
│   │   ├── tools/
│   │   │   └── AssessChangeRisk/           # Risk assessment tool
│   │   └── scheduledtasks/
│   │       └── weekly-cost-report/         # Weekly cost analysis
│   │
│   └── agent2/                     # IT Support & ServiceNow Agent
│       ├── agents/
│       │   └── it-support-handler/         # Handle IT support requests
│       ├── skills/
│       │   ├── device-support-triage/      # Warranty-based device triage
│       │   └── vpn-connectivity-triage/    # Bounded VPN diagnostics
│       ├── scheduledtasks/
│       │   ├── weekday-it-support-review/  # Daily queue review
│       │   └── weekly-it-support-trends/   # Weekly trend report
│       └── tools/
│           ├── CheckWarranty/              # Warranty lookup tool
│           ├── DiagnoseVpnIssue/            # Bounded VPN error runbooks
│           └── LookupServiceNowIncident/   # ServiceNow integration
│
├── dashboard.json                  # Azure Portal dashboard template
└── .gitignore
```

---

## Demo Scenarios

### Scenario 1: Slow Query (Missing Index)

| | |
|---|---|
| **What it demonstrates** | SRE Agent detects a performance degradation caused by a missing database index, diagnoses the root cause, and creates the index autonomously |
| **SRE Agent features** | Azure Monitor alert → Agent activation, SQL MCP connector, `sql-query-diagnosis` skill, `sql-performance-fix` skill, `change-risk-assessor` hook, `sql-write-guard` hook |

**Setup:**
1. Ensure the database has the Products table populated (via `seed-database.sql`)
2. DTU alert rule is configured (deployed automatically by Bicep)
3. SRE Agent 1 has the SQL MCP connector with the database connection string

**How to trigger:**
```bash
python simulator/demo.py
# Select option 1: "Slow Query (Missing Index)"
```

The simulator drops any existing indexes on the `Products.Category` column, then fires rapid `SELECT ... WHERE Category = @cat` queries in a loop, driving DTU usage above 80%.

**What to expect:**
1. The simulator shows live query latency (typically 800–2000ms per query)
2. Azure Monitor fires the DTU > 80% alert (~2-5 minutes)
3. SRE Agent 1 activates, connects via SQL MCP, identifies the missing index
4. The `change-risk-assessor` hook evaluates the proposed `CREATE INDEX` statement
5. The `sql-write-guard` hook approves the DDL change
6. SRE Agent creates the index: `CREATE NONCLUSTERED INDEX IX_Products_Category ON Products(Category)`
7. The simulator detects the index and shows a before/after performance graph
8. Query latency drops from ~1000ms to ~5ms (99%+ improvement)

---

### Scenario 2: Blocking Chain

| | |
|---|---|
| **What it demonstrates** | SRE Agent detects and resolves a SQL blocking chain (transaction deadlock) |
| **SRE Agent features** | `sql-blocking-diagnosis` skill, `sql-blocking-fix` skill, SQL MCP |

**Setup:**
- Same SQL MCP setup as Scenario 1

**How to trigger:**
```bash
python simulator/demo.py
# Select option 2: "Blocking Chain"
```

The simulator opens a long-running transaction that holds locks on the Orders table, then fires concurrent queries that get blocked.

**What to expect:**
1. The simulator opens a transaction with `BEGIN TRAN` + `UPDATE Orders` + `WAITFOR DELAY`
2. Subsequent queries to the Orders table are blocked
3. SRE Agent detects the blocking chain via `sys.dm_exec_requests` and `sys.dm_tran_locks`
4. Agent identifies the blocking session and either kills it or waits for it to complete
5. Blocked queries resume execution

---

### Scenario 3: Bad Deployment

| | |
|---|---|
| **What it demonstrates** | SRE Agent validates a deployment post-push and investigates failures |
| **SRE Agent features** | GitHub Actions HTTP trigger, `deployment-validator` extended agent, GitHub MCP connector, health endpoint monitoring |

**Setup:**
1. Add a GitHub Actions deployment workflow to your fork (this repository does not include one by default)
2. Configure `ZAVA_GH_REPO=maihh97/wellbeing-app-sre-agent`
3. Configure `ZAVA_GH_TOKEN` with repository contents/workflow access
4. Configure `ZAVA_SRE_TRIGGER_URL` from the SRE Agent HTTP trigger
5. Add the GitHub connector if you want commit-diff correlation

**How to trigger:**

```bash
python simulator/demo.py 3
```

The simulator pushes a deliberately bad `appsettings.json`, monitors the latest GitHub Actions run, waits for `/health` to fail, and invokes the SRE Agent HTTP trigger.

**What to expect:**
1. GitHub Actions deploys a bad database hostname and `/health` fails
2. GitHub Actions sends an HTTP trigger to the SRE Agent with deployment metadata
3. The `deployment-validator` agent activates
4. Agent hits `/health`, sees the failure, and investigates via GitHub MCP
5. Agent checks the commit diff, identifies the issue, and reports findings
6. After approval, the configuration is restored and health is confirmed

---

### Scenario 4: ServiceNow Integration

| | |
|---|---|
| **What it demonstrates** | SRE Agent handles an IT support request by looking up warranty status and creating/updating ServiceNow incidents |
| **SRE Agent features** | `it-support-handler` extended agent, `CheckWarranty` tool, `LookupServiceNowIncident` tool, ServiceNow API integration |

**Setup:**
1. Create a ServiceNow Personal Developer Instance (PDI) at [developer.servicenow.com](https://developer.servicenow.com/)
2. Configure the ServiceNow URL, username, and password in the simulator env vars
3. SRE Agent 2 must have the `CheckWarranty` and `LookupServiceNowIncident` tools

**How to trigger:**
```bash
python simulator/demo.py
# Select option 4: "ServiceNow Integration"
```

The simulator creates a ServiceNow incident for a laptop warranty issue, then triggers SRE Agent 2.

**What to expect:**
1. The simulator creates an INC ticket in ServiceNow
2. SRE Agent 2 activates, looks up the incident via `LookupServiceNowIncident`
3. Agent calls `CheckWarranty` with the laptop serial number
4. The warranty API returns status (active/expired, replacement eligibility)
5. Agent updates the ServiceNow incident with warranty details and recommendation

#### Additional Agent 2 Demo: VPN Connectivity

Agent 2 also handles moderate-priority ServiceNow incidents whose short description contains `VPN connectivity issue`. The `DiagnoseVpnIssue` tool recognizes VPN errors `809`, `720`, and `691`, plus certificate failures.

- Errors `809` and `720` return low-risk remediation steps and may be resolved through the Review-mode approval gate.
- Error `691`, certificate failures, and unknown errors remain open and are routed to the appropriate support team.
- The workflow never requests passwords, MFA codes, tokens, recovery codes, or private keys.

Create the incident in the `IT Support` assignment group with priority `3`, include the VPN error code and operating system in the description, and use a short description such as `VPN connectivity issue - Error 809`.

Agent 2 includes two reusable skills for device and VPN triage. It also runs two read-only scheduled reviews in UTC: a weekday queue review at 13:00 and a weekly trends report on Monday at 09:30. Scheduled reviews report missing evidence, pending approvals, escalations, and recurring patterns without modifying ServiceNow incidents or sending notifications.

---

### Scenario 5: HTTP Trigger (Recommended)

| | |
|---|---|
| **What it demonstrates** | A post-deployment failure invokes SRE Agent directly without requiring GitHub Actions |
| **SRE Agent features** | HTTP trigger, App Service health investigation, Application Insights evidence, review-mode remediation |

```powershell
$env:ZAVA_RESOURCE_GROUP = "rg-zava"
$env:ZAVA_APP_NAME = "app-zava956235"
$env:ZAVA_APP_URL = "https://app-zava956235.azurewebsites.net"
$env:ZAVA_SRE_TRIGGER_URL = "<trigger-url>"
python simulator/demo.py 5
```

Press `b` to inject an invalid SQL hostname. The simulator confirms the health failure, calls the SRE Agent trigger, and monitors recovery. Press `f` to restore the configuration manually or `q` to exit.

---

### Scenario 6: Simulate All

Launches scenarios 1, 5, and 4 in separate terminals. This requires both private SQL connectivity and ServiceNow configuration; it is not the recommended keynote path.

```bash
python simulator/demo.py 6
```

---

### Scenario 7: Reset All

Cleans up SQL indexes/blocking sessions, restores the managed-identity connection string, restarts the app, and checks health.

```bash
python simulator/demo.py 7
```

---

## SRE Agent Configuration

### Step 1: Create Agents at sre.azure.com

1. Navigate to [https://sre.azure.com](https://sre.azure.com)
2. Click **"Create Agent"**
3. Create **Agent 1: SQL & App Performance:**
   - Name: `zava-sreagent-1`
   - Agent resource group: `rg-zava`
   - Region: `East US 2`
   - Resource group to monitor: `rg-zava`
   - Description: "Monitors SQL performance, handles deployments, manages app health"
4. Create **Agent 2: IT Support & ServiceNow:**
   - Name: `zava-sreagent-2`
   - Agent resource group: `rg-zava`
   - Region: `East US 2`
   - Resource group to monitor: `rg-zava`
   - Description: "Handles IT support tickets, warranty lookups, ServiceNow integration"

### Step 2: Configure MCP Connectors

See [MCP Connector Setup](#mcp-connector-setup) below.

### Step 3: Apply Skills, Hooks, and Agents

Use **Builder** in the SRE Agent portal to add the repository definitions under `sre-config/`, or manage the agent through the Azure MCP Server SRE Agent tools.

If `srectl` is available in your environment, the repository still groups the definitions by agent:

```bash
# Install srectl (if not already installed)
# See https://learn.microsoft.com/azure/sre-agent for install instructions

# Select Agent 1 context
srectl config set-context <agent-1-id>

# Apply all Agent 1 configurations
srectl apply -f sre-config/agent1/skills/
srectl apply -f sre-config/agent1/hooks/
srectl apply -f sre-config/agent1/agents/
srectl apply -f sre-config/agent1/tools/
srectl apply -f sre-config/agent1/scheduledtasks/

# Switch to Agent 2
srectl config set-context <agent-2-id>

# Apply Agent 2 configurations
srectl apply -f sre-config/agent2/agents/
srectl apply -f sre-config/agent2/tools/
```

### Step 4: Set Up Incident Handlers and HTTP Triggers

**HTTP Trigger (recommended demo):**
1. In the SRE Agent portal, go to Agent 1 → Triggers
2. Create an HTTP trigger routed to `deployment-validator`
3. Start in **Review** mode
4. Copy the trigger URL into `ZAVA_SRE_TRIGGER_URL`

**Alert Handler (for Azure Monitor):**
1. In the SRE Agent portal, go to Agent 1 → Alert Handlers
2. Link `alert-zava956235-dtu-high`, `alert-zava956235-http-5xx`, and `alert-zava956235-health-check`
3. SRE Agent will automatically activate when these alerts fire

---

## MCP Connector Setup

### SQL MCP Connector (Agent 1)

The SQL MCP connector allows SRE Agent to query and modify the SQL database.

1. In SRE Agent portal → Agent 1 → Tools → Add MCP Connector
2. Package: `mssql-mcp@latest`
3. Environment variables:

| Variable | Value |
|----------|-------|
| Connection | `sql-zava956235.database.windows.net` / `sqldb-zava956235` using Microsoft Entra authentication |

> The SQL server is private-only. A SQL MCP server must have network access to `vnet-zava956235`; otherwise, begin with Azure-native resource, Monitor, Application Insights, and HTTP-trigger demonstrations.

### GitHub MCP Connector (Agent 1)

The GitHub MCP connector allows SRE Agent to inspect repositories, commits, and pull requests.

1. Create a GitHub Personal Access Token (PAT):
   - Go to [github.com/settings/tokens](https://github.com/settings/tokens)
   - Create a fine-grained token with read access to `maihh97/wellbeing-app-sre-agent`
2. In SRE Agent portal → Agent 1 → Tools → Add MCP Connector
3. Package: `@github/github-mcp-server`
4. Environment variables:

| Variable | Value |
|----------|-------|
| `GITHUB_PERSONAL_ACCESS_TOKEN` | `ghp_xxxxxxxxxxxxxxxxxxxx` |

---

## ServiceNow PDI Setup

### Get a Free Instance

1. Go to [developer.servicenow.com](https://developer.servicenow.com/)
2. Sign up for a free account
3. Click **"Start Building"** → **"Request Instance"**
4. Wait for the instance to provision (typically 5–10 minutes)
5. Note your instance URL (e.g., `https://dev123456.service-now.com`)

### Configure for the Demo

Set environment variables before running the simulator:

```powershell
$env:ZAVA_SN_URL  = "https://dev123456.service-now.com"
$env:ZAVA_SN_USER = "admin"
$env:ZAVA_SN_PASS = "your-instance-password"
```

### Create Test Tickets

The simulator (Scenario 4) creates incidents automatically. To create them manually:

1. Log into your ServiceNow instance
2. Navigate to **Incident → Create New**
3. Fill in:
   - Short Description: `Laptop replacement request - warranty expired`
   - Category: `Hardware`
   - Urgency: `Medium`
   - Description: `Employee SN-2021-DEL-3344 laptop warranty has expired. Requesting replacement.`

---

## Simulator Usage

```bash
# Install dependencies
pip install -r simulator/requirements.txt

# Run interactive menu
python simulator/demo.py

# Direct scenario launch
python simulator/demo.py 1    # Slow Query (Missing Index)
python simulator/demo.py 2    # Blocking Chain
python simulator/demo.py 3    # GitHub Actions bad deployment
python simulator/demo.py 4    # ServiceNow integration
python simulator/demo.py 5    # Direct HTTP-trigger deployment failure
python simulator/demo.py 6    # Launch multiple scenarios
python simulator/demo.py 7    # Reset all
```

### Environment Variables

Override defaults by setting environment variables:

```powershell
$env:ZAVA_RESOURCE_GROUP = "rg-zava"
$env:ZAVA_APP_NAME       = "app-zava956235"
$env:ZAVA_SQL_SERVER     = "sql-zava956235.database.windows.net"
$env:ZAVA_SQL_DATABASE   = "sqldb-zava956235"
$env:ZAVA_APP_URL        = "https://app-zava956235.azurewebsites.net"
$env:ZAVA_SRE_TRIGGER_URL = "<URL copied from Builder > HTTP triggers>"
$env:ZAVA_GH_REPO         = "maihh97/wellbeing-app-sre-agent"
$env:ZAVA_SN_URL       = "https://dev123456.service-now.com"
$env:ZAVA_SN_USER      = "admin"
$env:ZAVA_SN_PASS      = "your-password"
```

---

## Resource Links

After deployment, bookmark these:

| Resource | URL |
|----------|-----|
| **Main App** | `https://app-zava956235.azurewebsites.net` |
| **Wellbeing Portal** | `https://app-zava956235-itportal.azurewebsites.net` |
| **Laptop Request (Scenario 4)** | `https://app-zava956235-itportal.azurewebsites.net/index.html` |
| **Warranty API** | `https://app-zava956235-warranty.azurewebsites.net` |
| **Azure Portal** | `https://portal.azure.com` → resource group `rg-zava` |
| **SRE Agent Portal** | `https://sre.azure.com` |
| **Dashboard** | Azure Portal → search "Zava Operations Dashboard" |
| **App Insights** | Azure Portal → `ai-zava956235` |
| **SQL Database** | Azure Portal → `sql-zava956235` / `sqldb-zava956235` |

---

## Troubleshooting

### MCP Connection Issues

**Problem:** SRE Agent can't connect to SQL via MCP.

- Confirm the MCP host has private network access to `vnet-zava956235`
- Use Microsoft Entra authentication; SQL passwords are disabled by policy
- Verify `https://app-zava956235.azurewebsites.net/health` reports `database: connected`

**Problem:** GitHub MCP connector fails.

- Verify the PAT hasn't expired
- Ensure the PAT has `repo` read permissions
- Test: `curl -H "Authorization: token ghp_xxx" https://api.github.com/user`

### SQL Access

The deployment uses Microsoft Entra-only authentication. The main API's system-assigned managed identity is the SQL Entra administrator and initializes the demo schema on startup. Public SQL access is disabled.

Scenarios 1 and 2 make direct SQL connections. Run them from a VNet-connected host and use an Entra-capable SQL client. Scenarios 3, 4, and the HTTP-trigger demo can run from this workstation.

### App Service Quota

**Problem:** `Conflict: Cannot create more than N App Service plans in region.`

- Free/shared tier App Service plans have quota limits per region
- Delete unused App Service plans, or use a different region
- The B1 plan supports up to 3 apps (all 3 Zava apps share one plan)

### Alert Not Firing

**Problem:** DTU alert doesn't fire during Scenario 1.

- The Basic 5 DTU tier has very low headroom, so alerts typically fire within 2-5 minutes
- Check Azure Monitor → Alerts → look for `alert-zava956235-dtu-high`
- Verify the alert rule is enabled: Azure Portal → Alerts → Alert Rules
- If the simulator queries complete too fast, the DTU spike may be insufficient. Run the simulator longer.
- Check the evaluation window: the alert uses a 5-minute window with 1-minute frequency

### Simulator Can't Connect to SQL

The SQL endpoint is private by policy. Do not add a public firewall rule. Use a host connected to `vnet-zava956235`, or demonstrate Scenario 3/4 and HTTP triggers from this workstation.

---

## Cost Estimate

All resources use the lowest production-capable SKUs:

| Resource | SKU | Monthly Cost |
|----------|-----|-------------|
| SQL Database | Basic (5 DTU) | ~$5 |
| App Service Plan | B1 (shared by 3 apps) | ~$13 |
| Log Analytics | Pay-per-GB (free tier: 5GB) | ~$0 |
| Application Insights | Included with Log Analytics | ~$0 |
| Azure Monitor Alerts | Free tier (10 alert rules) | ~$0 |
| Private Endpoint | SQL private connectivity | ~$7 |
| **Total** | | **~$25/month** |

> 💡 **Tip:** Delete the resource group when not in use to stop all charges:
> ```bash
> az group delete -n rg-zava --yes --no-wait
> ```

---

## License

This repository is a demonstration environment for Azure SRE Agent and a non-clinical employee wellbeing experience.
