import "./global.css";
import type { ReactNode } from "react";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: {
    template: "%s | Multica Docs",
    default: "Multica Docs",
  },
  description:
    "Documentation for Multica — the open-source managed agents platform.",
};

export default function Layout({ children }: { children: ReactNode }) {
  return children;
}
