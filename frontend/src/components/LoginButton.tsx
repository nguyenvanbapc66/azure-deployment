import { useState, useEffect } from "react";

interface User {
  name?: string;
  email?: string;
  picture?: string;
  sub?: string;
}

interface LoginButtonProps {
  apiUrl?: string;
}

const LoginButton: React.FC<LoginButtonProps> = ({ apiUrl = "http://localhost:3000" }) => {
  const [isLoading, setIsLoading] = useState(false);
  const [user, setUser] = useState<User | null>(null);

  const handleLogin = async () => {
    setIsLoading(true);
    try {
      console.log("Attempting Banv OIDC login...");
      const response = await fetch(`${apiUrl}/oauth/login`);
      const data = await response.json();

      if (data.authUrl) {
        console.log("Opening Banv OIDC popup:", data.authUrl);

        // Open popup window
        const popup = window.open(
          data.authUrl,
          "banv-oidc",
          "width=500,height=600,scrollbars=yes,resizable=yes,status=yes,location=yes"
        );

        if (!popup) {
          alert("Popup blocked! Please allow popups for this site.");
          return;
        }

        // Poll for popup close or redirect
        const checkClosed = setInterval(() => {
          if (popup.closed) {
            clearInterval(checkClosed);
            console.log("OIDC popup closed, checking user status... ", user);
          }
        }, 1000);

        // Listen for messages from popup
        const messageHandler = (event: MessageEvent) => {
          if (event.origin !== window.location.origin) return;
          if (event.data.type === "OAUTH_SUCCESS") {
            console.log("Received OAuth success message:", event.data.user);
            setUser(event.data.user);
            popup.close();
            window.removeEventListener("message", messageHandler);
          }
        };
        window.addEventListener("message", messageHandler);
      } else {
        console.error("No auth URL received");
        alert("Failed to get OAuth URL");
      }
    } catch (error) {
      console.error("OAuth login error:", error);
      alert("Login failed. Please try again.");
    } finally {
      setIsLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      await fetch(`${apiUrl}/oauth/logout`);
      setUser(null);
    } catch (error) {
      console.error("Logout error:", error);
    }
  };

  // Check for user info in URL params (after OAuth callback)
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const userParam = urlParams.get("user");
    const isPopup = urlParams.get("popup") === "true";

    if (userParam) {
      try {
        const userInfo = JSON.parse(decodeURIComponent(userParam));

        if (isPopup) {
          // If this is a popup, send message to parent and close
          if (window.opener) {
            window.opener.postMessage({ type: "OAUTH_SUCCESS", user: userInfo }, window.location.origin);
            window.close();
          }
        } else {
          // Normal flow - set user state
          setUser(userInfo);
          // Clean up URL
          window.history.replaceState({}, document.title, window.location.pathname);
        }
      } catch (error) {
        console.error("Error parsing user info:", error);
      }
    }
  }, []);

  if (user) {
    return (
      <div
        style={{
          padding: "20px",
          border: "1px solid #ccc",
          borderRadius: "8px",
          margin: "20px 0",
        }}
      >
        <h3>Welcome, {user.name || user.email || "User"}!</h3>
        <p>Email: {user.email}</p>
        {user.picture && (
          <img src={user.picture} alt="Profile" style={{ width: "50px", height: "50px", borderRadius: "50%" }} />
        )}
        <button
          onClick={handleLogout}
          style={{
            backgroundColor: "#dc3545",
            color: "white",
            border: "none",
            padding: "10px 20px",
            borderRadius: "5px",
            cursor: "pointer",
            marginTop: "10px",
          }}
        >
          Logout
        </button>
      </div>
    );
  }

  return (
    <div style={{ textAlign: "center", margin: "20px 0" }}>
      <button
        onClick={handleLogin}
        disabled={isLoading}
        style={{
          backgroundColor: "#007bff",
          color: "white",
          border: "none",
          padding: "12px 24px",
          borderRadius: "5px",
          cursor: isLoading ? "not-allowed" : "pointer",
          fontSize: "16px",
          fontWeight: "bold",
          boxShadow: "0 2px 4px rgba(0,0,0,0.1)",
        }}
      >
        {isLoading ? "Logging in..." : "Login with Banv OIDC"}
      </button>
    </div>
  );
};

export default LoginButton;
