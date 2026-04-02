"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";

const EXCLUDED_PREFIXES = ["/login", "/pair/"];

interface NavigationState {
  lastPath: string;
  onPathChange: (path: string) => void;
}

export const useNavigationStore = create<NavigationState>()(
  persist(
    (set) => ({
      lastPath: "/issues",

      onPathChange: (path: string) => {
        if (!EXCLUDED_PREFIXES.some((prefix) => path.startsWith(prefix))) {
          // Strip workspace slug — store only the sub-path
          const subPath = path.replace(/^\/[^/]+/, "") || "/issues";
          set({ lastPath: subPath });
        }
      },
    }),
    {
      name: "multica_navigation",
      partialize: (state) => ({ lastPath: state.lastPath }),
    }
  )
);
