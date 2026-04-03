"use client";

import mixpanel from "mixpanel-browser";
import { createLogger } from "@/shared/logger";

const logger = createLogger("analytics");

const MIXPANEL_TOKEN = process.env.NEXT_PUBLIC_MIXPANEL_TOKEN;

/** Whether Mixpanel is enabled (token is configured). */
export const isAnalyticsEnabled = Boolean(MIXPANEL_TOKEN);

let initialized = false;

/**
 * Initialize Mixpanel. Safe to call multiple times — subsequent calls are no-ops.
 * If NEXT_PUBLIC_MIXPANEL_TOKEN is not set, all analytics calls become silent no-ops.
 */
export function initAnalytics() {
  if (!isAnalyticsEnabled || initialized) return;

  mixpanel.init(MIXPANEL_TOKEN!, {
    track_pageview: false, // we track page views manually for more control
    persistence: "localStorage",
    ip: true,
  });

  initialized = true;
  logger.info("mixpanel initialized");
}

/**
 * Identify the current user. Call after login or session restore.
 */
export function identifyUser(userId: string, properties?: Record<string, unknown>) {
  if (!isAnalyticsEnabled) return;

  mixpanel.identify(userId);

  if (properties) {
    mixpanel.people.set(properties);
  }
}

/**
 * Reset identity. Call on logout.
 */
export function resetUser() {
  if (!isAnalyticsEnabled) return;
  mixpanel.reset();
}

/**
 * Register super properties — attached to every subsequent event.
 */
export function registerSuperProperties(properties: Record<string, unknown>) {
  if (!isAnalyticsEnabled) return;
  mixpanel.register(properties);
}

/**
 * Track an event with optional properties.
 */
export function track(event: string, properties?: Record<string, unknown>) {
  if (!isAnalyticsEnabled) return;
  mixpanel.track(event, properties);
}

/**
 * Increment a numeric user profile property.
 */
export function incrementUserProperty(property: string, value: number = 1) {
  if (!isAnalyticsEnabled) return;
  mixpanel.people.increment(property, value);
}
