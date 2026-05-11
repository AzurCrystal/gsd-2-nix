{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      stableSourceInfo = import ../pkgs/gsd-2/source.nix {
        inherit (pkgs) fetchFromGitHub;
      };
      gsdPackage = config.packages."gsd-2";
      gsdRoot = "${gsdPackage}/lib/node_modules/gsd-pi";
      playwrightBrowsersPath = "${
        config.packages."gsd-2-playwright-runtime"
      }/share/gsd-2-playwright-runtime/browsers";
      rtkBin = "${config.packages."gsd-2-rtk"}/bin/rtk";
      mcpServerBin = "${gsdPackage}/bin/gsd-mcp-server";
      daemonBin = "${gsdPackage}/bin/gsd-daemon";
      node = pkgs.lib.getExe pkgs.nodejs_24;
    in
    {
      checks.gsd-2-blueprint =
        pkgs.runCommand "gsd-2-blueprint-check"
          {
            nativeBuildInputs = [
              pkgs.gitMinimal
              pkgs.nodejs_24
            ];
          }
          ''
            test -x ${gsdPackage}/bin/gsd
            test -x ${gsdPackage}/bin/gsd-cli
            test -x ${gsdPackage}/bin/gsd-mcp-server
            test -x ${gsdPackage}/bin/gsd-daemon
            test "$(${gsdPackage}/bin/gsd --version)" = "${stableSourceInfo.version}"
            test -x ${config.packages."gsd-2-suite"}/bin/gsd-mcp-server
            test -x ${config.packages."gsd-2-suite"}/bin/gsd-daemon
            test -x ${config.packages."gsd-2-playwright-runtime"}/bin/gsd-playwright-runtime
            test -x ${config.packages."gsd-2-rtk"}/bin/rtk
            test -x ${config.packages."gsd-2-rtk"}/bin/gsd-rtk-runtime
            test "$(${config.packages."gsd-2-rtk"}/bin/rtk --version)" = "rtk ${stableSourceInfo.rtkVersion}"
            test -f ${gsdPackage}/share/gsd-2-blueprint/graph.json
            test -f ${gsdPackage}/share/gsd-2-blueprint/components/gsd-2.md
            test -f ${gsdPackage}/dist/web/standalone/server.js
            test -f ${gsdRoot}/dist/loader.js
            test -f ${gsdRoot}/dist/web/standalone/server.js
            test -f ${gsdRoot}/packages/mcp-server/dist/cli.js
            test -f ${gsdRoot}/packages/daemon/dist/cli.js
            test -f ${gsdRoot}/packages/rpc-client/dist/rpc-client.js
            test -f ${gsdRoot}/dist/resources/extensions/gsd/bootstrap/write-gate.js
            test -f ${gsdRoot}/dist/resources/extensions/gsd/tools/workflow-tool-executors.js
            test -f ${gsdRoot}/src/resources/extensions/gsd/bootstrap/write-gate.ts
            test -n "$(find -L ${gsdRoot}/native/addon -maxdepth 1 -type f -name 'gsd_engine.*.node' -print -quit)"
            test -z "$(find -L ${gsdRoot}/node_modules -path '*/@gsd-build/engine-*' -print -quit)"
            test "$(${config.packages."gsd-2-rtk"}/bin/rtk rewrite 'git status')" = "rtk git status"
            rtkEnv="$(${config.packages."gsd-2-rtk"}/bin/gsd-rtk-runtime --print-env)"
            printf '%s\n' "$rtkEnv" | grep -q '^GSD_RTK_PATH='
            printf '%s\n' "$rtkEnv" | grep -q '^GSD_SKIP_RTK_INSTALL=1$'
            printf '%s\n' "$rtkEnv" | grep -q '^RTK_TELEMETRY_DISABLED=1$'
            test -d ${config.packages."gsd-2-playwright-runtime"}/share/gsd-2-playwright-runtime/browsers
            test -n "$(find -L ${
              config.packages."gsd-2-playwright-runtime"
            }/share/gsd-2-playwright-runtime/browsers -maxdepth 3 -type f -path '*/chrome-headless-shell-linux64/chrome-headless-shell' -print -quit)"
            playwrightEnv="$(${
              config.packages."gsd-2-playwright-runtime"
            }/bin/gsd-playwright-runtime --print-env)"
            printf '%s\n' "$playwrightEnv" | grep -q '^PLAYWRIGHT_BROWSERS_PATH='
            printf '%s\n' "$playwrightEnv" | grep -q '^PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1$'
            printf '%s\n' "$playwrightEnv" | grep -q '^PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true$'
            mkdir -p "$out"
          '';

      checks.gsd-2-runtime-smoke =
        pkgs.runCommand "gsd-2-runtime-smoke"
          {
            nativeBuildInputs = [
              pkgs.gitMinimal
              pkgs.nodejs_24
            ];
          }
          ''
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
                "${gsdRoot}/packages/native/dist/text/index.js",
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

            const requireFromGsd = createRequire(pathToFileURL("${gsdRoot}/package.json"));
            const { chromium } = requireFromGsd("playwright");
            const jiti = requireFromGsd("jiti")("${gsdRoot}/src/resources/extensions/browser-tools", {
              interopDefault: true,
              debug: false,
            });
            const { EVALUATE_HELPERS_SOURCE } = jiti("${gsdRoot}/src/resources/extensions/browser-tools/evaluate-helpers.ts");

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

            const requireFromGsd = createRequire(pathToFileURL("${gsdRoot}/package.json"));
            const jiti = requireFromGsd("jiti")("${gsdRoot}/src/resources/extensions/gsd", {
              interopDefault: true,
              debug: false,
            });
            const repo = mkdtempSync(join(tmpdir(), "gsd-rtk-smoke-"));
            execSync("git init -q", { cwd: repo, stdio: "pipe" });
            writeFileSync(join(repo, "demo.txt"), "hello from gsd rtk smoke\n");

            const { runVerificationGate } = jiti("${gsdRoot}/src/resources/extensions/gsd/verification-gate.ts");

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

      checks.gsd-2-companion-smoke =
        pkgs.runCommand "gsd-2-companion-smoke"
          {
            nativeBuildInputs = [
              pkgs.gitMinimal
              pkgs.nodejs_24
            ];
          }
          ''
                    export HOME="$(mktemp -d)"
                    export XDG_CACHE_HOME="$HOME/.cache"

                    cat > "$TMPDIR/companion-smoke.mjs" <<'EOF'
            import assert from "node:assert/strict";
            import { spawn } from "node:child_process";
            import { constants, accessSync, existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
            import { tmpdir } from "node:os";
            import { join } from "node:path";
            import { pathToFileURL } from "node:url";

            const cliAssertionDir = mkdtempSync(join(tmpdir(), "gsd-companion-cli-"));
            const cliAssertionHook = join(cliAssertionDir, "assert-gsd-cli-path.mjs");

            writeFileSync(cliAssertionHook, [
              'import assert from "node:assert/strict";',
              'import { constants, accessSync, writeFileSync } from "node:fs";',
              'import { pathToFileURL } from "node:url";',
              'const label = process.env.GSD_CLI_ASSERT_LABEL ?? "companion";',
              'const expected = process.env.EXPECTED_GSD_CLI_PATH;',
              'assert.ok(expected, label + " expected CLI path must be set");',
              'assert.equal(process.env.GSD_CLI_PATH, expected, label + " wrapper must set GSD_CLI_PATH");',
              'accessSync(expected, constants.R_OK);',
              'assert.ok(expected.endsWith("/dist/loader.js"), label + " should use the root-local JS loader entrypoint");',
              'const modulePath = process.env.GSD_SESSION_MANAGER_MODULE;',
              'assert.ok(modulePath, label + " session-manager module path must be set");',
              'const { SessionManager } = await import(pathToFileURL(modulePath).href);',
              'assert.equal(SessionManager.resolveCLIPath(), expected, label + " resolveCLIPath should use packaged CLI");',
              'writeFileSync(process.env.GSD_CLI_ASSERTION_MARKER, label + "\\n", { flag: "a" });',
            ].join("\n") + "\n");

            function companionEnv(label, root, sessionManagerModule) {
              const expectedCliPath = join(root, "dist", "loader.js");
              accessSync(expectedCliPath, constants.R_OK);
              return {
                HOME: process.env.HOME,
                XDG_CACHE_HOME: process.env.XDG_CACHE_HOME,
                NODE_OPTIONS: "--import=" + pathToFileURL(cliAssertionHook).href,
                EXPECTED_GSD_CLI_PATH: expectedCliPath,
                GSD_SESSION_MANAGER_MODULE: sessionManagerModule,
                GSD_CLI_ASSERTION_MARKER: join(cliAssertionDir, label + ".ok"),
                GSD_CLI_ASSERT_LABEL: label,
              };
            }

            async function waitFor(predicate, timeoutMs, label, describeFailure = () => "") {
              const deadline = Date.now() + timeoutMs;
              while (Date.now() < deadline) {
                if (await predicate()) return;
                await new Promise((resolve) => setTimeout(resolve, 50));
              }
              throw new Error("timed out waiting for " + label + describeFailure());
            }

            async function assertWorkflowBridgeImportable(root, label) {
              const workflowToolsUrl = pathToFileURL(join(root, "packages/mcp-server/dist/workflow-tools.js"));
              const writeGateUrl = new URL("../../../dist/resources/extensions/gsd/bootstrap/write-gate.js", workflowToolsUrl);
              const executorsUrl = new URL("../../../dist/resources/extensions/gsd/tools/workflow-tool-executors.js", workflowToolsUrl);
              const writeGate = await import(writeGateUrl.href);
              const executors = await import(executorsUrl.href);

              assert.equal(typeof writeGate.loadWriteGateSnapshot, "function", label);
              assert.equal(typeof writeGate.shouldBlockPendingGateInSnapshot, "function", label);
              assert.equal(typeof writeGate.shouldBlockQueueExecutionInSnapshot, "function", label);
              assert.equal(typeof executors.executePlanMilestone, "function", label);
              assert.equal(typeof executors.executeSummarySave, "function", label);
              assert.ok(Array.isArray(executors.SUPPORTED_SUMMARY_ARTIFACT_TYPES), label);
            }

            async function assertRpcClientStartsRootLocalLoader(root, label) {
              const { RpcClient } = await import(pathToFileURL(join(root, "packages/rpc-client/dist/rpc-client.js")).href);
              const client = new RpcClient({
                cliPath: join(root, "dist", "loader.js"),
                cwd: mkdtempSync(join(tmpdir(), "gsd-rpc-loader-smoke-")),
                args: ["--bare"],
                env: { HOME: process.env.HOME, XDG_CACHE_HOME: process.env.XDG_CACHE_HOME },
              });

              try {
                await client.start();
                assert.equal(client.process.spawnfile, "node", label + " should spawn node for JS loader");
                assert.equal(client.process.spawnargs[1], join(root, "dist", "loader.js"), label + " should pass root-local loader to node");
              } finally {
                await client.stop();
              }
            }

            async function smokeMcpServer() {
              await assertWorkflowBridgeImportable("${gsdRoot}", "mcp-server workflow bridge");
              await assertRpcClientStartsRootLocalLoader("${gsdRoot}", "mcp-server");

              const child = spawn("${mcpServerBin}", [], {
                stdio: ["pipe", "ignore", "pipe"],
                env: companionEnv("mcp-server", "${gsdRoot}", "${gsdRoot}/packages/mcp-server/dist/session-manager.js"),
              });

              let stderr = "";
              let childExit = null;
              child.stderr.setEncoding("utf8");
              child.stderr.on("data", (chunk) => {
                stderr += chunk;
              });
              child.on("exit", (code, signal) => {
                childExit = { code, signal };
              });

              await waitFor(
                () => stderr.includes("MCP server started on stdio"),
                30000,
                "mcp startup",
                () => "\nstderr:\n" + stderr + "\nexit: " + JSON.stringify(childExit),
              );
              child.stdin.end();

              const exitCode = await new Promise((resolve, reject) => {
                child.on("error", reject);
                child.on("exit", (code) => resolve(code ?? 1));
              });

              assert.equal(exitCode, 0);
              assert.match(stderr, /MCP server started on stdio/);
              assert.match(stderr, /Shutting down/);
              assert.match(readFileSync(join(cliAssertionDir, "mcp-server.ok"), "utf8"), /mcp-server/);
            }

            async function smokeDaemon() {
              await assertRpcClientStartsRootLocalLoader("${gsdRoot}", "daemon");

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
              ].join("\n"));

              const child = spawn("${daemonBin}", ["--config", configPath], {
                stdio: ["ignore", "ignore", "pipe"],
                env: companionEnv("daemon", "${gsdRoot}", "${gsdRoot}/packages/daemon/dist/session-manager.js"),
              });

              let stderr = "";
              let childExit = null;
              child.stderr.setEncoding("utf8");
              child.stderr.on("data", (chunk) => {
                stderr += chunk;
              });
              child.on("exit", (code, signal) => {
                childExit = { code, signal };
              });

              await waitFor(
                () => existsSync(logPath) && readFileSync(logPath, "utf8").includes("daemon started"),
                30000,
                "daemon startup log",
                () => "\nstderr:\n" + stderr + "\nexit: " + JSON.stringify(childExit),
              );
              child.kill("SIGTERM");

              const exitCode = await new Promise((resolve, reject) => {
                child.on("error", reject);
                child.on("exit", (code) => resolve(code ?? 1));
              });

              assert.equal(exitCode, 0);

              const logContent = readFileSync(logPath, "utf8");
              assert.match(logContent, /daemon started/);
              assert.match(logContent, /daemon shutting down/);

              for (const line of logContent.trim().split("\n")) {
                const entry = JSON.parse(line);
                assert.equal(typeof entry.ts, "string");
                assert.equal(typeof entry.level, "string");
                assert.equal(typeof entry.msg, "string");
              }

              assert.equal(stderr, "");
              assert.match(readFileSync(join(cliAssertionDir, "daemon.ok"), "utf8"), /daemon/);
            }

            await smokeMcpServer();
            await smokeDaemon();
            EOF

                    ${node} "$TMPDIR/companion-smoke.mjs"

                    mkdir -p "$out"
          '';
    };
}
