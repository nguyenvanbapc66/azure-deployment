import { ApplicationInsights } from "@microsoft/applicationinsights-web";
import { ReactPlugin } from "@microsoft/applicationinsights-react-js";

let appInsights: ApplicationInsights | null = null;
let reactPlugin: ReactPlugin | null = null;

export const initializeAppInsights = () => {
  const connectionString = import.meta.env.VITE_APPLICATIONINSIGHTS_CONNECTION_STRING;

  if (!connectionString) {
    console.warn("VITE_APPLICATIONINSIGHTS_CONNECTION_STRING not found - Application Insights disabled");
    return { appInsights: null, reactPlugin: null };
  }

  try {
    reactPlugin = new ReactPlugin();

    appInsights = new ApplicationInsights({
      config: {
        connectionString: connectionString,
        enableAutoRouteTracking: true,
        enableCorsCorrelation: true,
        enableRequestHeaderTracking: true,
        enableResponseHeaderTracking: true,
        enableAjaxErrorStatusText: true,
        enableUnhandledPromiseRejectionTracking: true,
        extensions: [reactPlugin],
        extensionConfig: {
          [reactPlugin.identifier]: {
            debug: import.meta.env.DEV,
          },
        },
      },
    });

    appInsights.loadAppInsights();

    // Set user context
    appInsights.setAuthenticatedUserContext("user-" + Date.now(), "banv-app");

    console.log("Application Insights initialized successfully");

    return { appInsights, reactPlugin };
  } catch (error) {
    console.error("Failed to initialize Application Insights:", error);
    return { appInsights: null, reactPlugin: null };
  }
};

export const getAppInsights = () => appInsights;
export const getReactPlugin = () => reactPlugin;

// Custom telemetry functions
export const trackEvent = (name: string, properties?: Record<string, string | number | boolean>) => {
  if (appInsights) {
    appInsights.trackEvent({ name, properties });
  }
};

export const trackException = (exception: Error, properties?: Record<string, string | number | boolean>) => {
  if (appInsights) {
    appInsights.trackException({ exception, properties });
  }
};

export const trackPageView = (name: string, uri?: string) => {
  if (appInsights) {
    appInsights.trackPageView({ name, uri });
  }
};

export const trackMetric = (name: string, average: number, properties?: Record<string, string | number | boolean>) => {
  if (appInsights) {
    appInsights.trackMetric({ name, average }, properties);
  }
};
