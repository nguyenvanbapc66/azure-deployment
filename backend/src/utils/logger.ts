import winston from "winston";
import DailyRotateFile from "winston-daily-rotate-file";
import path from "path";
import * as appInsights from "applicationinsights";

// Sensitive data fields to filter out from logs
const SENSITIVE_FIELDS = [
  "password",
  "pass",
  "pwd",
  "secret",
  "token",
  "accessToken",
  "refreshToken",
  "authorization",
  "auth",
  "apikey",
  "api_key",
  "username", // Added based on requirements
  "email",
  "creditCard",
  "ssn",
  "socialSecurityNumber",
  "pin",
  "cvv",
  "cvc",
];

// Function to filter sensitive data from objects
const filterSensitiveData = (obj: any): any => {
  if (obj === null || obj === undefined) return obj;

  if (Array.isArray(obj)) {
    return obj.map((item) => filterSensitiveData(item));
  }

  if (typeof obj === "object") {
    const filtered: any = {};
    for (const key in obj) {
      const lowerKey = key.toLowerCase();
      if (SENSITIVE_FIELDS.some((field) => lowerKey.includes(field))) {
        filtered[key] = "[FILTERED]";
      } else {
        filtered[key] = filterSensitiveData(obj[key]);
      }
    }
    return filtered;
  }

  return obj;
};

// Custom format for consistent logging
const customFormat = winston.format.combine(
  winston.format.timestamp({
    format: "YYYY-MM-DD HH:mm:ss.SSS",
  }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, service, ...meta }) => {
    const filteredMeta = filterSensitiveData(meta);
    return JSON.stringify({
      timestamp,
      level: level.toUpperCase(),
      service,
      message,
      ...filteredMeta,
    });
  })
);

// Application Insights transport function
const createAzureInsightsTransport = (logType: string, level: string = "info") => {
  return winston.format.printf((info) => {
    // Only send to Application Insights if client is available
    if (appInsights.defaultClient && process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
      try {
        const filteredInfo = filterSensitiveData(info);

        // Send different telemetry based on log type
        switch (logType) {
          case "request":
            if (filteredInfo.statusCode && filteredInfo.method && filteredInfo.url) {
              // Track as request telemetry
              appInsights.defaultClient.trackRequest({
                name: `${filteredInfo.method} ${filteredInfo.path || filteredInfo.url}`,
                url: filteredInfo.url,
                duration: parseDuration(filteredInfo.duration),
                resultCode: filteredInfo.statusCode.toString(),
                success: filteredInfo.statusCode < 400,
                properties: {
                  logType: "request",
                  level: filteredInfo.level,
                  service: filteredInfo.service,
                  requestId: filteredInfo.requestId,
                  ip: filteredInfo.ip,
                  userAgent: filteredInfo.userAgent,
                  timestamp: filteredInfo.timestamp,
                },
              });
            } else {
              // Track as trace for request events
              appInsights.defaultClient.trackTrace({
                message: filteredInfo.message,
                properties: {
                  logType: "request",
                  level: filteredInfo.level,
                  service: filteredInfo.service,
                  requestId: filteredInfo.requestId,
                  method: filteredInfo.method,
                  url: filteredInfo.url,
                  path: filteredInfo.path,
                  ip: filteredInfo.ip,
                  timestamp: filteredInfo.timestamp,
                  severity: mapLogLevel(filteredInfo.level),
                },
              });
            }
            break;

          case "security":
            // Track security events
            appInsights.defaultClient.trackEvent({
              name: "SecurityEvent",
              properties: {
                message: filteredInfo.message,
                logType: "security",
                level: filteredInfo.level,
                service: filteredInfo.service,
                requestId: filteredInfo.requestId,
                ip: filteredInfo.ip,
                userAgent: filteredInfo.userAgent,
                endpoint: filteredInfo.endpoint,
                timestamp: filteredInfo.timestamp,
                severity: mapLogLevel(filteredInfo.level),
              },
            });
            break;

          case "app":
          default:
            if (filteredInfo.level === "error" && (filteredInfo.error || filteredInfo.stack)) {
              // Track application errors as exceptions
              const error = new Error(filteredInfo.error?.message || filteredInfo.message);
              if (filteredInfo.error?.stack || filteredInfo.stack) {
                error.stack = filteredInfo.error?.stack || filteredInfo.stack;
              }

              appInsights.defaultClient.trackException({
                exception: error,
                properties: {
                  logType: "application",
                  level: filteredInfo.level,
                  service: filteredInfo.service,
                  requestId: filteredInfo.requestId,
                  endpoint: filteredInfo.endpoint,
                  processingTime: filteredInfo.processingTime,
                  timestamp: filteredInfo.timestamp,
                  severity: "critical",
                },
              });
            } else {
              // Track regular application logs as traces
              appInsights.defaultClient.trackTrace({
                message: filteredInfo.message,
                properties: {
                  logType: "application",
                  level: filteredInfo.level,
                  service: filteredInfo.service,
                  requestId: filteredInfo.requestId,
                  endpoint: filteredInfo.endpoint,
                  userId: filteredInfo.userId,
                  processingTime: filteredInfo.processingTime,
                  timestamp: filteredInfo.timestamp,
                  severity: mapLogLevel(filteredInfo.level),
                },
              });
            }
            break;
        }
      } catch (error) {
        console.error("Error sending log to Application Insights:", error);
      }
    }

    // Return empty string since this is just for side effects
    return "";
  });
};

// Helper functions
const parseDuration = (duration: string | number): number => {
  if (typeof duration === "number") return duration;
  if (typeof duration === "string") {
    const match = duration.match(/(\d+(?:\.\d+)?)/);
    return match ? parseFloat(match[1]) : 0;
  }
  return 0;
};

const mapLogLevel = (level: string): string => {
  switch (level.toLowerCase()) {
    case "error":
      return "critical";
    case "warn":
    case "warning":
      return "warning";
    case "info":
      return "information";
    case "debug":
      return "verbose";
    default:
      return "information";
  }
};

// Create logs directory if it doesn't exist
const logsDir = path.join(process.cwd(), "logs");

// Base transport configuration
const getBaseTransports = (logType: string, level: string = "info") => {
  const transports: winston.transport[] = [
    // Console output for development
    new winston.transports.Console({
      level: process.env.NODE_ENV === "production" ? "warn" : level,
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple(),
        winston.format.printf(({ timestamp, level, message, ...meta }) => {
          const filteredMeta = filterSensitiveData(meta);
          return `${timestamp} [${level}] [${logType.toUpperCase()}] ${message} ${Object.keys(filteredMeta).length > 0 ? JSON.stringify(filteredMeta) : ""}`;
        })
      ),
    }),
  ];

  // Application Insights integration happens in the logger helper functions

  return transports;
};

// Request Logger Configuration
const requestLogger = winston.createLogger({
  format: customFormat,
  defaultMeta: { service: "banv-backend-requests" },
  transports: [
    ...getBaseTransports("requests", "info"),

    // Separate file for request logs with daily rotation
    new DailyRotateFile({
      filename: path.join(logsDir, "requests-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      maxSize: "50m",
      maxFiles: "30d",
      level: "info",
      createSymlink: true,
      symlinkName: "requests-current.log",
    }),

    // Error-only request logs
    new DailyRotateFile({
      filename: path.join(logsDir, "requests-errors-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      maxSize: "50m",
      maxFiles: "30d",
      level: "error",
      createSymlink: true,
      symlinkName: "requests-errors-current.log",
    }),
  ],
});

// Application Logger Configuration
const appLogger = winston.createLogger({
  format: customFormat,
  defaultMeta: { service: "banv-backend-app" },
  transports: [
    ...getBaseTransports("app", process.env.NODE_ENV === "production" ? "warn" : "debug"),

    // General application logs with daily rotation
    new DailyRotateFile({
      filename: path.join(logsDir, "app-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      maxSize: "50m",
      maxFiles: "30d",
      level: "info",
      createSymlink: true,
      symlinkName: "app-current.log",
    }),

    // Debug logs (only in development)
    ...(process.env.NODE_ENV !== "production"
      ? [
          new DailyRotateFile({
            filename: path.join(logsDir, "app-debug-%DATE%.log"),
            datePattern: "YYYY-MM-DD",
            maxSize: "20m",
            maxFiles: "7d",
            level: "debug",
            createSymlink: true,
            symlinkName: "app-debug-current.log",
          }),
        ]
      : []),

    // Error-only application logs
    new DailyRotateFile({
      filename: path.join(logsDir, "app-errors-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      maxSize: "50m",
      maxFiles: "60d",
      level: "error",
      createSymlink: true,
      symlinkName: "app-errors-current.log",
    }),
  ],
});

// Security Logger for audit trails
const securityLogger = winston.createLogger({
  format: customFormat,
  defaultMeta: { service: "banv-backend-security" },
  transports: [
    ...getBaseTransports("security", "info"),

    new DailyRotateFile({
      filename: path.join(logsDir, "security-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      maxSize: "50m",
      maxFiles: "90d",
      level: "info",
      createSymlink: true,
      symlinkName: "security-current.log",
    }),
  ],
});

// Send to Application Insights
const sendToApplicationInsights = (message: string, meta: any, logType: string, level: string) => {
  if (!appInsights.defaultClient || !process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
    return;
  }

  try {
    const filteredMeta = filterSensitiveData(meta || {});

    switch (logType) {
      case "request":
        if (filteredMeta.statusCode && filteredMeta.method && filteredMeta.url) {
          // Track as request telemetry
          appInsights.defaultClient.trackRequest({
            name: `${filteredMeta.method} ${filteredMeta.path || filteredMeta.url}`,
            url: filteredMeta.url,
            duration: parseDuration(filteredMeta.duration),
            resultCode: filteredMeta.statusCode.toString(),
            success: filteredMeta.statusCode < 400,
            properties: {
              logType: "request",
              level: level,
              service: "banv-backend-requests",
              requestId: filteredMeta.requestId,
              ip: filteredMeta.ip,
              userAgent: filteredMeta.userAgent,
              timestamp: filteredMeta.timestamp,
            },
          });
        } else {
          // Track as trace for request events
          appInsights.defaultClient.trackTrace({
            message: message,
            properties: {
              logType: "request",
              level: level,
              service: "banv-backend-requests",
              severity: mapLogLevel(level),
              ...filteredMeta,
            },
          });
        }
        break;

      case "security":
        // Track security events
        appInsights.defaultClient.trackEvent({
          name: "SecurityEvent",
          properties: {
            message: message,
            logType: "security",
            level: level,
            service: "banv-backend-security",
            severity: mapLogLevel(level),
            ...filteredMeta,
          },
        });

        // Also track as trace for queries
        appInsights.defaultClient.trackTrace({
          message: `[SECURITY] ${message}`,
          properties: {
            logType: "security",
            level: level,
            service: "banv-backend-security",
            severity: mapLogLevel(level),
            category: "security",
            ...filteredMeta,
          },
        });
        break;

      case "app":
      default:
        if (level === "error" && (filteredMeta.error || filteredMeta.stack)) {
          // Track application errors as exceptions
          const error = new Error(filteredMeta.error?.message || message);
          if (filteredMeta.error?.stack || filteredMeta.stack) {
            error.stack = filteredMeta.error?.stack || filteredMeta.stack;
          }

          appInsights.defaultClient.trackException({
            exception: error,
            properties: {
              logType: "application",
              level: level,
              service: "banv-backend-app",
              severity: "critical",
              ...filteredMeta,
            },
          });
        } else {
          // Track regular application logs as traces
          appInsights.defaultClient.trackTrace({
            message: message,
            properties: {
              logType: "application",
              level: level,
              service: "banv-backend-app",
              severity: mapLogLevel(level),
              ...filteredMeta,
            },
          });
        }
        break;
    }
  } catch (error) {
    console.error("Error sending log to Application Insights:", error);
  }
};

// Helper functions for structured logging
export const logger = {
  // Request logging helpers
  request: {
    info: (message: string, meta?: any) => {
      const filteredMeta = filterSensitiveData(meta);
      requestLogger.info(message, filteredMeta);
      sendToApplicationInsights(message, filteredMeta, "request", "info");
    },
    warn: (message: string, meta?: any) => {
      const filteredMeta = filterSensitiveData(meta);
      requestLogger.warn(message, filteredMeta);
      sendToApplicationInsights(message, filteredMeta, "request", "warn");
    },
    error: (message: string, meta?: any) => {
      const filteredMeta = filterSensitiveData(meta);
      requestLogger.error(message, filteredMeta);
      sendToApplicationInsights(message, filteredMeta, "request", "error");
    },
  },

  // Application logging helpers
  app: {
    debug: (message: string, meta?: any) => {
      const filteredMeta = filterSensitiveData(meta);
      appLogger.debug(message, filteredMeta);
      sendToApplicationInsights(message, filteredMeta, "app", "debug");
    },
    info: (message: string, meta?: any) => {
      const filteredMeta = filterSensitiveData(meta);
      appLogger.info(message, filteredMeta);
      sendToApplicationInsights(message, filteredMeta, "app", "info");
    },
    warn: (message: string, meta?: any) => {
      const filteredMeta = filterSensitiveData(meta);
      appLogger.warn(message, filteredMeta);
      sendToApplicationInsights(message, filteredMeta, "app", "warn");
    },
    error: (message: string, meta?: any) => {
      const filteredMeta = filterSensitiveData(meta);
      appLogger.error(message, filteredMeta);
      sendToApplicationInsights(message, filteredMeta, "app", "error");
    },
  },

  // Security logging helpers
  security: {
    info: (message: string, meta?: any) => {
      const filteredMeta = filterSensitiveData(meta);
      securityLogger.info(message, filteredMeta);
      sendToApplicationInsights(message, filteredMeta, "security", "info");
    },
    warn: (message: string, meta?: any) => {
      const filteredMeta = filterSensitiveData(meta);
      securityLogger.warn(message, filteredMeta);
      sendToApplicationInsights(message, filteredMeta, "security", "warn");
    },
    error: (message: string, meta?: any) => {
      const filteredMeta = filterSensitiveData(meta);
      securityLogger.error(message, filteredMeta);
      sendToApplicationInsights(message, filteredMeta, "security", "error");
    },
  },
};

export { filterSensitiveData };
