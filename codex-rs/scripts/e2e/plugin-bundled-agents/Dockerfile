# Self-contained Docker sandbox that builds `codex` from source and runs the
# plugin-bundled-agents end-to-end test against a live model.
#
# Build (from the repo root):
#   docker build -f codex-rs/scripts/e2e/plugin-bundled-agents/Dockerfile -t codex-pba-e2e .
#
# Run (provide an OpenAI-compatible Responses endpoint):
#   docker run --rm \
#     -e AAB_BASE_URL=https://your-endpoint \
#     -e AAB_API_KEY=sk-... \
#     -e AAB_MODEL=your-model \
#     codex-pba-e2e
#
# To skip the ~20 min in-image build, build the binary on the host first and
# bind-mount it: `-v $PWD/codex-rs/target/release/codex:/usr/local/bin/codex`
# with `--entrypoint /usr/local/bin/run_e2e.sh`.
FROM rust:1.95-bookworm AS build
WORKDIR /src
COPY . /src
RUN apt-get update -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*
RUN cd codex-rs && cargo build --release --bin codex

FROM debian:bookworm-slim
RUN apt-get update -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/codex-rs/target/release/codex /usr/local/bin/codex
COPY codex-rs/scripts/e2e/plugin-bundled-agents/plugin/research-tools /opt/fixture/research-tools
COPY codex-rs/scripts/e2e/plugin-bundled-agents/run_e2e.sh /usr/local/bin/run_e2e.sh
RUN chmod +x /usr/local/bin/run_e2e.sh
ENTRYPOINT ["/usr/local/bin/run_e2e.sh"]
