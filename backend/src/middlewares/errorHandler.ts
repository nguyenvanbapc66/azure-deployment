import { Request, Response, NextFunction } from "express";

export type AppError = Error & {
  status?: number;
};

export const errorHandler = (err: AppError, req: Request, res: Response, next: NextFunction) => {
  console.error(err);
  res.status(err.status || 500).json({
    message: err.message || "Internal Server Error",
  });
};

export const notFoundHandler = (req: Request, res: Response, next: NextFunction) => {
  if (req.path.startsWith("/api/")) {
    res.status(404).json({
      message: "API endpoint not found",
      status: "not_found",
      timestamp: new Date().toISOString(),
      path: req.path,
    });
  } else {
    res.status(404).json({
      message: "Not Found",
      status: "not_found",
      timestamp: new Date().toISOString(),
      path: req.path,
    });
  }
};
