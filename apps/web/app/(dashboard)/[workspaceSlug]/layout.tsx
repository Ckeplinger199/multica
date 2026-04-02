"use client";

import { use, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useWorkspaceStore } from "@/features/workspace";
import { MulticaIcon } from "@/components/multica-icon";

export default function WorkspaceSlugLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ workspaceSlug: string }>;
}) {
  const { workspaceSlug } = use(params);
  const router = useRouter();
  const workspace = useWorkspaceStore((s) => s.workspace);
  const workspaces = useWorkspaceStore((s) => s.workspaces);
  const switchWorkspace = useWorkspaceStore((s) => s.switchWorkspace);

  useEffect(() => {
    if (!workspace) return;
    if (workspace.slug === workspaceSlug) return;

    const target = workspaces.find((ws) => ws.slug === workspaceSlug);
    if (target) {
      switchWorkspace(target.id);
    } else {
      router.replace(`/${workspace.slug}/issues`);
    }
  }, [workspaceSlug, workspace, workspaces, switchWorkspace, router]);

  if (!workspace || workspace.slug !== workspaceSlug) {
    return (
      <div className="flex h-full items-center justify-center">
        <MulticaIcon className="size-6 animate-pulse" />
      </div>
    );
  }

  return children;
}
