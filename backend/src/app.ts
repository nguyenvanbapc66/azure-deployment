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

  console.log("Application Insights initialized successfully");
} else {
  console.warn("APPLICATIONINSIGHTS_CONNECTION_STRING not found - Application Insights disabled");
}

import express from "express";
import cors from "cors";
import session from "express-session";
import { register, collectDefaultMetrics, Counter, Histogram } from "prom-client";

import { itemRoutes, oauthRoutes } from "./routes";
import { errorHandler, notFoundHandler } from "./middlewares";

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
app.use("/oauth", oauthRoutes);

// Global error handler (should be after routes)
app.use(errorHandler);
app.use(notFoundHandler);

export default app;
