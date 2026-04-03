"use client";

import { create } from "zustand";
import type { User } from "@/shared/types";
import { api } from "@/shared/api";
import { track, identifyUser, resetUser, incrementUserProperty, AnalyticsEvents } from "@/features/analytics";
import { setLoggedInCookie, clearLoggedInCookie } from "./auth-cookie";

interface AuthState {
  user: User | null;
  isLoading: boolean;

  initialize: () => Promise<void>;
  sendCode: (email: string) => Promise<void>;
  verifyCode: (email: string, code: string) => Promise<User>;
  logout: () => void;
  setUser: (user: User) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isLoading: true,

  initialize: async () => {
    const token = localStorage.getItem("multica_token");
    if (!token) {
      set({ isLoading: false });
      return;
    }

    api.setToken(token);

    try {
      const user = await api.getMe();
      set({ user, isLoading: false });
    } catch {
      api.setToken(null);
      api.setWorkspaceId(null);
      localStorage.removeItem("multica_token");
      localStorage.removeItem("multica_workspace_id");
      set({ user: null, isLoading: false });
    }
  },

  sendCode: async (email: string) => {
    await api.sendCode(email);
  },

  verifyCode: async (email: string, code: string) => {
    const { token, user } = await api.verifyCode(email, code);
    localStorage.setItem("multica_token", token);
    api.setToken(token);
    setLoggedInCookie();
    identifyUser(user.id, {
      $name: user.name,
      $email: user.email,
      created_at: user.created_at,
    });
    track(AnalyticsEvents.LOGIN_OTP_VERIFIED, {
      email_domain: email.split("@")[1],
    });
    set({ user });
    return user;
  },

  logout: () => {
    track(AnalyticsEvents.LOGOUT);
    localStorage.removeItem("multica_token");
    localStorage.removeItem("multica_workspace_id");
    api.setToken(null);
    api.setWorkspaceId(null);
    clearLoggedInCookie();
    resetUser();
    set({ user: null });
  },

  setUser: (user: User) => {
    set({ user });
  },
}));
