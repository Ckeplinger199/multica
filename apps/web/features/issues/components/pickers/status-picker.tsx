"use client";

import { useState } from "react";
import type { IssueStatus, UpdateIssueRequest } from "@/shared/types";
import { ALL_STATUSES, STATUS_CONFIG } from "@/features/issues/config";
import { track, AnalyticsEvents } from "@/features/analytics";
import { StatusIcon } from "../status-icon";
import { PropertyPicker, PickerItem } from "./property-picker";

export function StatusPicker({
  status,
  onUpdate,
}: {
  status: IssueStatus;
  onUpdate: (updates: Partial<UpdateIssueRequest>) => void;
}) {
  const [open, setOpen] = useState(false);
  const cfg = STATUS_CONFIG[status];

  return (
    <PropertyPicker
      open={open}
      onOpenChange={setOpen}
      width="w-44"
      trigger={
        <>
          <StatusIcon status={status} className="h-3.5 w-3.5 shrink-0" />
          <span className="truncate">{cfg.label}</span>
        </>
      }
    >
      {ALL_STATUSES.map((s) => {
        const c = STATUS_CONFIG[s];
        return (
          <PickerItem
            key={s}
            selected={s === status}
            hoverClassName={c.hoverBg}
            onClick={() => {
              track(AnalyticsEvents.ISSUE_STATUS_CHANGED, { from_status: status, to_status: s });
              onUpdate({ status: s });
              setOpen(false);
            }}
          >
            <StatusIcon status={s} className="h-3.5 w-3.5" />
            <span>{c.label}</span>
          </PickerItem>
        );
      })}
    </PropertyPicker>
  );
}
