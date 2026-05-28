---
name: open-web
description: >
  Open a URL in a Playwright-driven browser (via the maister MCP
  server), wait for the page to settle, capture an accessibility
  snapshot + optional screenshot, surface console errors, and report
  what landed. Bridges the gap between WebFetch (server-rendered HTML
  only, no JS, no session) and pasting screenshots manually — works
  for pages behind a login wall (headed browser inherits an
  authenticated session) and for JavaScript-rendered SPAs that
  WebFetch can't read.
  Trigger phrases: "open this URL", "open in browser", "load page in
  Playwright", "screenshot this page", "what's on this page", "fetch
  rendered content".
argument-hint: "<url> [--close] [--no-screenshot] [--timeout 15s]"
allowed-tools:
  - Bash
  - AskUserQuestion
  - mcp__plugin_maister_playwright__browser_navigate
  - mcp__plugin_maister_playwright__browser_snapshot
  - mcp__plugin_maister_playwright__browser_take_screenshot
  - mcp__plugin_maister_playwright__browser_wait_for
  - mcp__plugin_maister_playwright__browser_console_messages
  - mcp__plugin_maister_playwright__browser_close
  - mcp__plugin_maister_playwright__browser_tabs
---

# /open-web — Drive a Playwright browser from the agent

This skill is the agent's hand on a real browser. It exists because two common URLs are unreadable by `WebFetch`:

1. **Auth-walled pages** — course platforms, internal dashboards, GitHub private repos. WebFetch is unauthenticated; the Playwright MCP browser inherits whatever session you already have open (or you log in once and stay).
2. **JavaScript-rendered apps** — SPAs, React/Vue dashboards, infinite-scroll pages. WebFetch sees the empty HTML shell before JS runs; Playwright sees the rendered DOM.

For everything else (public static pages, Markdown docs, GitHub READMEs), `WebFetch` is faster and cheaper — use it.

## When to use, when to skip

**Use when**:
- Page requires login and your browser is already authenticated.
- Page is a SPA / JS-rendered app and the content you want appears only after scripts run.
- You want a screenshot for visual reference (UI bug, layout check, design comparison).
- You want to surface JS console errors that might explain a blank page.

**Skip when**:
- Page is public + server-rendered → `WebFetch` is the right tool.
- You need to fetch dozens of pages → write a script, don't slash-command-loop.
- You only need offline reading → save the page manually.

## Process

### Step 0: Verify the Playwright MCP server is reachable

If the `mcp__plugin_maister_playwright__browser_navigate` tool isn't available (maister plugin not installed, MCP server not started), print:

```
Playwright MCP server unavailable. Either:
  - Maister plugin not installed → re-run setup with the marketplace registered
  - MCP server not started → check /mcp dialog in Claude Code
STOP.
```

Then STOP. Do NOT fall back to WebFetch — that defeats the purpose; the user picked /open-web because they specifically need a real browser.

### Step 1: Resolve URL + flags

Parse arguments:

- **First positional arg** = URL. Required.
- `--close` — close the browser tab after the report. Default: leave open (preserves session for follow-ups).
- `--no-screenshot` — skip the screenshot capture. Default: take one.
- `--timeout <Ns>` — override the default 5s wait for the page to settle. Default: 5s.

URL validation:

- Must start with `http://` or `https://`. If user passed a bare host (`example.com`), prepend `https://` and tell them.
- If empty after argument parsing, ask:

  AskUserQuestion:
  - question: "Paste the URL you want to open."
    header: "URL?"
    options:
    - label: "Cancel"
      description: "Exit without opening anything."
    multiSelect: false

  (The user will type the URL via the "Other" path that's offered automatically.)

### Step 2: Navigate

Call `mcp__plugin_maister_playwright__browser_navigate` with the URL. Handle failure modes:

| Failure | Detection | Action |
|---|---|---|
| DNS failure / connection refused | Tool error message contains "ERR_NAME_NOT_RESOLVED" or "ECONNREFUSED" | Print the error, STOP. |
| HTTP 4xx / 5xx | Page loaded but status code in the 400-599 range | Print status, continue (sometimes auth walls return 401 but still render a login form). |
| Auth redirect | Final URL ends in `/login`, `/signin`, `/oauth`, or page title matches `(?i)(sign[ -]?in|log[ -]?in|authenticate)` | Print: "Page requires login. Complete it in the opened browser window, then re-run /open-web with the same URL." STOP — do NOT proceed to snapshot. |
| Bot-detection wall (Cloudflare, hCaptcha) | Page title or body matches `(?i)(checking your browser|access denied|verify you are human)` | Print warning, continue — the user may have to interact in the browser, but the snapshot still has value. |

### Step 3: Wait for content

Call `mcp__plugin_maister_playwright__browser_wait_for` with the timeout from Step 1. Target: `body` visible (best-effort default).

For SPAs that hydrate slowly, this won't always catch the "fully ready" state — that's expected. The user can re-run with `--timeout 15s` if the first snapshot was empty.

### Step 4: Capture state

Run in this order (each is a separate MCP call):

1. **`browser_snapshot`** — accessibility tree of the page. This is the canonical form for the agent to reason about content. Always do this.
2. **`browser_take_screenshot`** — viewport PNG. Skip if `--no-screenshot` was passed.
3. **`browser_console_messages`** — surface JS errors / warnings. Often explains why a page rendered blank.

### Step 5: Report

Print a structured summary:

```
═══════════════════════════════════════════════════════════
  PAGE LOADED
═══════════════════════════════════════════════════════════

  URL:           <final URL after redirects>
  Title:         <page title from snapshot>
  HTTP:          <status code>
  Snapshot:      <N> top-level landmarks
  Top headings:  <up to 3 h1/h2 from snapshot>
  Screenshot:    <captured | skipped>
  Console:       <N errors, M warnings>

  First findings (from snapshot):
    <one-line summary of what the page contains — list items,
     article body, dashboard widgets, login form, error message...>

═══════════════════════════════════════════════════════════
```

If console errors are non-zero, append the first 3 verbatim — they often diagnose a blank page faster than the screenshot.

### Step 6: Close (only on explicit user request)

If user passed `--close`, call `mcp__plugin_maister_playwright__browser_close`. Otherwise leave the tab open:

- Preserves cookies / authenticated session for subsequent `/open-web` calls on the same domain.
- Lets the user interact with the page directly (click a link, scroll, log in) before the next agent action.

STOP after the report (or after close).

## Critical guardrails

1. **Don't fall back to WebFetch on failure.** The user picked `/open-web` because they specifically need a real browser (auth, JS rendering). If the Playwright server is unreachable, surface the problem — don't silently degrade.

2. **Don't auto-click through login forms.** If the page is an auth wall, STOP and tell the user to log in. Automated credential typing belongs in a different tool, not a "open this URL" skill.

3. **Don't navigate sub-links automatically.** `/open-web` opens one URL. For multi-step flows (click here, then there, then screenshot), the user makes those calls explicitly via `browser_click` + `browser_navigate` in the same session.

4. **Don't close the tab unless asked.** Headed browser session is expensive to recreate (re-login, re-warm caches). Default-leave-open is the cooperative behavior.

5. **Don't paraphrase the snapshot.** When the user asks "what's on this page?", quote landmarks and heading text from the snapshot verbatim. Hallucinating page content from a partial render is worse than admitting the page hadn't finished loading.

## Notes

- The MCP server runs headed by default in the maister config — that's what makes the auth-inherited workflow work. For headless mode, configure the server differently (out of scope for this skill).
- This skill exists because `WebFetch` returns server-rendered HTML only. Modern web apps render most content client-side; for them, `WebFetch` reads an empty shell. `/open-web` is the escape hatch for that class of page, not a replacement for `WebFetch` on the easy cases.
- If you want to read the same URL repeatedly during a session (debugging an SPA), the open-tab + re-snapshot loop is much cheaper than re-navigating each time. Pass `--close` only at the end.
