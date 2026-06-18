# chatgpt-pro-consult

A thin, auditable agent skill for consulting ChatGPT Pro through local backends when a task needs a serious second opinion: architecture, hard debugging, security review, migration risk, planning, or model/tool comparison.

It follows the `npx skills add` skill standard: the repository root contains a valid `SKILL.md` with `name` and `description` frontmatter.

## Install

From GitHub after publishing:

```bash
npx skills add semreh-ai/chatgpt-pro-consult-skill
```

Project-level Hermes install:

```bash
npx skills add semreh-ai/chatgpt-pro-consult-skill --agent hermes-agent -y --copy
```

List/discovery check:

```bash
npx skills add semreh-ai/chatgpt-pro-consult-skill --list
```

Local development install test:

```bash
npx skills add ./chatgpt-pro-consult-skill --list
```

## What this skill does

- Builds a compact context bundle for a ChatGPT Pro consult.
- Runs a local backend adapter if configured.
- Enforces secret/path scanning before sending context.
- Uses repo/task “rooms” for thread isolation.
- Uses per-room locks to prevent duplicate browser/CLI calls.
- Writes receipts for traceability.
- Requires the primary agent to synthesize the response instead of blindly trusting it.

## What this skill does not do

- It does not manage ChatGPT credentials.
- It does not ask for cookies or tokens.
- It does not scrape browser sessions.
- It does not read browser profiles, keychains, password managers, or cookie stores.
- It does not silently upload whole repositories.
- It does not fabricate backend responses.

## Backend options

The skill itself is not a ChatGPT Pro backend. It is a safe wrapper around one.
If preflight says no `chatgpt-pro` or `oracle` backend was found, install and
configure one of the backends below.

Quickest path:

```bash
npm install -g @steipete/oracle
oracle --version
```

Then configure Oracle's own ChatGPT/API/browser login flow according to its
documentation. This skill will only call the local `oracle` command; it will not
handle your ChatGPT credentials or browser session itself.

After installing a backend, verify detection:

```bash
bash scripts/preflight.sh --backend auto --json
```

Backend selection order:

1. `--backend <name>`
2. `CHATGPT_PRO_CONSULT_BACKEND`
3. `CHATGPT_PRO_CONSULT_COMMAND`
4. `chatgpt-pro` CLI if installed
5. `oracle` CLI if installed
6. clear failure

Supported backend names:

- `auto`
- `custom`
- `chatgpt-pro`
- `oracle`

### Oracle backend

If [`steipete/oracle`](https://github.com/steipete/oracle) is installed, the wrapper can invoke it as a mature external CLI backend.

### ChatGPT Pro CLI backend

If a `chatgpt-pro` command is installed, the wrapper tries to use it as a Codex-native ChatGPT Pro line.

### Custom backend

Set `CHATGPT_PRO_CONSULT_COMMAND` to a command that reads these environment variables:

- `PROMPT_FILE`
- `ROOM`
- `RECEIPT_PATH`
- `TIMEOUT_SECONDS`

Example:

```bash
CHATGPT_PRO_CONSULT_COMMAND=./examples/custom-backend.sh \
  bash scripts/chatgpt-pro-consult.sh --prompt-file templates/context-bundle.md --backend custom
```

## Usage

Create a context bundle:

```bash
cp templates/context-bundle.md /tmp/context.md
$EDITOR /tmp/context.md
```

Run preflight:

```bash
bash scripts/preflight.sh --backend auto --json
```

Run consult:

```bash
bash scripts/chatgpt-pro-consult.sh \
  --prompt-file /tmp/context.md \
  --backend auto \
  --room my-repo-architecture-review \
  --timeout 600 \
  --format json
```

## Exit codes

- `0` success
- `2` invalid CLI arguments
- `3` prompt file missing/unreadable
- `4` secret scan blocked the prompt
- `5` no backend available
- `6` backend failed
- `7` lock conflict

## Prior art / acknowledgements

This original skill synthesizes ideas from:

- [`christianaranda/codex-pro-skill`](https://github.com/christianaranda/codex-pro-skill) — minimal Codex skill UX and Pro second-pass workflow.
- [`steipete/oracle`](https://github.com/steipete/oracle) — mature CLI/MCP/browser backend pattern for external AI consults.
- [`pauljunsukhan/codex-chatgpt-pro-plugin`](https://github.com/pauljunsukhan/codex-chatgpt-pro-plugin) — repo rooms, context bundles, receipts, and Codex-native ChatGPT Pro line design.

No upstream code is copied.

## License

MIT.
