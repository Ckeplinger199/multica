"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { usePathname } from "next/navigation";
import { initAnalytics, isAnalyticsEnabled, track } from "./mixpanel";
import { AnalyticsEvents } from "./events";

/**
 * Initializes Mixpanel on mount and tracks page views on route changes.
 * Renders nothing — just wraps children for provider placement in the tree.
 *
 * When NEXT_PUBLIC_MIXPANEL_TOKEN is not set, this component is effectively a no-op.
 */
export function AnalyticsProvider({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const prevPathRef = useRef<string | null>(null);

  // Initialize Mixpanel once
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
