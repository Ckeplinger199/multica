"use client";

import posthog from "posthog-js";
import { createLogger } from "@/shared/logger";

const logger = createLogger("analytics");

const POSTHOG_KEY = process.env.NEXT_PUBLIC_POSTHOG_KEY;
const POSTHOG_HOST = process.env.NEXT_PUBLIC_POSTHOG_HOST || "https://us.i.posthog.com";

/** Whether PostHog is enabled (API key is configured). */
export const isAnalyticsEnabled = Boolean(POSTHOG_KEY);

let initialized = false;

/**
 * Initialize PostHog. Safe to call multiple times — subsequent calls are no-ops.
 * If NEXT_PUBLIC_POSTHOG_KEY is not set, all analytics calls become silent no-ops.
 */
export function initAnalytics() {
  if (!isAnalyticsEnabled || initialized) return;

  posthog.init(POSTHOG_KEY!, {
    api_host: POSTHOG_HOST,
    capture_pageview: false, // we track page views manually for more control
    capture_pageleave: true,
    persistence: "localStorage",
  });

  initialized = true;
  logger.info("posthog initialized");
}

/**
 * Identify the current user. Call after login or session restore.
 */
export function identifyUser(userId: string, properties?: Record<string, unknown>) {
  if (!isAnalyticsEnabled) return;
  posthog.identify(userId, properties);
}

/**
 * Reset identity. Call on logout.
 */
export function resetUser() {
  if (!isAnalyticsEnabled) return;
  posthog.reset();
}

/**
 * Register super properties — attached to every subsequent event.
 */
export function registerSuperProperties(properties: Record<string, unknown>) {
  if (!isAnalyticsEnabled) return;
  posthog.register(properties);
}

/**
 * Track an event with optional properties.
 */
export function track(event: string, properties?: Record<string, unknown>) {
  if (!isAnalyticsEnabled) return;
  posthog.capture(event, properties);
}
