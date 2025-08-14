// Application Insights must be imported and initialized first
import * as appInsights from "applicationinsights";

// Initialize Application Insights
if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  appInsights
    .setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .setAutoDependencyCorrelation(true)
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true, true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true)
    .setUseDiskRetryCaching(true)
    .setSendLiveMetrics(true)
    .start();

  // Set cloud role name and instance for proper service identification
  const cloudRole = process.env.APPLICATION_INSIGHTS_CLOUD_ROLE || "banv-backend-api";
  const cloudRoleInstance = process.env.APPLICATION_INSIGHTS_CLOUD_ROLE_INSTANCE || "banv-backend-instance";

  appInsights.defaultClient.context.tags[appInsights.defaultClient.context.keys.cloudRole] = cloudRole;
  appInsights.defaultClient.context.tags[appInsights.defaultClient.context.keys.cloudRoleInstance] = cloudRoleInstance;

  // Set service name and version
  appInsights.defaultClient.context.tags[appInsights.defaultClient.context.keys.applicationVersion] =
    process.env.npm_package_version || "1.0.0";

  console.log(`Application Insights initialized successfully with service name: ${cloudRole}`);
} else {
  console.warn("APPLICATIONINSIGHTS_CONNECTION_STRING not found - Application Insights disabled");
}

import express from "express";
import cors from "cors";
import session from "express-session";
import { register, collectDefaultMetrics, Counter, Histogram, Gauge } from "prom-client";

import { itemRoutes, oauthRoutes, userRoutes } from "./routes";
import { errorHandler, notFoundHandler, requestLogger, healthCheckLogger, errorRequestLogger } from "./middlewares";
import { logger } from "./utils";

// Initialize Prometheus metrics
collectDefaultMetrics();

// Custom metrics
const httpRequestsTotal = new Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"],
});

const httpRequestDuration = new Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route"],
  buckets: [0.1, 0.5, 1, 2, 5],
});

const app = express();

// Health check logger (before request logger to avoid noise)
app.use(healthCheckLogger);

// Main request logging middleware
app.use(requestLogger);

// Metrics middleware
app.use((req, res, next) => {
  const start = Date.now();

  res.on("finish", () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route?.path || req.path;

    httpRequestsTotal.inc({
      method: req.method,
      route: route,
      status_code: res.statusCode.toString(),
    });

    httpRequestDuration.observe({ method: req.method, route: route }, duration);
  });

  next();
});

app.use(
  cors({
    origin: process.env.FRONTEND_URL || "http://localhost:5173",
    credentials: true,
  })
);
app.use(express.json());

// Session configuration
app.use(
  session({
    secret: process.env.SESSION_SECRET || "your-session-secret",
    resave: true, // Changed to true to ensure session is saved
    saveUninitialized: true, // Changed to true to save new sessions
    cookie: {
      secure: process.env.NODE_ENV === "production",
      maxAge: 24 * 60 * 60 * 1000, // 24 hours
      httpOnly: true,
    },
  })
);

// Add advanced telemetry middleware if available
if ((global as any).advancedTelemetryMiddleware) {
  app.use((global as any).advancedTelemetryMiddleware);
}

// Log application startup
logger.app.info("Backend application starting", {
  nodeEnv: process.env.NODE_ENV || "development",
  version: process.env.npm_package_version || "1.0.0",
  timestamp: new Date().toISOString(),
  features: {
    applicationInsights: !!process.env.APPLICATIONINSIGHTS_CONNECTION_STRING,
    logging: true,
    cors: true,
    sessions: true,
  },
});

// Health check endpoint for /health
app.get("/health", (_, res) => {
  res.json({
    message: "Check health",
    status: "healthy",
    timestamp: new Date().toISOString(),
  });
});

// Metrics endpoint for Prometheus
app.get("/metrics", async (_, res) => {
  try {
    res.set("Content-Type", register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    res.status(500).end(error);
  }
});

// Readiness probe
app.get("/ready", (_, res) => {
  res.json({
    message: "Application is ready",
    status: "ready",
    timestamp: new Date().toISOString(),
  });
});

// Routes
app.use("/api/items", itemRoutes);
app.use("/api/user", userRoutes); // New user routes
app.use("/oauth", oauthRoutes);

// Error logging middleware (before error handlers)
app.use(errorRequestLogger);

// Global error handler (should be after routes)
app.use(errorHandler);
app.use(notFoundHandler);

// ========================================
// CRAZY ADVANCED APPLICATION INSIGHTS SETUP
// ========================================

if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  // Initialize Application Insights with ADVANCED features
  appInsights
    .setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .setAutoDependencyCorrelation(true)
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true, true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true, true)

    .setSendLiveMetrics(true) // 🔥 LIVE METRICS STREAM
    .setAutoCollectPreAggregatedMetrics(true)
    .setAutoCollectHeartbeat(true)
    .setInternalLogging(false, true);

  // Start Application Insights
  appInsights.start();

  // Get the telemetry client for custom metrics
  const client = appInsights.defaultClient;

  // Set cloud role and instance for better service mapping
  const cloudRole = process.env.APPLICATION_INSIGHTS_CLOUD_ROLE || "banv-backend-api";
  const cloudRoleInstance = process.env.APPLICATION_INSIGHTS_CLOUD_ROLE_INSTANCE || "banv-backend";

  client.context.tags[client.context.keys.cloudRole] = cloudRole;
  client.context.tags[client.context.keys.cloudRoleInstance] = cloudRoleInstance;

  // 🚀 CRAZY CUSTOM METRICS
  const businessMetrics = {
    userLogins: new Counter({
      name: "user_logins_total",
      help: "Total number of user logins",
      labelNames: ["method", "status"],
    }),
    apiResponseTime: new Histogram({
      name: "api_response_duration_seconds",
      help: "API response time in seconds",
      labelNames: ["endpoint", "method", "status_code"],
      buckets: [0.001, 0.005, 0.015, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 1.0, 5.0],
    }),
    activeUsers: new Gauge({
      name: "active_users_current",
      help: "Current number of active users",
      labelNames: ["session_type"],
    }),
    businessTransactions: new Counter({
      name: "business_transactions_total",
      help: "Total business transactions",
      labelNames: ["type", "status", "user_type"],
    }),
    errorsByType: new Counter({
      name: "application_errors_total",
      help: "Application errors by type",
      labelNames: ["error_type", "endpoint", "severity"],
    }),
  };

  // 📊 ADVANCED TELEMETRY MIDDLEWARE
  const advancedTelemetryMiddleware = (req: express.Request, res: express.Response, next: express.NextFunction) => {
    const startTime = Date.now();
    const endpoint = req.route?.path || req.path;

    // Track request start
    client.trackEvent({
      name: "RequestStarted",
      properties: {
        endpoint: endpoint,
        method: req.method,
        userAgent: req.get("User-Agent") || "unknown",
        ip: req.ip,
        timestamp: new Date().toISOString(),
      },
    });

    // Track response when finished
    res.on("finish", () => {
      const duration = (Date.now() - startTime) / 1000;
      const statusCode = res.statusCode;

      // Track response metrics
      businessMetrics.apiResponseTime.labels(endpoint, req.method, statusCode.toString()).observe(duration);

      // Track custom telemetry
      client.trackRequest({
        name: `${req.method} ${endpoint}`,
        url: req.url,
        duration: duration * 1000,
        resultCode: statusCode.toString(),
        success: statusCode < 400,
        properties: {
          endpoint: endpoint,
          method: req.method,
          statusCode: statusCode.toString(),
          duration: duration.toString(),
          userAgent: req.get("User-Agent") || "unknown",
        },
      });

      // Track performance thresholds
      if (duration > 1.0) {
        client.trackEvent({
          name: "SlowRequest",
          properties: {
            endpoint: endpoint,
            method: req.method,
            duration: duration.toString(),
            threshold: "1.0s",
          },
        });
      }

      // Track errors
      if (statusCode >= 400) {
        const errorType = statusCode >= 500 ? "server_error" : "client_error";
        businessMetrics.errorsByType.labels(errorType, endpoint, statusCode >= 500 ? "critical" : "warning").inc();

        client.trackException({
          exception: new Error(`HTTP ${statusCode} - ${req.method} ${endpoint}`),
          properties: {
            endpoint: endpoint,
            method: req.method,
            statusCode: statusCode.toString(),
            errorType: errorType,
          },
        });
      }
    });

    next();
  };

  // 🎯 BUSINESS LOGIC TRACKING
  const trackBusinessEvent = (eventName: string, properties: any = {}) => {
    client.trackEvent({
      name: eventName,
      properties: {
        ...properties,
        timestamp: new Date().toISOString(),
        service: cloudRole,
      },
    });
  };

  // 📈 PERFORMANCE MONITORING
  const trackPerformance = (name: string, duration: number, properties: any = {}) => {
    client.trackMetric({
      name: name,
      value: duration,
      properties: properties,
    });
  };

  // Make tracking functions available globally
  (global as any).trackBusinessEvent = trackBusinessEvent;
  (global as any).trackPerformance = trackPerformance;
  (global as any).businessMetrics = businessMetrics;
  (global as any).advancedTelemetryMiddleware = advancedTelemetryMiddleware;

  console.log(`🚀 ADVANCED Application Insights initialized for service: ${cloudRole}`);
  console.log("🔥 Features enabled: Live Metrics, Custom Telemetry, Performance Tracking, Business Metrics");
} else {
  console.warn("⚠️  Application Insights connection string not found");
}

export default app;
