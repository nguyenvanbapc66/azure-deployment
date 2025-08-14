import { Request, Response, NextFunction } from "express";
import { logger, filterSensitiveData } from "../utils";

// Extract IP address from request
const getClientIp = (req: Request): string => {
  return (req.headers["x-forwarded-for"] as string)?.split(",")[0]?.trim() || req.socket.remoteAddress || "unknown";
};

// Get request size
const getRequestSize = (req: Request): number => {
  const contentLength = req.headers["content-length"];
  return contentLength ? parseInt(contentLength, 10) : 0;
};

// Get response size
const getResponseSize = (res: Response): number => {
  return res.get("content-length") ? parseInt(res.get("content-length")!, 10) : 0;
};

// Generate request ID
const generateRequestId = (): string => {
  return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
};

// Log request start
const logRequestStart = (req: Request & { requestId?: string }): void => {
  const requestId = generateRequestId();
  req.requestId = requestId;

  const requestData = {
    requestId,
    method: req.method,
    url: req.originalUrl || req.url,
    path: req.path,
    query: filterSensitiveData(req.query),
    headers: filterSensitiveData({
      "user-agent": req.get("User-Agent"),
      "content-type": req.get("Content-Type"),
      accept: req.get("Accept"),
      origin: req.get("Origin"),
      referer: req.get("Referer"),
      // Exclude sensitive headers like Authorization
      "x-forwarded-for": req.get("X-Forwarded-For"),
      "x-real-ip": req.get("X-Real-IP"),
    }),
    ip: getClientIp(req),
    requestSize: getRequestSize(req),
    timestamp: new Date().toISOString(),
  };

  logger.request.info("Request started", requestData);
};

// Log request completion
const logRequestComplete = (req: Request & { requestId?: string }, res: Response, startTime: number): void => {
  const duration = Date.now() - startTime;
  const statusCode = res.statusCode;

  const responseData = {
    requestId: req.requestId,
    method: req.method,
    url: req.originalUrl || req.url,
    path: req.path,
    statusCode,
    statusMessage: res.statusMessage,
    duration: `${duration}ms`,
    responseSize: getResponseSize(res),
    ip: getClientIp(req),
    userAgent: req.get("User-Agent"),
    timestamp: new Date().toISOString(),
    // Add performance categorization
    performance: {
      category: duration < 100 ? "fast" : duration < 500 ? "normal" : duration < 1000 ? "slow" : "very_slow",
      threshold: duration,
    },
  };

  // Determine log level based on status code
  if (statusCode >= 500) {
    logger.request.error("Request completed with server error", responseData);
  } else if (statusCode >= 400) {
    logger.request.warn("Request completed with client error", responseData);
  } else {
    logger.request.info("Request completed successfully", responseData);
  }

  // Log slow requests separately for monitoring
  if (duration > 1000) {
    logger.app.warn("Slow request detected", {
      requestId: req.requestId,
      duration: `${duration}ms`,
      endpoint: `${req.method} ${req.path}`,
      statusCode,
      ip: getClientIp(req),
    });
  }
};

// Main request logging middleware
export const requestLogger = (req: Request, res: Response, next: NextFunction): void => {
  const startTime = Date.now();

  // Log request start
  logRequestStart(req as Request & { requestId?: string });

  // Track original res.json to log response data (filtered)
  const originalJson = res.json;
  res.json = function (data: any) {
    // Log response data (filtered for sensitive information)
    if (req.path.includes("/api/")) {
      logger.app.debug("API Response data", {
        requestId: (req as any).requestId,
        endpoint: `${req.method} ${req.path}`,
        responseData: filterSensitiveData(data),
        statusCode: res.statusCode,
      });
    }
    return originalJson.call(this, data);
  };

  // Log when response finishes
  res.on("finish", () => {
    logRequestComplete(req as Request & { requestId?: string }, res, startTime);
  });

  // Log when response closes (connection terminated)
  res.on("close", () => {
    if (!res.headersSent) {
      logger.request.warn("Request connection closed before response sent", {
        requestId: (req as any).requestId,
        method: req.method,
        url: req.originalUrl || req.url,
        duration: `${Date.now() - startTime}ms`,
        ip: getClientIp(req),
      });
    }
  });

  // Log uncaught errors in the request pipeline
  res.on("error", (error) => {
    logger.request.error("Response stream error", {
      requestId: (req as any).requestId,
      method: req.method,
      url: req.originalUrl || req.url,
      error: error.message,
      stack: error.stack,
      ip: getClientIp(req),
    });
  });

  next();
};

// Health check requests logger (lighter logging)
export const healthCheckLogger = (req: Request, res: Response, next: NextFunction): void => {
  // Only log health check requests at debug level to reduce noise
  if (req.path === "/health" || req.path === "/ready" || req.path === "/metrics") {
    logger.app.debug("Health check request", {
      method: req.method,
      path: req.path,
      ip: getClientIp(req),
      userAgent: req.get("User-Agent"),
    });
  }
  next();
};

// Error request logger (for 4xx and 5xx responses)
export const errorRequestLogger = (error: any, req: Request, res: Response, next: NextFunction): void => {
  const errorData = {
    requestId: (req as any).requestId,
    method: req.method,
    url: req.originalUrl || req.url,
    path: req.path,
    error: {
      message: error.message,
      stack: error.stack,
      name: error.name,
      code: error.code,
    },
    requestBody: filterSensitiveData(req.body),
    query: filterSensitiveData(req.query),
    params: req.params,
    headers: filterSensitiveData({
      "user-agent": req.get("User-Agent"),
      "content-type": req.get("Content-Type"),
      origin: req.get("Origin"),
    }),
    ip: getClientIp(req),
    timestamp: new Date().toISOString(),
  };

  logger.request.error("Request error occurred", errorData);

  // Also log to security logger if it's a potential security issue
  if (error.statusCode === 401 || error.statusCode === 403 || error.statusCode === 429) {
    logger.security.warn("Security-related request error", {
      requestId: (req as any).requestId,
      method: req.method,
      url: req.originalUrl || req.url,
      statusCode: error.statusCode,
      ip: getClientIp(req),
      userAgent: req.get("User-Agent"),
      error: error.message,
    });
  }

  next(error);
};

export default requestLogger;
