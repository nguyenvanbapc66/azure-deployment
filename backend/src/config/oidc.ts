import { Provider } from "oidc-provider";
import type { ClientAuthMethod, ClientMetadata } from "oidc-provider";

// OIDC Configuration
export const OIDC_CONFIG = {
  issuer: "https://id-dev.mindx.edu.vn",
  clients: [
    {
      client_id: "banv-aks",
      client_secret: "banv-aks-secret",
      grant_types: ["authorization_code"],
      redirect_uris: [
        "http://localhost:3000/oauth/openid/callback",
        "https://banv-api-dev.mindx.edu.vn/oauth/openid/callback",
      ],
      response_types: ["code"],
      token_endpoint_auth_method: "client_secret_post" as ClientAuthMethod,
    },
  ] as ClientMetadata[],
  scopes: ["openid", "profile", "email"],
  claims: {
    openid: ["sub"],
    profile: ["name", "given_name", "family_name", "preferred_username"],
    email: ["email", "email_verified"],
  },
  cookies: {
    keys: [process.env.SESSION_SECRET || "fallback-secret-key"],
    long: {
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax" as const,
    },
    short: {
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax" as const,
    },
  },
  features: {
    devInteractions: { enabled: false },
  },
  pkce: {
    required: () => false,
  },
  interactions: {
    url(ctx: any, interaction: any) {
      return `/oidc/interaction/${interaction.uid}`;
    },
  },
};

// Mock user data for development
const mockUsers = [
  {
    id: "1",
    email: "banv@mindx.com.vn",
    name: "BanV User",
    given_name: "BanV",
    family_name: "User",
    preferred_username: "banv",
    email_verified: true,
  },
];

export const findUserById = async (id: string) => {
  return mockUsers.find((user) => user.id === id);
};

export const createOIDCProvider = () => {
  try {
    const oidc = new Provider(OIDC_CONFIG.issuer, {
      clients: OIDC_CONFIG.clients,
      cookies: OIDC_CONFIG.cookies,
      scopes: OIDC_CONFIG.scopes,
      claims: OIDC_CONFIG.claims,
      features: OIDC_CONFIG.features,
      pkce: OIDC_CONFIG.pkce,
      interactions: OIDC_CONFIG.interactions,

      async findAccount(ctx: any, id: string) {
        console.log(`OIDC findAccount: ${id}`);
        const user = await findUserById(id);
        if (!user) {
          return undefined;
        }

        return {
          accountId: id,
          async claims(use: any, scope: any) {
            const userClaims = {
              sub: id,
              ...user,
            };

            const requestedClaims: any = {};
            if (scope && scope.includes("openid")) {
              requestedClaims.sub = userClaims.sub;
            }
            if (scope && scope.includes("profile")) {
              requestedClaims.name = userClaims.name;
              requestedClaims.given_name = userClaims.given_name;
              requestedClaims.family_name = userClaims.family_name;
              requestedClaims.preferred_username = userClaims.preferred_username;
            }
            if (scope && scope.includes("email")) {
              requestedClaims.email = userClaims.email;
              requestedClaims.email_verified = userClaims.email_verified;
            }

            console.log(`OIDC claims for ${id}:`, requestedClaims);
            return requestedClaims;
          },
        };
      },

      async loadExistingGrant(ctx: any) {
        const grantId = ctx.oidc.result?.consent?.grantId || ctx.oidc.session?.grantIdFor?.(ctx.oidc.client!.clientId);

        if (grantId) {
          return ctx.oidc.provider.Grant.find(grantId);
        }

        const grant = new ctx.oidc.provider.Grant({
          clientId: ctx.oidc.client!.clientId,
          accountId: ctx.oidc.session!.accountId!,
        });

        grant.addOIDCScope("openid");
        grant.addOIDCScope("profile");
        grant.addOIDCScope("email");

        grant.addOIDCClaims(["sub"]);
        grant.addOIDCClaims(["name", "given_name", "family_name", "preferred_username"]);
        grant.addOIDCClaims(["email", "email_verified"]);

        await grant.save();
        return grant;
      },

      renderError(ctx: any, out: any, error: any) {
        console.error("OIDC Provider Error:", {
          error: out.error,
          description: out.error_description,
          message: error.message,
          name: error.name,
        });

        ctx.type = "html";
        ctx.body = `
          <!DOCTYPE html>
          <html>
          <head>
            <title>Authentication Error</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
              body { 
                font-family: Arial, sans-serif; 
                margin: 40px auto; 
                max-width: 600px; 
                padding: 20px;
              }
              .error { 
                background: #f8d7da; 
                color: #721c24; 
                padding: 20px; 
                border-radius: 8px; 
                border: 1px solid #f5c6cb;
              }
              .back-link { 
                margin-top: 20px; 
                text-align: center; 
              }
              .back-link a { 
                color: #007cba; 
                text-decoration: none; 
              }
              .back-link a:hover { 
                text-decoration: underline; 
              }
            </style>
          </head>
          <body>
            <div class="error">
              <h1>Authentication Error</h1>
              <p><strong>Error:</strong> ${out.error}</p>
              <p><strong>Description:</strong> ${out.error_description}</p>
              ${out.state ? `<p><strong>State:</strong> ${out.state}</p>` : ""}
            </div>
            <div class="back-link">
              <a href="/">← Back to Home</a>
            </div>
          </body>
          </html>
        `;
      },
    });

    // Configure proxy trust
    oidc.app.proxy = true;

    return oidc;
  } catch (error) {
    console.error("Failed to create OIDC Provider:", error);
    throw error;
  }
};
