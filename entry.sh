#!/usr/bin/env bash
# Copyright 2026 The Bureau Authors
# SPDX-License-Identifier: Apache-2.0

# Entry point for Claude Code agents running inside Bureau sandboxes.
#
# This script is thin scaffolding: bureau-agent-claude handles all
# real work (settings.local.json, hooks, MCP, agent service
# integration). When the Go SDK ships and bureau-agent-claude moves
# to this repo, this script gets absorbed into the Go binary.

set -euo pipefail

# Ensure .claude directory exists. On workspace-backed sandboxes this
# is the shared workspace .claude/ directory; on tmpfs-backed sandboxes
# (no workspace) it is ephemeral.
mkdir -p "${HOME:=/workspace}/.claude"

# Forward to bureau-agent-claude, which:
#   - Writes .claude/settings.local.json (hooks, permissions, MCP config)
#   - Spawns Claude Code with stream-json output parsing
#   - Reports to agent service, handles session lifecycle
exec bureau-agent-claude "$@"
