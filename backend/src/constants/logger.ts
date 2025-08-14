export const LOG_MESSAGE = {
  USER: {
    // Message for successful requests
    INFORMATION_SUCCESS: "Processing user information request",
    SOCIALS_SUCCESS: "Processing user socials request",
    ERROR_SUCCESS: "Triggering intentional error for testing",

    // Message for warning requests
    INFORMATION_WARNING: "User not found",
    SOCIALS_WARNING: "User not found for socials request",
    ERROR_WARNING: "Unauthorized access attempt on error endpoint",

    // Message for error requests
    INFORMATION_ERROR: "Error processing user information request",
    SOCIALS_ERROR: "Error processing user socials request",
    ERROR_ERROR: "Intentional error triggered successfully",
  },
};
