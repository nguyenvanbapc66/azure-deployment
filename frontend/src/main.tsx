import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";
// Temporarily disabled for debugging
// import "./services/applicationInsights";

// The Application Insights initialization happens automatically when importing
// Global error handler is now handled by the service

createRoot(document.getElementById("root")!).render(<App />);
