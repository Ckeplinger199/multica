"use client";

import { useWorkspaceStore } from "./store";

export function useActorName() {
  const members = useWorkspaceStore((s) => s.members);
  const agents = useWorkspaceStore((s) => s.agents);

  const getMemberName = (userId: string) => {
    const m = members.find((m) => m.user_id === userId);
    return m?.name ?? "Unknown";
  };

  const getAgentName = (agentId: string) => {
    const a = agents.find((a) => a.id === agentId);
    return a?.name ?? "Unknown Agent";
  };

  const getActorName = (type: string, id: string) => {
    if (type === "member") return getMemberName(id);
    if (type === "agent") return getAgentName(id);
    return "System";
  };

  const getActorInitials = (type: string, id: string) => {
    const name = getActorName(type, id);
    return name
      .split(" ")
      .map((w) => w[0])
      .join("")
      .toUpperCase()
      .slice(0, 2);
  };

  const getActorAvatarUrl = (type: string, id: string): string | null => {
    if (type === "member") return members.find((m) => m.user_id === id)?.avatar_url ?? null;
    if (type === "agent") return agents.find((a) => a.id === id)?.avatar_url ?? null;
    return null;
  };

  return { getMemberName, getAgentName, getActorName, getActorInitials, getActorAvatarUrl };
}

/**
 * Returns a function that prefixes a path with the current workspace slug.
 * Usage: `const wp = useWorkspacePath(); wp("/issues")` → `"/my-workspace/issues"`
 */
export function useWorkspacePath() {
  const slug = useWorkspaceStore((s) => s.workspace?.slug);
  return (path: string) => (slug ? `/${slug}${path}` : path);
}

/**
 * Strip the first path segment (workspace slug) from a pathname.
 * `"/my-workspace/issues"` → `"/issues"`
 * `"/my-workspace"` → `"/"`
 */
export function stripWorkspaceSlug(pathname: string): string {
  return pathname.replace(/^\/[^/]+/, "") || "/";
}
