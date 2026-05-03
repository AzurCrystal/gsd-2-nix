{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      stableSourceInfo = import ../pkgs/gsd-2/source.nix {
        inherit (pkgs) fetchFromGitHub;
      };
      gsdCoreRoot = "${config.packages."gsd-2-core"}/lib/node_modules/gsd-pi";
      gsdWebRoot = "${config.packages."gsd-2-web"}";
      playwrightBrowsersPath = "${config.packages."gsd-2-playwright-runtime"}/share/gsd-2-playwright-runtime/browsers";
      rtkBin = "${config.packages."gsd-2-rtk"}/bin/rtk";
      mcpServerBin = "${config.packages."gsd-mcp-server"}/bin/gsd-mcp-server";
      daemonBin = "${config.packages."gsd-daemon"}/bin/gsd-daemon";
      node = pkgs.lib.getExe pkgs.nodejs_24;
    in
    {
      checks.gsd-2-blueprint = pkgs.runCommand "gsd-2-blueprint-check" {
        nativeBuildInputs = [
          pkgs.gitMinimal
          pkgs.nodejs_24
        ];
      } ''
        test -x ${config.packages."gsd-2"}/bin/gsd
        test "$(${config.packages."gsd-2"}/bin/gsd --version)" = "${stableSourceInfo.version}"
        test -x ${config.packages."gsd-2-suite"}/bin/gsd-mcp-server
        test -x ${config.packages."gsd-2-suite"}/bin/gsd-daemon
        test -x ${config.packages."gsd-2-playwright-runtime"}/bin/gsd-playwright-runtime
        test -x ${config.packages."gsd-2-rtk"}/bin/rtk
        test -x ${config.packages."gsd-2-rtk"}/bin/gsd-rtk-runtime
        test -f ${config.packages."gsd-2"}/share/gsd-2-blueprint/graph.json
        test -f ${config.packages."gsd-2-core"}/share/gsd-2-blueprint/components/gsd-2-core.md
        test -f ${config.packages."gsd-2-web"}/dist/web/standalone/server.js
        test -f ${config.packages."gsd-2"}/dist/web/standalone/server.js
        test -n "$(find -L ${config.packages."gsd-2-core"}/lib/node_modules/gsd-pi/native/addon -maxdepth 1 -type f -name 'gsd_engine.*.node' -print -quit)"
        test -n "$(find -L ${config.packages."gsd-2-web"}/native/addon -maxdepth 1 -type f -name 'gsd_engine.*.node' -print -quit)"
        test -n "$(find -L ${config.packages."gsd-2"}/lib/node_modules/gsd-pi/native/addon -maxdepth 1 -type f -name 'gsd_engine.*.node' -print -quit)"
        test -z "$(find -L ${config.packages."gsd-2"}/lib/node_modules -path '*/@gsd-build/engine-*' -print -quit)"
        test "$(${config.packages."gsd-2-rtk"}/bin/rtk rewrite 'git status')" = "rtk git status"
        rtkEnv="$(${config.packages."gsd-2-rtk"}/bin/gsd-rtk-runtime --print-env)"
        printf '%s\n' "$rtkEnv" | grep -q '^GSD_RTK_PATH='
        printf '%s\n' "$rtkEnv" | grep -q '^GSD_SKIP_RTK_INSTALL=1$'
        printf '%s\n' "$rtkEnv" | grep -q '^RTK_TELEMETRY_DISABLED=1$'
        test -d ${config.packages."gsd-2-playwright-runtime"}/share/gsd-2-playwright-runtime/browsers
        test -n "$(find -L ${config.packages."gsd-2-playwright-runtime"}/share/gsd-2-playwright-runtime/browsers -maxdepth 3 -type f -path '*/chrome-headless-shell-linux64/chrome-headless-shell' -print -quit)"
        playwrightEnv="$(${config.packages."gsd-2-playwright-runtime"}/bin/gsd-playwright-runtime --print-env)"
        printf '%s\n' "$playwrightEnv" | grep -q '^PLAYWRIGHT_BROWSERS_PATH='
        printf '%s\n' "$playwrightEnv" | grep -q '^PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1$'
        printf '%s\n' "$playwrightEnv" | grep -q '^PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true$'
        mkdir -p "$out"
      '';

      checks.gsd-2-runtime-smoke = pkgs.runCommand "gsd-2-runtime-smoke" {
        nativeBuildInputs = [
          pkgs.gitMinimal
          pkgs.nodejs_24
        ];
      } ''
        export HOME="$(mktemp -d)"
        export XDG_CACHE_HOME="$HOME/.cache"
        export PLAYWRIGHT_BROWSERS_PATH="${playwrightBrowsersPath}"
        export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
        export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true

        cat > "$TMPDIR/native-smoke.cjs" <<EOF
const assert = require("node:assert/strict");

const roots = [
  [
    "core",
    "${gsdCoreRoot}/packages/native/dist/text/index.js",
  ],
  [
    "web",
    "${gsdWebRoot}/packages/native/dist/text/index.js",
  ],
  [
    "meta",
    "${config.packages."gsd-2"}/packages/native/dist/text/index.js",
  ],
];

for (const [label, modulePath] of roots) {
  const text = require(modulePath);
  const lines = text.wrapTextWithAnsi("\u001b[31mhello world\u001b[0m", 5, 4);

  assert.ok(Array.isArray(lines), label + " should return wrapped lines");
  assert.ok(lines.length >= 2, label + " should wrap across multiple lines");
  assert.equal(text.visibleWidth("abc", 4), 3, label + " should measure visible width");
}
EOF

        ${node} "$TMPDIR/native-smoke.cjs"

        cat > "$TMPDIR/browser-smoke.mjs" <<EOF
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const requireFromGsd = createRequire(pathToFileURL("${gsdCoreRoot}/package.json"));
const { chromium } = requireFromGsd("playwright");
const jiti = requireFromGsd("jiti")("${gsdCoreRoot}/src/resources/extensions/browser-tools", {
  interopDefault: true,
  debug: false,
});
const { EVALUATE_HELPERS_SOURCE } = jiti("${gsdCoreRoot}/src/resources/extensions/browser-tools/evaluate-helpers.ts");

const browser = await chromium.launch({
  headless: true,
  args: ["--no-sandbox", "--disable-dev-shm-usage"],
});

try {
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();

  await page.setContent("<button id='submit'>Submit Form</button>");
  await page.evaluate(EVALUATE_HELPERS_SOURCE);

  const smokeResult = await page.evaluate(() => ({
    role: window.__pi.inferRole(document.getElementById("submit")),
    name: window.__pi.accessibleName(document.getElementById("submit")),
    visible: window.__pi.isVisible(document.getElementById("submit")),
  }));

  assert.deepEqual(smokeResult, {
    role: "button",
    name: "Submit Form",
    visible: true,
  });

  const screenshot = await page.screenshot({ type: "png" });
  assert.ok(screenshot.length > 0);
} finally {
  await browser.close();
}
EOF

        ${node} "$TMPDIR/browser-smoke.mjs"

        cat > "$TMPDIR/rtk-smoke.mjs" <<EOF
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

process.env.GSD_RTK_PATH = "${rtkBin}";
process.env.GSD_SKIP_RTK_INSTALL = "1";
process.env.RTK_TELEMETRY_DISABLED = "1";
process.env.PATH = "${config.packages."gsd-2-rtk"}/bin:" + (process.env.PATH ?? "");

const requireFromGsd = createRequire(pathToFileURL("${gsdCoreRoot}/package.json"));
const jiti = requireFromGsd("jiti")("${gsdCoreRoot}/src/resources/extensions/gsd", {
  interopDefault: true,
  debug: false,
});
const repo = mkdtempSync(join(tmpdir(), "gsd-rtk-smoke-"));
execSync("git init -q", { cwd: repo, stdio: "pipe" });
writeFileSync(join(repo, "demo.txt"), "hello from gsd rtk smoke\n");

const { runVerificationGate } = jiti("${gsdCoreRoot}/src/resources/extensions/gsd/verification-gate.ts");

const result = runVerificationGate({
  cwd: repo,
  preferenceCommands: ["git status"],
});

assert.equal(result.passed, true);
assert.equal(result.discoverySource, "preference");
assert.equal(result.checks.length, 1);
assert.match(result.checks[0].stdout, /\* No commits yet on/);
assert.match(result.checks[0].stdout, /Untracked:\s+1 files/);
assert.match(result.checks[0].stdout, /demo\.txt/);
EOF

        ${node} "$TMPDIR/rtk-smoke.mjs"

        mkdir -p "$out"
      '';

      checks.gsd-2-companion-smoke = pkgs.runCommand "gsd-2-companion-smoke" {
        nativeBuildInputs = [
          pkgs.nodejs_24
        ];
      } ''
        export HOME="$(mktemp -d)"
        export XDG_CACHE_HOME="$HOME/.cache"

        cat > "$TMPDIR/companion-smoke.mjs" <<EOF
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

async function waitFor(predicate, timeoutMs, label) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error("timed out waiting for " + label);
}

async function smokeMcpServer() {
  const child = spawn("${mcpServerBin}", [], {
    stdio: ["pipe", "ignore", "pipe"],
    env: { ...process.env },
  });

  let stderr = "";
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => {
    stderr += chunk;
  });

  await waitFor(() => stderr.includes("MCP server started on stdio"), 10000, "mcp startup");
  child.stdin.end();

  const exitCode = await new Promise((resolve, reject) => {
    child.on("error", reject);
    child.on("exit", (code) => resolve(code ?? 1));
  });

  assert.equal(exitCode, 0);
  assert.match(stderr, /MCP server started on stdio/);
  assert.match(stderr, /Shutting down/);
}

async function smokeDaemon() {
  const dir = mkdtempSync(join(tmpdir(), "gsd-daemon-smoke-"));
  const logPath = join(dir, "daemon.log");
  const configPath = join(dir, "daemon.yaml");

  writeFileSync(configPath, [
    "projects:",
    "  scan_roots: []",
    "log:",
    '  file: "' + logPath.replace(/"/g, '\\"') + '"',
    "  level: info",
    "  max_size_mb: 10",
    "",
  ].join("\\n"));

  const child = spawn("${daemonBin}", ["--config", configPath], {
    stdio: ["ignore", "ignore", "pipe"],
    env: { ...process.env },
  });

  let stderr = "";
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => {
    stderr += chunk;
  });

  await waitFor(() => existsSync(logPath) && readFileSync(logPath, "utf8").includes("daemon started"), 10000, "daemon startup log");
  child.kill("SIGTERM");

  const exitCode = await new Promise((resolve, reject) => {
    child.on("error", reject);
    child.on("exit", (code) => resolve(code ?? 1));
  });

  assert.equal(exitCode, 0);

  const logContent = readFileSync(logPath, "utf8");
  assert.match(logContent, /daemon started/);
  assert.match(logContent, /daemon shutting down/);

  for (const line of logContent.trim().split("\\n")) {
    const entry = JSON.parse(line);
    assert.equal(typeof entry.ts, "string");
    assert.equal(typeof entry.level, "string");
    assert.equal(typeof entry.msg, "string");
  }

  assert.equal(stderr, "");
}

await smokeMcpServer();
await smokeDaemon();
EOF

        ${node} "$TMPDIR/companion-smoke.mjs"

        mkdir -p "$out"
      '';
    };
}
