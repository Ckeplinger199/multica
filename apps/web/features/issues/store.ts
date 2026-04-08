"use client";

import { create } from "zustand";
import type { Issue } from "@/shared/types";
import { toast } from "sonner";
import { api } from "@/shared/api";
import { createLogger } from "@/shared/logger";

const logger = createLogger("issue-store");

interface IssueState {
  issues: Issue[];
  loading: boolean;
  activeIssueId: string | null;
  fetch: () => Promise<void>;
  setIssues: (issues: Issue[]) => void;
  addIssue: (issue: Issue) => void;
  updateIssue: (id: string, updates: Partial<Issue>) => void;
  removeIssue: (id: string) => void;
  setActiveIssue: (id: string | null) => void;
}

export const useIssueStore = create<IssueState>((set, get) => ({
  issues: [],
  loading: true,
  activeIssueId: null,

  fetch: async () => {
    logger.debug("fetch start");
    const isInitialLoad = get().issues.length === 0;
    if (isInitialLoad) set({ loading: true });
    try {
      const pageSize = 200;
      let allIssues: Issue[] = [];
      let offset = 0;
      let total = 0;
      do {
        const res = await api.listIssues({ limit: pageSize, offset });
        allIssues = allIssues.concat(res.issues);
        total = res.total;
        offset += res.issues.length;
      } while (allIssues.length < total);
      logger.info("fetched", allIssues.length, "issues");
      set({ issues: allIssues, loading: false });
    } catch (err) {
      logger.error("fetch failed", err);
      toast.error("Failed to load issues");
      if (isInitialLoad) set({ loading: false });
    }
  },

  setIssues: (issues) => set({ issues }),
  addIssue: (issue) =>
    set((s) => ({
      issues: s.issues.some((i) => i.id === issue.id)
        ? s.issues
        : [...s.issues, issue],
    })),
  updateIssue: (id, updates) =>
    set((s) => ({
      issues: s.issues.map((i) => (i.id === id ? { ...i, ...updates } : i)),
    })),
  removeIssue: (id) =>
    set((s) => ({ issues: s.issues.filter((i) => i.id !== id) })),
  setActiveIssue: (id) => set({ activeIssueId: id }),
}));
