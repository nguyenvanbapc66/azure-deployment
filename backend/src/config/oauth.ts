// MindX OAuth Configuration
export const OAUTH_CONFIG = {
  // OIDC Provider Endpoints (banv custom provider)
  issuer: "https://id-dev.mindx.edu.vn",
  authorizationURL: "https://id-dev.mindx.edu.vn/auth",
  tokenURL: "https://id-dev.mindx.edu.vn/token",
  userInfoURL: "https://id-dev.mindx.edu.vn/me",
  discoveryURL: "https://id-dev.mindx.edu.vn/.well-known/openid_configuration",

  // Client Configuration (using banv-aks values)
  clientID: process.env.OAUTH_CLIENT_ID || "banv-aks",
  clientSecret: process.env.OAUTH_CLIENT_SECRET || "banv-aks-secret",

  // Callback URLs
  callbackURL: process.env.OAUTH_CALLBACK_URL || "http://localhost:3000/oauth/openid/callback",

  // Scopes
  scope: "openid profile email",

  // Additional OAuth settings
  state: true,
  responseType: "code",
  grantType: "authorization_code",
};

// Environment-specific configurations
export const getOAuthConfig = () => {
  const isProduction = process.env.NODE_ENV === "production";

  return {
    ...OAUTH_CONFIG,
    callbackURL: isProduction
      ? "https://banv-api-dev.mindx.edu.vn/oauth/openid/callback"
      : "http://localhost:3000/oauth/openid/callback",
  };
};
