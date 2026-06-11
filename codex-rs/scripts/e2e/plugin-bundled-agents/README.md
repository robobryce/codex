# Plugin-bundled agents — end-to-end test

A Docker-sandboxed end-to-end test for the plugin-bundled agent roles feature.
It exercises the **real `codex` binary** against a **live model** and proves the
feature with an A/B (positive + negative-control) design.

## What it asserts

A fixture plugin (`plugin/research-tools`) bundles a custom agent role via an
`agents/` directory:

```
research-tools/
├── .codex-plugin/plugin.json   # { "name": "research-tools", "agents": "./agents" }
└── agents/researcher.toml      # name = "plugin_researcher", model = "gpt-5.2", ...
```

The plugin is staged into a throwaway `CODEX_HOME` and the harness runs
`codex exec`, asking the model to call `spawn_agent` with
`agent_type="plugin_researcher"`:

| Case | `[plugins."research-tools@e2e"].enabled` | Expected |
| ---- | ---------------------------------------- | -------- |
| A    | `true`                                   | `spawn_agent` resolves and spawns the role (receiver thread created) |
| B    | `false`                                  | `unknown agent_type 'plugin_researcher'` |

The assertion is on **role resolution**, which is deterministic and
model-independent; the harness only retries to coax the model into emitting the
tool call (tool-calling itself is non-deterministic).

## Running

```bash
# From the repo root. Builds codex from source inside the image (~20 min).
docker build -f codex-rs/scripts/e2e/plugin-bundled-agents/Dockerfile -t codex-pba-e2e .

docker run --rm \
  -e AAB_BASE_URL="https://your-openai-compatible-endpoint" \
  -e AAB_API_KEY="sk-..." \
  -e AAB_MODEL="your-model" \
  codex-pba-e2e
```

The endpoint must support the OpenAI **Responses** API (`/v1/responses`); this
codex version no longer supports `wire_api = "chat"`.

A passing run prints:

```
E2E PASS: plugin-bundled agent role resolves iff its plugin is enabled.
```
