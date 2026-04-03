/**
 * Centralized event name constants for Mixpanel tracking.
 * Using constants prevents typos and makes it easy to audit all tracked events.
 */
export const AnalyticsEvents = {
  // Page views
  PAGE_VIEWED: "page_viewed",

  // Auth
  LOGIN_STARTED: "login_started",
  LOGIN_OTP_VERIFIED: "login_otp_verified",
  LOGOUT: "logout",

  // Issue management
  ISSUE_LIST_VIEWED: "issue_list_viewed",
  ISSUE_VIEW_MODE_CHANGED: "issue_view_mode_changed",
  ISSUE_FILTER_APPLIED: "issue_filter_applied",
  ISSUE_CREATED: "issue_created",
  ISSUE_OPENED: "issue_opened",
  ISSUE_STATUS_CHANGED: "issue_status_changed",
  ISSUE_PRIORITY_CHANGED: "issue_priority_changed",
  ISSUE_ASSIGNEE_CHANGED: "issue_assignee_changed",
  ISSUE_DESCRIPTION_EDITED: "issue_description_edited",
  ISSUE_DUE_DATE_CHANGED: "issue_due_date_changed",
  ISSUE_COMMENT_ADDED: "issue_comment_added",
  ISSUE_REACTION_ADDED: "issue_reaction_added",
  ISSUE_DELETED: "issue_deleted",
  ISSUE_BATCH_ACTION: "issue_batch_action",

  // Agent management
  AGENT_LIST_VIEWED: "agent_list_viewed",
  AGENT_CREATED: "agent_created",
  AGENT_OPENED: "agent_opened",
  AGENT_CONFIG_UPDATED: "agent_config_updated",
  AGENT_ASSIGNED_TO_ISSUE: "agent_assigned_to_issue",

  // Workspace
  WORKSPACE_CREATED: "workspace_created",
  WORKSPACE_SWITCHED: "workspace_switched",
  MEMBER_INVITED: "member_invited",
  MEMBER_REMOVED: "member_removed",
  REPOSITORY_CONNECTED: "repository_connected",

  // Runtimes
  RUNTIMES_PAGE_VIEWED: "runtimes_page_viewed",
  RUNTIME_DETAIL_OPENED: "runtime_detail_opened",

  // Settings
  SETTINGS_OPENED: "settings_opened",
  APPEARANCE_CHANGED: "appearance_changed",
  API_TOKEN_CREATED: "api_token_created",
  PROFILE_UPDATED: "profile_updated",

  // Inbox
  INBOX_OPENED: "inbox_opened",
  NOTIFICATION_CLICKED: "notification_clicked",

  // Landing
  LANDING_PAGE_VIEWED: "landing_page_viewed",
  CTA_CLICKED: "cta_clicked",
} as const;
