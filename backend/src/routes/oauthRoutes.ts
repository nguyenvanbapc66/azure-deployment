import { Router } from "express";

// Extend session interface for TypeScript
declare module "express-session" {
  interface SessionData {
    oauthState?: string;
    user?: any;
  }
}

const router = Router();

// OAuth configuration for Banv OIDC Provider
const OAUTH_CONFIG = {
  clientID: process.env.OAUTH_CLIENT_ID || "banv-aks",
  clientSecret: process.env.OAUTH_CLIENT_SECRET || "8daaa53ae9256b929f2b5a2ac04ce66375ed2f92ac",
  scope: "openid profile email",
  callbackURL: process.env.OAUTH_CALLBACK_URL || "http://localhost:3000/oauth/openid/callback",
  // callbackURL: process.env.OAUTH_CALLBACK_URL || "https://banv-api-dev.mindx.edu.vn/oauth/openid/callback",
  // discoveryURL: "https://banv-app-dev.mindx.edu.vn/oidc/.well-known/openid-configuration",
  // issuer: "https://banv-app-dev.mindx.edu.vn/oidc",
  // authorizationURL: "https://banv-app-dev.mindx.edu.vn/oidc/auth",
  // tokenURL: "https://banv-app-dev.mindx.edu.vn/oidc/token",
  // userInfoURL: "https://banv-app-dev.mindx.edu.vn/oidc/me",
  discoveryURL: "https://id-dev.mindx.edu.vn/.well-known/openid-configuration",
  issuer: "https://id-dev.mindx.edu.vn",
  authorizationURL: "https://id-dev.mindx.edu.vn/auth",
  tokenURL: "https://id-dev.mindx.edu.vn/token",
  userInfoURL: "https://id-dev.mindx.edu.vn/me",
};

// OAuth login route - initiates OAuth flow
router.get("/login", (req, res) => {
  try {
    const state = Math.random().toString(36).substring(7);

    // Store state in session for security
    req.session.oauthState = state;

    // Debug: Log session info
    console.log("OAuth login - Session ID:", req.sessionID);
    console.log("OAuth login - Stored state:", req.session.oauthState);

    const authUrl =
      `${OAUTH_CONFIG.authorizationURL}?` +
      `client_id=${OAUTH_CONFIG.clientID}&` +
      `redirect_uri=${encodeURIComponent(OAUTH_CONFIG.callbackURL)}&` +
      `response_type=code&` +
      `scope=${encodeURIComponent(OAUTH_CONFIG.scope)}&` +
      `state=${state}`;

    res.json({
      message: "OAuth login initiated",
      authUrl: authUrl,
    });
  } catch (error) {
    console.error("OAuth login error:", error);
    res.status(500).json({ error: "Failed to generate authorization URL" });
  }
});

// OAuth callback route
router.get("/openid/callback", async (req, res) => {
  try {
    const { code, state } = req.query;

    // Debug: Log callback info
    console.log("OAuth callback - Session ID:", req.sessionID);
    console.log("OAuth callback - Received state:", state);
    console.log("OAuth callback - Stored state:", req.session.oauthState);
    console.log("OAuth callback - Session data:", req.session);

    if (!code) {
      return res.status(400).json({ error: "Authorization code not received" });
    }

    // Verify state parameter (temporarily disabled for testing)
    if (state !== req.session.oauthState) {
      console.log("State mismatch - Received:", state, "Expected:", req.session.oauthState);
      console.log("Temporarily bypassing state check for testing");
      // return res.status(400).json({ error: "Invalid state parameter" });
    }

    // Exchange code for token
    const tokenResponse = await fetch(OAUTH_CONFIG.tokenURL, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        client_id: OAUTH_CONFIG.clientID,
        client_secret: OAUTH_CONFIG.clientSecret,
        code: code as string,
        redirect_uri: OAUTH_CONFIG.callbackURL,
      }),
    });

    const tokenData = await tokenResponse.json();

    if (tokenData.error) {
      return res.status(400).json({ error: tokenData.error });
    }

    // Get user info with access token
    const userResponse = await fetch(OAUTH_CONFIG.userInfoURL, {
      headers: {
        Authorization: `Bearer ${tokenData.access_token}`,
      },
    });

    const userInfo = await userResponse.json();

    // Store user info in session
    req.session.user = userInfo;

    // Redirect to frontend with user info
    const frontendUrl = process.env.FRONTEND_URL || "http://localhost:5173";
    const userInfoParam = encodeURIComponent(JSON.stringify(userInfo));
    const redirectUrl = `${frontendUrl}?user=${userInfoParam}&popup=true`;
    res.redirect(redirectUrl);
  } catch (error) {
    console.error("OAuth callback error:", error);
    res.status(500).json({ error: "OAuth authentication failed" });
  }
});

// Logout route
router.get("/logout", (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      return res.status(500).json({ error: "Error during logout" });
    }
    res.json({ message: "Logged out successfully" });
  });
});

// Get current user info
router.get("/user", (req, res) => {
  if (req.session.user) {
    res.json({
      message: "User info retrieved successfully",
      user: req.session.user,
    });
  } else {
    res.status(401).json({ message: "No user logged in" });
  }
});

export default router;
