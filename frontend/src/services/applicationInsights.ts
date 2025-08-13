import { ApplicationInsights } from "@microsoft/applicationinsights-web";
import { ReactPlugin } from "@microsoft/applicationinsights-react-js";

// 🚀 ADVANCED APPLICATION INSIGHTS SETUP
const reactPlugin = new ReactPlugin();

// Get configuration from environment variables
const connectionString = import.meta.env.VITE_APPLICATIONINSIGHTS_CONNECTION_STRING || "your-connection-string";
const cloudRole = import.meta.env.VITE_APPLICATION_INSIGHTS_CLOUD_ROLE || "banv-frontend-web";
const cloudRoleInstance = import.meta.env.VITE_APPLICATION_INSIGHTS_CLOUD_ROLE_INSTANCE || "banv-frontend";

// Initialize Application Insights with ADVANCED features
const appInsights = new ApplicationInsights({
  config: {
    connectionString: connectionString,
    extensions: [reactPlugin],
    extensionConfig: {
      [reactPlugin.identifier]: {
        debug: import.meta.env.DEV,
      },
    },
    // 🔥 ADVANCED CONFIGURATION
    enableAutoRouteTracking: true,
    enableCorsCorrelation: true,
    enableRequestHeaderTracking: true,
    enableResponseHeaderTracking: true,
    enableAjaxErrorStatusText: true,
    enableUnhandledPromiseRejectionTracking: true,
    autoTrackPageVisitTime: true,
    // 📊 ADVANCED TELEMETRY
    samplingPercentage: 100,
    maxBatchInterval: 5000,
    maxBatchSizeInBytes: 102400,
    enableDebug: false,
    loggingLevelTelemetry: 2,
  },
});

appInsights.loadAppInsights();

// 🚀 CUSTOM TELEMETRY SETUP
appInsights.addTelemetryInitializer((envelope) => {
  if (envelope.tags) {
    envelope.tags["ai.cloud.role"] = cloudRole;
    envelope.tags["ai.cloud.roleInstance"] = cloudRoleInstance;
  }

  // Add custom properties to all telemetry
  if (envelope.data && envelope.data.baseData) {
    envelope.data.baseData.properties = {
      ...envelope.data.baseData.properties,
      environment: "production",
      version: "1.13.0",
      userAgent: navigator.userAgent,
      viewport: `${window.innerWidth}x${window.innerHeight}`,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      language: navigator.language,
    };
  }

  return true;
});

// 🔥 BUSINESS TRACKING FUNCTIONS
const trackBusinessEvent = (name: string, properties: Record<string, string | number | boolean> = {}) => {
  appInsights.trackEvent({
    name: name,
    properties: {
      ...properties,
      timestamp: new Date().toISOString(),
      service: cloudRole,
      source: "frontend",
    },
  });
};

const trackUserInteraction = (
  action: string,
  element: string,
  properties: Record<string, string | number | boolean> = {}
) => {
  trackBusinessEvent("UserInteraction", {
    action: action,
    element: element,
    page: window.location.pathname,
    timestamp: new Date().toISOString(),
    ...properties,
  });
};

const trackPerformanceMetric = (
  name: string,
  value: number,
  properties: Record<string, string | number | boolean> = {}
) => {
  appInsights.trackMetric({
    name: name,
    average: value,
    properties: {
      ...properties,
      timestamp: new Date().toISOString(),
      service: cloudRole,
    },
  });
};

const trackApiCall = (url: string, method: string, duration: number, statusCode: number, success: boolean) => {
  // Track as business event
  trackBusinessEvent("ApiCall", {
    url: url,
    method: method,
    duration: duration,
    statusCode: statusCode,
    success: success,
    category: "api_interaction",
  });
};

// 📊 USER JOURNEY TRACKING
const trackUserJourney = (step: string, funnel: string, properties: Record<string, string | number | boolean> = {}) => {
  trackBusinessEvent("UserJourneyStep", {
    step: step,
    funnel: funnel,
    page: window.location.pathname,
    referrer: document.referrer,
    ...properties,
  });
};

// 🎯 BUSINESS METRICS TRACKING
const trackBusinessMetric = (metric: string, value: number, category: string = "general") => {
  trackPerformanceMetric(`business.${category}.${metric}`, value, {
    category: category,
    metric: metric,
  });
};

// 🚨 ERROR TRACKING WITH CONTEXT
const trackError = (error: Error, context: Record<string, string | number | boolean> = {}) => {
  appInsights.trackException({
    exception: error,
    properties: {
      ...context,
      timestamp: new Date().toISOString(),
      page: window.location.pathname,
      userAgent: navigator.userAgent,
      service: cloudRole,
    },
  });
};

// 📈 PAGE PERFORMANCE TRACKING
const trackPagePerformance = () => {
  if (performance && performance.timing) {
    const timing = performance.timing;
    const loadTime = timing.loadEventEnd - timing.navigationStart;
    const domReadyTime = timing.domContentLoadedEventEnd - timing.navigationStart;
    const renderTime = timing.domComplete - timing.domLoading;

    trackPerformanceMetric("page.loadTime", loadTime, { page: window.location.pathname });
    trackPerformanceMetric("page.domReadyTime", domReadyTime, { page: window.location.pathname });
    trackPerformanceMetric("page.renderTime", renderTime, { page: window.location.pathname });

    trackBusinessEvent("PagePerformance", {
      page: window.location.pathname,
      loadTime: loadTime,
      domReadyTime: domReadyTime,
      renderTime: renderTime,
      category: "performance",
    });
  }
};

// 🔥 AUTOMATIC TRACKING SETUP
// Track page performance on load
window.addEventListener("load", () => {
  setTimeout(trackPagePerformance, 1000);
});

// Track user interactions
document.addEventListener("click", (event) => {
  const target = event.target as HTMLElement;
  if (target.tagName === "BUTTON" || target.tagName === "A" || target.classList.contains("clickable")) {
    trackUserInteraction("click", target.tagName.toLowerCase(), {
      text: target.textContent?.trim() || "",
      className: target.className,
      id: target.id,
    });
  }
});

// Track form submissions
document.addEventListener("submit", (event) => {
  const form = event.target as HTMLFormElement;
  trackUserInteraction("form_submit", "form", {
    formId: form.id,
    formAction: form.action,
    formMethod: form.method,
  });
});

// Track visibility changes (user engagement)
document.addEventListener("visibilitychange", () => {
  trackBusinessEvent("VisibilityChange", {
    hidden: document.hidden,
    visibilityState: document.visibilityState,
  });
});

// Export functions for use in components
export {
  trackBusinessEvent,
  trackUserInteraction,
  trackPerformanceMetric,
  trackApiCall,
  trackUserJourney,
  trackBusinessMetric,
  trackError,
};

console.log(`🚀 ADVANCED Application Insights initialized for service: ${cloudRole}`);
console.log("🔥 Features enabled: User Journey Tracking, Business Metrics, Performance Monitoring");

export { reactPlugin };
