import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";
import { initializeAppInsights } from "./services/applicationInsights";

// Initialize Application Insights
const { appInsights } = initializeAppInsights();

// Add global error handler for unhandled errors
window.addEventListener("error", (event) => {
  if (appInsights) {
    appInsights.trackException({
      exception: new Error(event.message),
      properties: {
        filename: event.filename,
        lineno: event.lineno,
        colno: event.colno,
      },
    });
  }
});

createRoot(document.getElementById("root")!).render(<App />);
