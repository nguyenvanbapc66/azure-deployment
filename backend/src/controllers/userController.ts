import { Request, Response, NextFunction } from "express";
import { logger } from "../utils/logger";
import { LOG_MESSAGE } from "../constants";

type PreferencesType = {
  theme: string;
  notifications: boolean;
  newsletter: boolean;
};

type UserType = {
  id: number;
  username: string;
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  phone: string;
  role: string;
  lastLogin: string;
  token?: string;
  apiKey?: string;
  preferences: PreferencesType;
};

type SocialType = {
  id: number;
  userId: number;
  platform: string;
  username: string;
  accessToken: string;
  refreshToken?: string;
  profileUrl?: string;
  isPublic?: boolean;
  connectedAt?: string;
};

// Mock user data - includes sensitive information to test filtering
const mockUsers: UserType[] = [
  {
    id: 1,
    username: "john_doe",
    email: "john@example.com",
    password: "super_secret_password_123", // This will be filtered out
    firstName: "John",
    lastName: "Doe",
    phone: "+1-555-0123",
    role: "user",
    lastLogin: "2024-01-20T10:30:00Z",
    apiKey: "sk_test_1234567890abcdef", // This will be filtered out
    preferences: {
      theme: "dark",
      notifications: true,
      newsletter: false,
    },
  },
  {
    id: 2,
    username: "jane_smith",
    email: "jane@example.com",
    password: "another_secret_password", // This will be filtered out
    firstName: "Jane",
    lastName: "Smith",
    phone: "+1-555-0124",
    role: "admin",
    lastLogin: "2024-01-20T09:15:00Z",
    token: "bearer_token_xyz789", // This will be filtered out
    preferences: {
      theme: "light",
      notifications: true,
      newsletter: true,
    },
  },
];

// Mock social data - includes sensitive information
const mockSocials: SocialType[] = [
  {
    id: 1,
    userId: 1,
    platform: "github",
    username: "john_doe_dev",
    accessToken: "ghp_xxxxxxxxxxxxxxxxxxxx", // This will be filtered out
    refreshToken: "refresh_token_github", // This will be filtered out
    profileUrl: "https://github.com/john_doe_dev",
    isPublic: true,
    connectedAt: "2024-01-15T14:20:00Z",
  },
  {
    id: 2,
    userId: 1,
    platform: "twitter",
    username: "@johndoe",
    accessToken: "twitter_access_token_secret", // This will be filtered out
    profileUrl: "https://twitter.com/johndoe",
    isPublic: false,
    connectedAt: "2024-01-16T10:45:00Z",
  },
  {
    id: 3,
    userId: 2,
    platform: "linkedin",
    username: "jane-smith-dev",
    accessToken: "linkedin_bearer_token_xyz", // This will be filtered out
    profileUrl: "https://linkedin.com/in/jane-smith-dev",
    isPublic: true,
    connectedAt: "2024-01-18T08:30:00Z",
  },
];

// GET /api/user/information - Returns user information (sensitive data will be filtered in logs)
export const getUserInformation = async (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();
  const requestId = (req as any).requestId;

  try {
    // Log request processing start
    logger.app.info(LOG_MESSAGE.USER.INFORMATION_SUCCESS, {
      requestId,
      endpoint: "getUserInformation",
      query: req.query,
      userAgent: req.get("User-Agent"),
      ip: req.socket.remoteAddress,
    });

    // Simulate some processing time
    await new Promise((resolve) => setTimeout(resolve, Math.random() * 200 + 50));

    const userId = req.query.userId ? parseInt(req.query.userId as string, 10) : 1;
    const user = mockUsers.find((u) => u.id === userId);

    if (!user) {
      logger.app.warn(LOG_MESSAGE.USER.INFORMATION_WARNING, {
        requestId,
        userId,
        endpoint: "getUserInformation",
      });
      return res.status(404).json({
        error: "User not found",
        userId,
        timestamp: new Date().toISOString(),
        requestId,
      });
    }

    // Remove sensitive fields from response (but they'll still be filtered in logs if we log the user object)
    const userResponse = {
      id: user.id,
      username: user.username,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      phone: user.phone,
      role: user.role,
      lastLogin: user.lastLogin,
      preferences: user.preferences,
    };

    const processingTime = Date.now() - startTime;

    // Log successful processing with full user object (sensitive data will be filtered by logger)
    logger.app.info(LOG_MESSAGE.USER.INFORMATION_SUCCESS, {
      requestId,
      userId: user.id,
      processingTime: `${processingTime}ms`,
      endpoint: "getUserInformation",
      // This will have sensitive data filtered out by the logger
      userData: user,
    });

    // Return response
    res.status(200).json({
      success: true,
      data: userResponse,
      timestamp: new Date().toISOString(),
      requestId,
      processingTime: `${processingTime}ms`,
    });
  } catch (error) {
    const processingTime = Date.now() - startTime;

    logger.app.error(LOG_MESSAGE.USER.INFORMATION_ERROR, {
      requestId,
      error: error instanceof Error ? error.message : "Unknown error",
      stack: error instanceof Error ? error.stack : undefined,
      processingTime: `${processingTime}ms`,
      endpoint: "getUserInformation",
    });

    next(error);
  }
};

// GET /api/user/socials - Returns user social connections (sensitive data will be filtered in logs)
export const getUserSocials = async (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();
  const requestId = (req as any).requestId;

  try {
    // Log request processing start
    logger.app.info(LOG_MESSAGE.USER.SOCIALS_SUCCESS, {
      requestId,
      endpoint: "getUserSocials",
      query: req.query,
      userAgent: req.get("User-Agent"),
      ip: req.socket.remoteAddress,
    });

    // Simulate some processing time
    await new Promise((resolve) => setTimeout(resolve, Math.random() * 300 + 100));

    const userId = req.query.userId ? parseInt(req.query.userId as string, 10) : 1;
    const userSocials = mockSocials.filter((s) => s.userId === userId);

    // Check if user exists
    const userExists = mockUsers.find((u) => u.id === userId);
    if (!userExists) {
      logger.app.warn(LOG_MESSAGE.USER.SOCIALS_WARNING, {
        requestId,
        userId,
        endpoint: "getUserSocials",
      });
      return res.status(404).json({
        error: "User not found",
        userId,
        timestamp: new Date().toISOString(),
        requestId,
      });
    }

    // Remove sensitive fields from response
    const socialsResponse = userSocials.map((social) => ({
      id: social.id,
      platform: social.platform,
      username: social.username,
      profileUrl: social.profileUrl,
      isPublic: social.isPublic,
      connectedAt: social.connectedAt,
    }));

    const processingTime = Date.now() - startTime;

    // Log successful processing with full social objects (sensitive data will be filtered by logger)
    logger.app.info(LOG_MESSAGE.USER.SOCIALS_SUCCESS, {
      requestId,
      userId,
      socialCount: userSocials.length,
      processingTime: `${processingTime}ms`,
      endpoint: "getUserSocials",
      // This will have sensitive data (tokens) filtered out by the logger
      socialsData: userSocials,
    });

    // Return response
    res.status(200).json({
      success: true,
      data: socialsResponse,
      count: socialsResponse.length,
      timestamp: new Date().toISOString(),
      requestId,
      processingTime: `${processingTime}ms`,
    });
  } catch (error) {
    const processingTime = Date.now() - startTime;

    logger.app.error(LOG_MESSAGE.USER.SOCIALS_ERROR, {
      requestId,
      error: error instanceof Error ? error.message : "Unknown error",
      stack: error instanceof Error ? error.stack : undefined,
      processingTime: `${processingTime}ms`,
      endpoint: "getUserSocials",
    });

    next(error);
  }
};

// GET /api/error - Intentionally throws a 500 error for testing error logging
export const triggerError = async (req: Request, res: Response, next: NextFunction) => {
  const requestId = (req as any).requestId;
  const startTime = Date.now();

  try {
    // Log that we're about to trigger an error (for testing)
    logger.app.info(LOG_MESSAGE.USER.ERROR_SUCCESS, {
      requestId,
      endpoint: "triggerError",
      query: req.query,
      userAgent: req.get("User-Agent"),
      ip: req.socket.remoteAddress,
      purpose: "error_logging_test",
    });

    // Simulate some processing before error
    await new Promise((resolve) => setTimeout(resolve, Math.random() * 100 + 50));

    const errorType = (req.query.type as string) || "server";

    // Different types of errors for testing
    switch (errorType) {
      case "validation":
        const validationError = new Error("Invalid request data provided") as any;
        validationError.status = 400;
        throw validationError;

      case "unauthorized":
        const authError = new Error("Unauthorized access attempt") as any;
        authError.status = 401;
        // Log security event
        logger.security.warn(LOG_MESSAGE.USER.ERROR_WARNING, {
          requestId,
          ip: req.socket.remoteAddress,
          userAgent: req.get("User-Agent"),
          endpoint: "triggerError",
        });
        throw authError;

      case "forbidden":
        const forbiddenError = new Error("Forbidden action attempted") as any;
        forbiddenError.status = 403;
        throw forbiddenError;

      case "notfound":
        const notFoundError = new Error("Resource not found") as any;
        notFoundError.status = 404;
        throw notFoundError;

      case "server":
      default:
        // Simulate a server error with sensitive data that should be filtered
        const serverError = new Error("Internal server error occurred while processing request") as any;
        serverError.status = 500;
        serverError.sensitiveData = {
          password: "super_secret_db_password",
          apiKey: "sk_live_production_key_12345",
          dbConnection: "postgresql://user:pass@localhost:5432/prod_db",
        };
        throw serverError;
    }
  } catch (error) {
    const processingTime = Date.now() - startTime;

    // Log the error with context (sensitive data will be filtered)
    logger.app.error(LOG_MESSAGE.USER.ERROR_ERROR, {
      requestId,
      errorType: req.query.type || "server",
      error: error instanceof Error ? error.message : "Unknown error",
      stack: error instanceof Error ? error.stack : undefined,
      processingTime: `${processingTime}ms`,
      endpoint: "triggerError",
      // This sensitive data will be filtered out
      errorContext: (error as any).sensitiveData,
    });

    next(error);
  }
};
