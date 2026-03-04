# claude-code-agent

Claude Code agent template for [Bureau](https://github.com/bureau-foundation/bureau).
Runs Claude Code in a sandboxed environment with Bureau MCP tools, hook-based
write authorization, and agent service integration.

## What this provides

A Nix flake that packages Claude Code as a Bureau template. The template runs
`bureau-agent-claude` (the agent relay binary from the Bureau monorepo) which
spawns Claude Code with stream-json output parsing, session lifecycle
management, and structured event reporting to the agent service.

Inside the sandbox, Claude Code gets:
- Bureau MCP tools via `bureau mcp serve --progressive` (tickets, artifacts,
  identity, and all CLI commands filtered by authorization grants)
- Write-path authorization hooks (writes restricted to `/workspace/`,
  `/scratch/`, `/tmp/`)
- Anthropic API access via the credential-injecting proxy (API key never
  visible to the agent)
- Developer tools (git, coreutils, Node.js) from the Nix environment

## Architecture

```
Anthropic API ◀── proxy (injects x-api-key) ◀── bridge (TCP↔Unix) ◀── Claude Code
                                                                          │
                                                                   bureau-agent-claude
                                                                   (stream-json parser,
                                                                    hooks, agent service)
                                                                          │
                                                              bureau mcp serve --progressive
                                                              (tickets, artifacts, CLI tools)
```

## Deployment

### 1. Publish the template

```bash
bureau template publish --flake github:bureau-foundation/claude-code-agent \
    --room <your-template-room>
```

This evaluates the flake's `bureauTemplate` output and publishes it as a Matrix
state event. Command paths resolve to full `/nix/store/...` paths. The daemon
prefetches missing store paths from the binary cache before creating the sandbox.

### 2. Deploy an agent

```bash
bureau agent create bureau/template:bureau-agent-claude \
    --machine machine/<your-machine> \
    --name agent/<your-agent-name> \
    --credential-file ./creds \
    --extra-credential "ANTHROPIC_API_KEY=<your-api-key>"
```

The `ANTHROPIC_API_KEY` is added to the age-encrypted credential bundle. The
launcher decrypts it at sandbox creation time and the proxy injects it as an
`x-api-key` header on requests to the Anthropic API. The plaintext key never
appears in Matrix state events and is never visible to the agent process.

### 3. Verify

```bash
bureau observe agent/<your-agent-name>
```

## Template inheritance

This template inherits from `bureau/template:agent-base`, which provides proxy
socket configuration, machine/server name environment variables, and host
network access (via `base-networked`).

To add project-specific build tools (compilers, SDKs, language runtimes),
create a new template in your project's template room that inherits from this
one and overrides the `environment` field with a Nix derivation that includes
your tools:

```nix
bureauTemplate.x86_64-linux = {
  inherits = [ "bureau/template:bureau-agent-claude" ];
  environment = "${your-dev-env-with-extra-tools}";
};
```

## Binary cache

This flake is configured to use Bureau's R2 binary cache at
`cache.infra.bureau.foundation`. CI pushes signed closures on every merge to
main, so `nix build` and `bureau template publish --flake` fetch pre-built
binaries rather than compiling from source.

## Development

```bash
# Build the environment
nix build

# Evaluate the template output
nix eval --json .#bureauTemplate.x86_64-linux | jq .

# Check entry script
shellcheck entry.sh
```

## License

Apache-2.0. See [LICENSE](LICENSE).
