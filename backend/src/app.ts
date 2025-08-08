import express from "express";
import cors from "cors";
import session from "express-session";

import { itemRoutes, oauthRoutes } from "./routes";
import { errorHandler, notFoundHandler } from "./middlewares";

const app = express();

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

// Routes
app.use("/api/items", itemRoutes);
app.use("/oauth", oauthRoutes);

// Global error handler (should be after routes)
app.use(errorHandler);
app.use(notFoundHandler);

export default app;
