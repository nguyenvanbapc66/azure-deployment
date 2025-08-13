import express from "express";
import { createItem, getItems, getItemAnalytics } from "../controllers/itemController";

const router = express.Router();

// 🚀 NEW: Advanced Analytics Endpoint (must be before generic routes)
router.get("/analytics", getItemAnalytics);

// CRUD operations
router.post("/", createItem);
router.get("/", getItems);

export default router;
