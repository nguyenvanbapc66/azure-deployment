import { Request, Response, NextFunction } from "express";
import { logger } from "../utils";

export type AppError = Error & {
  status?: number;
  statusCode?: number;
};

export const errorHandler = (err: AppError, req: Request, res: Response, next: NextFunction) => {
  const statusCode = err.status || err.statusCode || 500;
  const requestId = (req as any).requestId;

  // Log error with context
  logger.app.error("Application error occurred", {
    requestId,
    method: req.method,
    url: req.originalUrl || req.url,
    path: req.path,
    error: {
      message: err.message,
      stack: err.stack,
      name: err.name,
      statusCode,
    },
    ip: req.socket.remoteAddress,
    userAgent: req.get("User-Agent"),
    timestamp: new Date().toISOString(),
  });

  // Send error response
  res.status(statusCode).json({
    message: err.message || "Internal Server Error",
    requestId,
    timestamp: new Date().toISOString(),
    ...(process.env.NODE_ENV === "development" && { stack: err.stack }),
  });
};

export const notFoundHandler = (req: Request, res: Response, next: NextFunction) => {
  const requestId = (req as any).requestId;

  // Log 404 errors
  logger.request.warn("Route not found", {
    requestId,
    method: req.method,
    url: req.originalUrl || req.url,
    path: req.path,
    ip: req.socket.remoteAddress,
    userAgent: req.get("User-Agent"),
    timestamp: new Date().toISOString(),
  });

  if (req.path.startsWith("/api/")) {
    res.status(404).json({
      message: "API endpoint not found",
      status: "not_found",
      timestamp: new Date().toISOString(),
      path: req.path,
      requestId,
    });
  } else {
    res.status(404).json({
      message: "Not Found",
      status: "not_found",
      timestamp: new Date().toISOString(),
      path: req.path,
      requestId,
    });
  }
};
