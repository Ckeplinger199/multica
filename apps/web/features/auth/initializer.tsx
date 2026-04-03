"use client";

import { useEffect, type ReactNode } from "react";
import { useAuthStore } from "./store";
import { useWorkspaceStore } from "@/features/workspace";
import { api } from "@/shared/api";
import { createLogger } from "@/shared/logger";
import { identifyUser, resetUser } from "@/features/analytics";
import { setLoggedInCookie, clearLoggedInCookie } from "./auth-cookie";

const logger = createLogger("auth");

/**
 * Initializes auth + workspace state from localStorage on mount.
 * Fires getMe() and listWorkspaces() in parallel when a cached token exists.
 */
export function AuthInitializer({ children }: { children: ReactNode }) {
  useEffect(() => {
    const token = localStorage.getItem("multica_token");
    if (!token) {
      clearLoggedInCookie();
      useAuthStore.setState({ isLoading: false });
      return;
    }

    api.setToken(token);
    const wsId = localStorage.getItem("multica_workspace_id");

    // Fire getMe and listWorkspaces in parallel
    const mePromise = api.getMe();
    const wsPromise = api.listWorkspaces();

    Promise.all([mePromise, wsPromise])
      .then(([user, wsList]) => {
        setLoggedInCookie();
        identifyUser(user.id, {
          $name: user.name,
          $email: user.email,
          created_at: user.created_at,
        });
        useAuthStore.setState({ user, isLoading: false });
        useWorkspaceStore.getState().hydrateWorkspace(wsList, wsId);
      })
      .catch((err) => {
        logger.error("auth init failed", err);
        api.setToken(null);
        api.setWorkspaceId(null);
        localStorage.removeItem("multica_token");
        localStorage.removeItem("multica_workspace_id");
        clearLoggedInCookie();
        resetUser();
        useAuthStore.setState({ user: null, isLoading: false });
      });
  }, []);

  return <>{children}</>;
}
