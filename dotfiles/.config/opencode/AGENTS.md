# Global agent instructions

## Working style

Behavioral defaults for all tasks (bias toward caution over speed; use judgment on trivial ones).

- **Think before coding.** State assumptions explicitly; if genuinely uncertain on something I
  must decide, ask rather than guess. When multiple interpretations or a simpler approach exist,
  surface them — don't silently pick. If something's unclear, stop and name what's confusing.
- **Simplicity first.** Write the minimum that solves the problem — nothing speculative. No
  unrequested abstractions, configurability, or error handling for impossible cases. If a senior
  engineer would call it overcomplicated, rewrite it smaller. The issue is usually timing, not the
  pattern itself: add complexity when it's needed, not before.
- **Surgical changes.** Touch only what the request needs; every changed line should trace to it.
  Don't refactor, reformat, or "improve" adjacent code, and match existing style even when you'd
  do it differently. Remove only the imports/vars/functions your own change orphaned; flag
  pre-existing dead code instead of deleting it.
- **Goal-driven execution.** Turn a task into a verifiable goal and loop until it's met — e.g.
  "fix the bug" → write a failing test that reproduces it, then make it pass; "refactor X" →
  tests green before and after. For multi-step work, state a brief plan with a verify check per
  step.
- **Python: always `uv`.** Manage every Python environment and dependency with `uv` (`uv venv`,
  `uv pip install`, `uv run`, `uv sync`) — never bare `pip`, `python -m venv`, or `virtualenv`,
  and never install into system/global Python. **Never install packages (any language, any tool)
  without asking me first** — propose what and why, then wait.

## Output language

Write everything in **Simplified Technical English** (ASD-STE100) — chat replies, code comments,
commit messages, PR descriptions, docs, and vault notes.

- One idea per sentence. Keep sentences short: about 20 words in instructions, 25 in descriptions.
- Use the active voice, and the imperative for instructions ("Run the script", not "The script
  should be run").
- One word, one meaning. Use the same term for the same thing every time; do not vary synonyms.
- Prefer the simple present tense. Do not use `-ing` forms as nouns or modifiers.
- Keep noun clusters to three words or fewer. Keep the articles — no telegraphic style.
- Keep paragraphs to six sentences or fewer.
- Prefer short, common words to long or figurative ones. Keep technical terms, identifiers, and
  command names exactly as they are.

Exceptions: code, identifiers, literal command or tool output, and quoted text — copy those
exactly. STE controls the form, not the content: still state uncertainty, caveats, and
disagreement.

## This machine

- Dotfiles are managed by a git-tracked repo; the `dotfiles` alias jumps to its checkout. Edit
  files there (they are symlinked into `$HOME`), and let me commit — don't commit or push on
  your own initiative.
- Secrets live encrypted in `~/.secrets` via `manage-secrets` (GPG/YubiKey). Never print or
  commit decrypted values.

## Second brain (Obsidian vault)

The vault lives at `$OBSIDIAN_VAULT` (default `~/vault`). Commands `/brief`, `/daily`, `/kb`,
`/project`, `/remind`, `/report` operate on it — prefer them over ad-hoc vault edits. If the
vault has its own `AGENTS.md`, its conventions win inside the vault. Do not git commit in the
vault — syncing is the vault's own concern.
