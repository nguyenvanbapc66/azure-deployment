import express from "express";
import { getUserInformation, getUserSocials, triggerError } from "../controllers/userController";

const router = express.Router();

// GET /api/user/information - Get user information (demonstrates sensitive data filtering in logs)
router.get("/information", getUserInformation);

// GET /api/user/socials - Get user social connections (demonstrates token filtering in logs)
router.get("/socials", getUserSocials);

// GET /api/error - Trigger various types of errors for testing error logging
router.get("/error", triggerError);

export default router;
