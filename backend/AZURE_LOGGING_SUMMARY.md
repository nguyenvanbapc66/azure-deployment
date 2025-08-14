# 🚀 Azure Application Insights Logging - Quick Start

## What's New? ✨

Your backend now sends **all logs automatically to Azure Application Insights** while maintaining local file logging. This gives you powerful cloud-based log analysis in the Azure Portal.

## 🎯 Where to Find Your Logs

### Azure Portal Path:

**Azure Portal** → **Application Insights** → **Your App Insights Resource** → **Monitoring** → **Logs**

### Key Tables to Query:

- **`requests`** - All HTTP requests with status codes (200, 400, 404, 500, etc.)
- **`traces`** - Application logs and request traces
- **`exceptions`** - Error logs with stack traces
- **`customEvents`** - Security events and business events

## 🔍 Essential Queries for Your Backend

### 1. **View All Recent Requests (Last Hour)**

```kusto
requests
| where timestamp > ago(1h)
| project timestamp, name, url, resultCode, duration, success
| order by timestamp desc
```

### 2. **View Your Custom Application Logs**

```kusto
traces
| where timestamp > ago(1h)
| where customDimensions.logType == "application"
| project timestamp, message, customDimensions.requestId, customDimensions.endpoint
| order by timestamp desc
```

### 3. **View Security Events (Failed logins, etc.)**

```kusto
customEvents
| where timestamp > ago(1h)
| where name == "SecurityEvent"
| project timestamp, customDimensions.message, customDimensions.ip, customDimensions.userAgent
| order by timestamp desc
```

### 4. **Track a Specific Request (Full Flow)**

```kusto
let requestId = "req_1234567890_abcdef";  // Replace with actual request ID from your logs
union requests, traces, customEvents
| where customDimensions.requestId == requestId
| project timestamp, message, customDimensions.logType
| order by timestamp asc
```

### 5. **Error Monitoring**

```kusto
union traces, exceptions
| where timestamp > ago(1h)
| where severityLevel >= 3
| project timestamp, message, customDimensions.requestId, customDimensions.logType
| order by timestamp desc
```

## 🛠️ Deployment Instructions

### Option 1: Using the Automated Script (Recommended)

```bash
cd backend
./LOGGING_DEPLOYMENT_SCRIPT.sh
```

### Option 2: Manual Setup

1. **Get Application Insights Connection String**:

   ```bash
   az monitor app-insights component show --app your-app-insights-name --resource-group your-rg --query connectionString -o tsv
   ```

2. **Create Kubernetes Secret**:

   ```bash
   kubectl create secret generic app-insights-secret \
     --from-literal=connection-string="YOUR_CONNECTION_STRING" \
     -n banv-projects
   ```

3. **Deploy Backend** (connection string will be picked up automatically)

## ✅ Verification Steps

### 1. **Test APIs to Generate Logs**

```bash
# Generate successful request logs
curl "https://your-backend-url/api/user/information"

# Generate error logs
curl "https://your-backend-url/api/user/error?type=server"

# Generate security logs
curl "https://your-backend-url/api/user/error?type=unauthorized"
```

### 2. **Check Azure Portal** (wait 1-2 minutes)

- Navigate to **Application Insights** → **Logs**
- Run the queries above
- You should see your logs with **sensitive data filtered out**

### 3. **Verify Request Correlation**

- Look for `requestId` in logs (e.g., `req_1755142632859_umabybluy`)
- Use this to trace the full request flow across multiple log entries

## 🔐 Security & Privacy

✅ **Sensitive data is automatically filtered** before sending to Azure:

- Passwords → `[FILTERED]`
- API keys → `[FILTERED]`
- Tokens → `[FILTERED]`
- Usernames → `[FILTERED]` (as requested)

✅ **Local logs still work** - All logs are saved to both local files AND Azure

## 🎉 Benefits

🔍 **Powerful Querying**: Use KQL (Kusto Query Language) for advanced log analysis
📊 **Visual Dashboards**: Create charts and dashboards from your logs  
🚨 **Real-time Alerts**: Set up alerts for errors, performance issues, security events
📈 **Performance Insights**: Analyze request durations, error rates, trends
🔗 **Request Correlation**: Track requests from start to finish across your system
☁️ **Cloud Scale**: Handle massive log volumes without local storage concerns

## 📚 Full Documentation

For detailed information, advanced queries, and troubleshooting:

- **[AZURE-INSIGHTS-LOGGING-GUIDE.md](./AZURE-INSIGHTS-LOGGING-GUIDE.md)** - Complete guide
- **[LOGGING_GUIDE.md](./LOGGING_GUIDE.md)** - Original logging system documentation

## 🚀 Ready to Deploy?

Simply run the deployment script and start monitoring your logs in Azure:

```bash
cd backend
./LOGGING_DEPLOYMENT_SCRIPT.sh
```

Your comprehensive logging system is now **cloud-ready**! 🎊
