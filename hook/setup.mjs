#!/usr/bin/env node
// Interactive setup for the XRPL feedback hook.
//
// Prompts for team name and real name (both required, cannot be left blank),
// then writes the config to ~/.xrpl-feedback-hook.json with owner-only
// permissions. No API key or token is needed: the server URL and token are
// baked into submit.mjs.
//
// Run:  node setup.mjs
//
// Non-interactive fallback (for automation): set TEAM_NAME and HACKER_NAME
// (and optionally FEEDBACK_URL / FEEDBACK_TOKEN to override the baked-in values)
// in the environment and run:  node setup.mjs --non-interactive
//
// Print hook registrations with absolute, resolved paths (portable even when
// this repo is vendored as a subfolder of a larger project):
//   node setup.mjs --emit-hooks

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import readline from "node:readline";
import { fileURLToPath } from "node:url";

const DEFAULT_FEEDBACK_URL = "https://hackathon-feedback-server.z000.workers.dev";
const CONFIG_PATH =
  process.env.XRPL_FEEDBACK_CONFIG ||
  path.join(os.homedir(), ".xrpl-feedback-hook.json");

function loadExisting() {
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      return JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
    }
  } catch {
    // ignore a broken existing file, we will overwrite it
  }
  return {};
}

function writeConfig(cfg) {
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 2) + "\n", { mode: 0o600 });
  try {
    fs.chmodSync(CONFIG_PATH, 0o600);
  } catch {
    // best effort on platforms without chmod
  }
}

function nonInteractive() {
  const existing = loadExisting();
  // Only team name and real name are required. The server URL and token are
  // baked into submit.mjs, so they are optional overrides here.
  const cfg = {
    teamName: process.env.TEAM_NAME || existing.teamName || "",
    hackerName: process.env.HACKER_NAME || existing.hackerName || "",
  };
  const url = process.env.FEEDBACK_URL || existing.feedbackUrl || "";
  const token = process.env.FEEDBACK_TOKEN || existing.feedbackToken || "";
  if (url) cfg.feedbackUrl = url;
  if (token) cfg.feedbackToken = token;

  const missing = [];
  if (!cfg.teamName.trim()) missing.push("TEAM_NAME");
  if (!cfg.hackerName.trim()) missing.push("HACKER_NAME");
  if (missing.length) {
    console.error("Missing required values: " + missing.join(", "));
    console.error("");
    console.error("Set them in the environment and re-run, for example:");
    console.error(
      '  TEAM_NAME="Your Team" HACKER_NAME="Your Name" node setup.mjs --non-interactive',
    );
    console.error("");
    console.error("Optional overrides: FEEDBACK_URL, FEEDBACK_TOKEN.");
    process.exit(1);
  }
  cfg.teamName = cfg.teamName.trim();
  cfg.hackerName = cfg.hackerName.trim();
  writeConfig(cfg);
  console.log("Wrote " + CONFIG_PATH);
}

async function interactive() {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const ask = (q) => new Promise((resolve) => rl.question(q, (a) => resolve(a)));

  async function askRequired(label) {
    while (true) {
      const value = (await ask(label)).trim();
      if (value) return value;
      console.log("This field is required. Please enter a value.");
    }
  }

  async function askWithDefault(label, def) {
    const value = (await ask(`${label}${def ? ` [${def}]` : ""}: `)).trim();
    return value || def;
  }

  const existing = loadExisting();

  console.log("");
  console.log("XRPL feedback hook setup");
  console.log("Your team name and real name are attached to every feedback item you submit.");
  console.log("");

  const teamName = await askRequired(
    existing.teamName ? `Team name [${existing.teamName}]: ` : "Team name: ",
  ).catch(() => existing.teamName);
  const hackerName = await askRequired(
    existing.hackerName ? `Your name [${existing.hackerName}]: ` : "Your name: ",
  );

  rl.close();

  // Server URL and token are baked into submit.mjs, so we do not ask for them.
  const cfg = {
    teamName: teamName.trim(),
    hackerName: hackerName.trim(),
  };
  if (existing.feedbackUrl) cfg.feedbackUrl = existing.feedbackUrl;
  if (existing.feedbackToken) cfg.feedbackToken = existing.feedbackToken;

  writeConfig(cfg);
  console.log("");
  console.log("Saved config to " + CONFIG_PATH);
  console.log(`Team: ${cfg.teamName}   Name: ${cfg.hackerName}`);
  console.log("");
  console.log("Next: register the hook in your agent CLI (see INSTALL.md).");
}

// Absolute path to this hook/ directory, resolved from this file. Using forward
// slashes keeps the emitted JSON valid on every platform (Node accepts them on
// Windows too, and they need no backslash escaping).
function hookDir() {
  return fileURLToPath(new URL(".", import.meta.url)).replace(/[\\/]+$/, "");
}
function fwd(p) {
  return p.split(path.sep).join("/");
}

// Print each agent's Stop-hook registration with the absolute, resolved path to
// its stop-hook.mjs. This is the portable fix for the common failure where the
// snippet hardcodes $CLAUDE_PROJECT_DIR/hook/... but the repo is vendored as a
// subfolder, so that variable resolves to the OUTER project and the path does
// not exist (the Stop hook then dies with exit 127 and never fires).
function emitHooks() {
  const dir = fwd(hookDir());
  const cmd = (rel) => `node "${dir}/agents/${rel}/stop-hook.mjs"`;

  const claude = {
    hooks: { Stop: [{ matcher: "", hooks: [{ type: "command", command: cmd("claude-code") }] }] },
  };
  const cursor = {
    version: 1,
    hooks: { stop: [{ command: cmd("cursor"), loop_limit: 2 }] },
  };
  const codex = {
    hooks: { Stop: [{ matcher: "", hooks: [{ type: "command", command: cmd("codex"), timeout: 60 }] }] },
  };

  console.log("");
  console.log("Hook registrations with absolute resolved paths (hook dir: " + dir + ").");
  console.log("These stay correct even if this repo is vendored inside a larger project,");
  console.log("unlike a $CLAUDE_PROJECT_DIR-relative path. Paste into the PROJECT-scoped");
  console.log("config for your agent.");
  console.log("");
  console.log("Claude Code  -> .claude/settings.json");
  console.log(JSON.stringify(claude, null, 2));
  console.log("");
  console.log("Cursor       -> .cursor/hooks.json");
  console.log(JSON.stringify(cursor, null, 2));
  console.log("");
  console.log("Codex        -> .codex/hooks.json");
  console.log(JSON.stringify(codex, null, 2));
}

if (process.argv.includes("--emit-hooks")) {
  emitHooks();
} else if (process.argv.includes("--non-interactive")) {
  nonInteractive();
  emitHooks();
} else {
  interactive().then(emitHooks);
}
