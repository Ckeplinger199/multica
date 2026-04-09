"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { usePathname } from "next/navigation";
import { initAnalytics, isAnalyticsEnabled, track } from "./posthog";
import { AnalyticsEvents } from "./events";

/**
 * Initializes PostHog on mount and tracks page views on route changes.
 * When NEXT_PUBLIC_POSTHOG_KEY is not set, this component is effectively a no-op.
 */
export function AnalyticsProvider({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const prevPathRef = useRef<string | null>(null);

  // Initialize PostHog once
  useEffect(() => {
    initAnalytics();
  }, []);

  // Track page views on route changes
  useEffect(() => {
    if (!isAnalyticsEnabled) return;

    const previousPath = prevPathRef.current;
    prevPathRef.current = pathname;

    // Skip initial mount (no previous path) — or track it if desired
    if (previousPath === pathname) return;

    track(AnalyticsEvents.PAGE_VIEWED, {
      path: pathname,
      previous_path: previousPath,
    });
  }, [pathname]);

  return <>{children}</>;
}
