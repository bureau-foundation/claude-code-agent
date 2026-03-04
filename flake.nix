# Copyright 2026 The Bureau Authors
# SPDX-License-Identifier: Apache-2.0

{
  description = "Claude Code agent template for Bureau — sandboxed AI coding agent with MCP tool integration";

  nixConfig = {
    extra-substituters = [ "https://cache.infra.bureau.foundation" ];
    extra-trusted-public-keys = [
      "cache.infra.bureau.foundation-1:3hpghLePqloLp0qMpkgPy/i0gKiL/Sxl2dY8EHZgOeY= cache.infra.bureau.foundation-2:e1rDOXBK+uLDTT+YU2UzIzkNHpLEaG2jCHZumlH1UmY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bureau.url = "github:bureau-foundation/bureau";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      bureau,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # claude-code is distributed under Anthropic's proprietary license.
          config.allowUnfreePredicate =
            pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];
        };

        entry-script = pkgs.writeShellScriptBin "claude-code-agent-entry" (builtins.readFile ./entry.sh);

        # Everything the sandbox needs in a single Nix store path.
        # Bind-mounted at /usr/local (via template `environment` field),
        # with bin/ prepended to PATH.
        claude-code-agent-env = pkgs.buildEnv {
          name = "claude-code-agent-env";
          paths =
            [
              pkgs.claude-code # Claude Code CLI
              bureau.packages.${system}.bureau # Bureau CLI (MCP server)
              bureau.packages.${system}.bureau-agent-claude # Agent relay binary
              bureau.packages.${system}.bureau-bridge # TCP-to-Unix bridge
              bureau.packages.${system}.bureau-proxy-call # One-shot proxy HTTP
              bureau.packages.${system}.bureau-pipeline-executor # Pipeline steps
              entry-script # Entry point wrapper
            ]
            ++ bureau.lib.presets.developer pkgs # git, coreutils, etc.
            ++ bureau.lib.modules.runtime.nodejs pkgs; # Node.js runtime
        };
      in
      {
        packages.default = claude-code-agent-env;

        # Bureau template definition. The `bureau template publish --flake`
        # command evaluates this attribute and publishes it as a Matrix state
        # event. Field names use snake_case matching the TemplateContent JSON
        # wire format (lib/schema/events_template.go).
        #
        # Command and environment paths resolve to full /nix/store/... paths
        # at eval time. The daemon prefetches missing store paths from the
        # binary cache before creating the sandbox.
        bureauTemplate = {
          description = "Claude Code agent with Bureau MCP tools, hook-based write authorization, and agent service integration";
          inherits = [ "bureau/template:agent-base" ];

          # bureau-bridge creates a TCP listener at 127.0.0.1:8642 that
          # forwards to the proxy Unix socket. Claude Code uses this as
          # ANTHROPIC_BASE_URL — the proxy injects the real API key.
          command = [
            "${claude-code-agent-env}/bin/bureau-bridge"
            "--listen"
            "127.0.0.1:8642"
            "--socket"
            "/run/bureau/proxy.sock"
            "--"
            "${claude-code-agent-env}/bin/claude-code-agent-entry"
          ];

          # The environment store path is bind-mounted into the sandbox
          # at /usr/local, and its bin/ is prepended to PATH. Contains
          # claude-code, bureau CLI, bureau-agent-claude, bureau-bridge,
          # git, coreutils, Node.js, and the entry script.
          environment = "${claude-code-agent-env}";

          required_services = [ "agent" ];

          environment_variables = {
            ANTHROPIC_BASE_URL = "http://127.0.0.1:8642/http/anthropic";
          };

          proxy_services = {
            anthropic = {
              upstream = "https://api.anthropic.com";
              inject_headers = {
                "x-api-key" = "ANTHROPIC_API_KEY";
              };
              strip_headers = [
                "x-api-key"
                "authorization"
              ];
            };
          };

          # /workspace: agent working directory (tmpfs default; workspace
          #   system overrides with bind mount when workspace is assigned)
          # /scratch: durable scratch space for plans (same override pattern)
          filesystem = [
            {
              dest = "/workspace";
              type = "tmpfs";
            }
            {
              dest = "/scratch";
              type = "tmpfs";
            }
          ];

          create_dirs = [
            "/scratch/plans"
            "/workspace/.claude"
          ];

          default_payload = {
            working_directory = "/workspace";
          };
        };
      }
    );
}
