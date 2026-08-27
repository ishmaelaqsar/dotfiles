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

## Comments and documentation

Follow the [Google developer documentation style guide](https://developers.google.com/style) as
well as STE. STE controls the shape of a sentence. The Google guide covers everything else.

- **Person.** Address the reader as "you". Do not write "we", and do not write "the user" when
  you mean the reader.
- **Tense.** Describe present behaviour in the present tense. Do not write "will" for something
  that happens now.
- **Possibility.** Write "might" for possibility. Keep "may" for permission.
- **Headings.** Use sentence case, not title case.
- **Words to drop.** Never write "simply", "just", "easy", "obvious", or "of course". They tell
  the reader how hard the task should feel, and they are wrong when the reader is stuck.
- **"Please".** Leave it out of instructions.
- **Abbreviations.** Spell out a term the first time you use it. Write "for example" and "that
  is" instead of "e.g." and "i.e.".
- **Lists.** Number a list when the order matters. Otherwise use bullets.
- **Link text.** Describe the target. Never write "click here" or "read more".
- **Code font.** Put identifiers, paths, flags, and commands in code font. Put UI labels in bold.
- **Direction.** Do not point with "above", "below", or "on the left". A screen reader gives no
  position, and the layout moves. Name the section or link to it.
- **Inclusive language.** Avoid ableist and violent terms. Write "check", not "sanity check".
  Write "placeholder", not "dummy". Keep a term when it is the literal name of a command or flag.
- **Punctuation.** Use the serial comma. Avoid exclamation marks.
- **No anthropomorphism.** A program does not want, think, or try.

For code comments, add two rules:

- Explain **why**, not what. The code already says what it does.
- Delete a comment that no longer matches the code. A stale comment is worse than none.

## Artifact style

Publish Artifacts as a **printed sheet**, not a themed web page. Keep the same light look in
every host theme.

- **Ground and sheet.** Paint a muted warm-grey desk behind a near-white sheet. Give the sheet
  square corners, a hairline edge, and a soft drop shadow. Square corners matter, because paper
  has no rounded ones.
- **Tokens.** `--desk: #e7e5df`, `--sheet: #fdfdfb`, `--edge: #cfccc4`, `--rule: #ddd9d1`,
  `--rule-2: #ebe8e1`, `--ink: #1a1a17`, `--ink-2: #55534c`, `--ink-3: #8a877e`.
- **Data ink.** `#1f5fa8` (blue) and `#c04a1d` (rust). Both clear 3:1 contrast on the sheet, and
  both pass the colourblind separation checks. Add more hues only after you validate them.
- **Type.** Use `Source Serif 4` for prose and `IBM Plex Mono` for every figure, label, and
  caption. Load both from Google Fonts, the one font host the Artifact CSP admits. Always give a
  fallback stack, or the face fails silently.
- **Tables.** Set them like print: a heavy rule under the header row, hairlines between rows, no
  fills, and no border radius. Add `font-variant-numeric: tabular-nums` to numeric columns, and
  `white-space: nowrap` so a figure never breaks across lines.
- **Table gutters.** Give every cell the same horizontal padding, about `12px` each side, for a
  `24px` gutter between columns. Then reset `padding-left` on the first column and `padding-right`
  on the last, so the table still aligns flush with the text column. Never zero `padding-right` on
  right-aligned numeric columns alone: the next cell contributes no left padding, so two adjacent
  numeric columns end up touching with no gutter at all. Keep header labels short, because the
  header usually sets the column width, not the data. Move a formula or a definition into the
  caption instead. Wrap each table in a container with `overflow-x: auto`, so a wide table scrolls
  rather than crushing its columns.
- **Section labels.** Set headings in small uppercase mono with wide letter-spacing.
- **Single theme.** Omit the `prefers-color-scheme` and `data-theme` blocks. Define every colour
  in `:root`, and paint the `body` background from a token, so the page holds on any host ground.
- **Avoid** the cream paper look with a serif display face and a terracotta accent. Use cool
  near-white stock and print inks instead.

Keep the treatment utilitarian. A technical page needs hierarchy, spacing, and a real palette.
It does not need a large hero or extra ornament.

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
