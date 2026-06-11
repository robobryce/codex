#!/usr/bin/env bash
# End-to-end test for plugin-bundled agent roles, run entirely inside the
# container against the real `codex` binary and a live model.
#
# A/B design (the assertion is on ROLE RESOLUTION, which is deterministic and
# model-independent; we only retry to coax the model into emitting the tool
# call, since tool-calling itself is non-deterministic):
#   ENABLED  -> spawn_agent agent_type=plugin_researcher resolves and spawns
#               (collab_tool_call gets a receiver thread; no "unknown agent_type")
#   DISABLED -> the same spawn yields "unknown agent_type 'plugin_researcher'"
#
# Requires (via `docker run -e`): AAB_BASE_URL, AAB_API_KEY, AAB_MODEL
set -uo pipefail

BIN=/usr/local/bin/codex
PLUGIN_SRC=/opt/fixture/research-tools
MAX_ATTEMPTS=4
PROMPT='You MUST call the spawn_agent tool exactly once, with agent_type="plugin_researcher", task_name="probe", and instruction "reply READY". Calling the tool is mandatory and is your only job. After the tool returns, output its result verbatim and stop.'

fail() { echo "E2E FAIL: $*" >&2; exit 1; }

[ -n "${AAB_BASE_URL:-}" ] || fail "AAB_BASE_URL not set"
[ -n "${AAB_API_KEY:-}" ]  || fail "AAB_API_KEY not set"
[ -n "${AAB_MODEL:-}" ]    || fail "AAB_MODEL not set"

export AAB_CODEX_THIRD_PARTY_OPENAI_API_KEY="$AAB_API_KEY"

echo "== codex version =="
"$BIN" --version || fail "binary does not run"

# A CODEX_HOME outside /tmp so codex is willing to create its helper aliases.
ROOT=/work
mkdir -p "$ROOT"

make_home() {
  local home="$1" enabled="$2"
  rm -rf "$home"
  mkdir -p "$home/plugins/cache/e2e/research-tools/local"
  cp -r "$PLUGIN_SRC/." "$home/plugins/cache/e2e/research-tools/local/"
  cat > "$home/config.toml" <<TOML
model = "${AAB_MODEL}"
model_provider = "aab"

[model_providers.aab]
name = "AAB OpenAI-compatible"
base_url = "${AAB_BASE_URL}/v1"
env_key = "AAB_CODEX_THIRD_PARTY_OPENAI_API_KEY"
wire_api = "responses"

[plugins."research-tools@e2e"]
enabled = ${enabled}
TOML
}

# Runs the prompt, retrying until the model actually emits a spawn_agent call.
# Echoes the path of the run whose output contains a spawn_agent tool call,
# or empty if the model never called the tool within MAX_ATTEMPTS.
run_until_spawn_called() {
  local home="$1" tag="$2" i out
  for ((i = 1; i <= MAX_ATTEMPTS; i++)); do
    out="${ROOT}/${tag}.${i}.jsonl"
    timeout 280 env CODEX_HOME="$home" "$BIN" exec --json --skip-git-repo-check \
      -s read-only -c model_reasoning_effort="low" "$PROMPT" > "$out" 2>"${out}.log"
    if grep -q '"tool":"spawn_agent"' "$out"; then
      echo "$out"
      return 0
    fi
    echo "  (attempt $i: model did not call spawn_agent; retrying)" >&2
  done
  return 1
}

echo "== CASE A: plugin ENABLED =="
make_home "${ROOT}/home_on" true
on_out="$(run_until_spawn_called "${ROOT}/home_on" on)" \
  || fail "enabled: model never emitted a spawn_agent call in $MAX_ATTEMPTS attempts"
echo "  spawn_agent call observed in: $on_out"
grep -q "unknown agent_type 'plugin_researcher'" "$on_out" \
  && fail "enabled: role was unexpectedly unknown"
grep -Eq 'receiver_thread_ids":\["[0-9a-f-]+' "$on_out" \
  || fail "enabled: spawn_agent did not complete with a receiver thread"
echo "  OK: plugin_researcher resolved and spawned while plugin enabled"

echo "== CASE B: plugin DISABLED (negative control) =="
make_home "${ROOT}/home_off" false
off_out="$(run_until_spawn_called "${ROOT}/home_off" off)" \
  || fail "disabled: model never emitted a spawn_agent call in $MAX_ATTEMPTS attempts"
echo "  spawn_agent call observed in: $off_out"
grep -q "unknown agent_type 'plugin_researcher'" "$off_out" \
  || fail "disabled: expected 'unknown agent_type' but did not see it"
grep -Eq 'receiver_thread_ids":\["[0-9a-f-]+' "$off_out" \
  && fail "disabled: spawn unexpectedly succeeded"
echo "  OK: plugin_researcher absent while plugin disabled"

echo
echo "E2E PASS: plugin-bundled agent role resolves iff its plugin is enabled."
