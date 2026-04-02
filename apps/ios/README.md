# Multica iOS App

MVP iOS client for the Multica platform — issue management with AI agent execution log viewing.

## Requirements

- Xcode 16+
- iOS 17.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for generating the Xcode project)

## Setup

```bash
# Install XcodeGen if you don't have it
brew install xcodegen

# Generate Xcode project
cd apps/ios
xcodegen generate

# Open in Xcode
open Multica.xcodeproj
```

## Configuration

By default, the app connects to `http://localhost:8080` in debug builds. To change the API URL, edit `Multica/Services/APIClient.swift`.

## Features

- **Authentication** — Passwordless email login (send code → verify)
- **Workspace selection** — Pick from your workspaces
- **Issue list** — Grouped by status, searchable, with status filtering
- **Issue detail** — View/edit title, status, priority, and assignee
- **Comments** — View and add comments with threaded display
- **Agent task runs** — View all historical agent executions for an issue
- **Execution logs** — Real-time streaming of agent tool use, thinking, and output
- **Real-time sync** — WebSocket connection for live updates

## Architecture

- **SwiftUI** with `@Observable` (iOS 17+)
- **MVVM** — ViewModels use `@Observable` macro
- **URLSession** for HTTP networking
- **URLSessionWebSocketTask** for real-time
- **Keychain** for secure token storage
- No third-party dependencies

## Structure

```
Multica/
├── MulticaApp.swift          # App entry point
├── Models/                   # Codable data models
├── Services/                 # API client, WebSocket, Keychain
├── ViewModels/               # @Observable view models
└── Views/
    ├── Auth/                 # Login + code verification
    ├── Workspace/            # Workspace picker
    ├── Issues/               # List, detail, create
    ├── Comments/             # Comment list + input
    ├── Tasks/                # Agent runs + execution logs
    └── Components/           # Shared UI (badges, icons, avatars)
```
