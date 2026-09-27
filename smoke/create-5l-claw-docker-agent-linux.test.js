const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const repoRoot = path.resolve(__dirname, "..");
const skillDir = path.join(repoRoot, "skills", "create-5l-claw-docker-agent-linux");
const versionScriptPath = path.join(skillDir, "scripts", "get-openclaw-versions-linux.sh");
const harnessScriptPath = path.join(skillDir, "scripts", "create-5l-claw-docker-agent-linux-harness.sh");
const installerScriptPath = path.join(repoRoot, "scripts", "claw-docker.sh");

function writeExecutable(filePath, contents) {
  fs.writeFileSync(filePath, contents);
  fs.chmodSync(filePath, 0o755);
}

function createFixture(t) {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "claw-agent-skill-"));
  const binDir = path.join(tempDir, "bin");
  fs.mkdirSync(binDir);

  t.after(() => fs.rmSync(tempDir, { recursive: true, force: true }));

  return { binDir, tempDir };
}

function run(command, args, fixture, extraEnv = {}, options = {}) {
  return spawnSync(command, args, {
    encoding: "utf8",
    cwd: options.cwd ?? fixture.tempDir,
    env: {
      ...process.env,
      PATH: `${fixture.binDir}:${process.env.PATH}`,
      ...extraEnv,
    },
  });
}

function installVersionQueryCurlStub(binDir) {
  writeExecutable(
    path.join(binDir, "curl"),
    `#!/usr/bin/env bash
set -euo pipefail

url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done

if [[ "$url" == *"Dockerfile"* ]]; then
  printf '%s\\n' "\${FAKE_TEMPLATE_DOCKERFILE:?}"
  exit 0
fi

if [[ "$url" == *"dist-tags"* ]]; then
  if [[ "\${FAKE_DIST_TAGS_RESULT:-success}" == "failure" ]]; then
    exit 22
  fi

  printf '%s\\n' "\${FAKE_DIST_TAGS_JSON:-{}}"
  exit 0
fi

exit 1
`,
  );
}

function installHarnessStubs(binDir) {
  writeExecutable(
    path.join(binDir, "curl"),
    `#!/usr/bin/env bash
set -euo pipefail

url=""
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    -*) shift ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

if [[ "$url" == *"claw-docker.sh"* ]]; then
  cat > "$output" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

version=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --openclaw-version)
      version="$2"
      shift 2
      ;;
    *) shift ;;
  esac
done

[[ -n "$version" ]]
printf 'ARG OPENCLAW_VERSION=%s\\n' "$version" > Dockerfile
touch docker-compose.yml
SCRIPT
  chmod +x "$output"
  exit 0
fi

exit 1
`,
  );

  writeExecutable(
    path.join(binDir, "docker"),
    `#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "compose" && "$2" == "version" ]]; then
  exit 0
fi

if [[ "$1" == "compose" && "$2" == "build" ]]; then
  printf '%s\\n' "build" >> "\${FAKE_DOCKER_LOG:?}"
  exit 0
fi

if [[ "$1" == "compose" && "$2" == "run" && "$*" == *" --version" ]]; then
  printf 'OpenClaw %s\\n' "\${FAKE_INSTALLED_VERSION:?}"
  exit 0
fi

echo "unexpected docker command: $*" >&2
exit 1
`,
  );

  writeExecutable(
    path.join(binDir, "ss"),
    `#!/usr/bin/env bash
set -euo pipefail
echo "State Recv-Q Send-Q Local Address:Port Peer Address:Port"
`,
  );
}

function installInstallerCurlStub(binDir) {
  writeExecutable(
    path.join(binDir, "curl"),
    `#!/usr/bin/env bash
set -euo pipefail

url=""
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    -*) shift ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

[[ -n "$output" ]] || exit 1
if [[ "$url" == *"Dockerfile"* ]]; then
  printf 'FROM scratch\\nARG OPENCLAW_VERSION=2026.1.1\\n' > "$output"
else
  printf 'placeholder\\n' > "$output"
fi
`,
  );
}

test("version query reports configured and latest versions", (t) => {
  const fixture = createFixture(t);
  installVersionQueryCurlStub(fixture.binDir);

  const result = run("bash", [versionScriptPath], fixture, {
    FAKE_TEMPLATE_DOCKERFILE: "ARG OPENCLAW_VERSION=2026.1.1",
    FAKE_DIST_TAGS_JSON: '{"latest":"2026.2.0"}',
  });

  assert.equal(result.status, 0, result.stderr);
  assert.equal(
    result.stdout,
    "configured_version=2026.1.1\nlatest_status=available\nlatest_version=2026.2.0\n",
  );
});

test("version query reports equal configured and latest versions", (t) => {
  const fixture = createFixture(t);
  installVersionQueryCurlStub(fixture.binDir);

  const result = run("bash", [versionScriptPath], fixture, {
    FAKE_TEMPLATE_DOCKERFILE: "ARG OPENCLAW_VERSION=2026.2.0",
    FAKE_DIST_TAGS_JSON: '{"latest":"2026.2.0"}',
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /configured_version=2026\.2\.0/);
  assert.match(result.stdout, /latest_status=available/);
  assert.match(result.stdout, /latest_version=2026\.2\.0/);
});

test("version query distinguishes an unpublished latest version", (t) => {
  const fixture = createFixture(t);
  installVersionQueryCurlStub(fixture.binDir);

  const result = run("bash", [versionScriptPath], fixture, {
    FAKE_TEMPLATE_DOCKERFILE: "ARG OPENCLAW_VERSION=2026.2.0",
    FAKE_DIST_TAGS_JSON: "{}",
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /latest_status=not_published/);
  assert.match(result.stdout, /latest_version=$/m);
});

test("version query distinguishes a failed latest-version query", (t) => {
  const fixture = createFixture(t);
  installVersionQueryCurlStub(fixture.binDir);

  const result = run("bash", [versionScriptPath], fixture, {
    FAKE_TEMPLATE_DOCKERFILE: "ARG OPENCLAW_VERSION=2026.2.0",
    FAKE_DIST_TAGS_RESULT: "failure",
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /latest_status=query_failed/);
  assert.match(result.stdout, /latest_version=$/m);
});

test("version query rejects an invalid configured version", (t) => {
  const fixture = createFixture(t);
  installVersionQueryCurlStub(fixture.binDir);

  const result = run("bash", [versionScriptPath], fixture, {
    FAKE_TEMPLATE_DOCKERFILE: "ARG OPENCLAW_VERSION=latest",
  });

  assert.equal(result.status, 1);
  assert.match(result.stderr, /invalid OpenClaw version/);
});

test("version query documents its interface and rejects unknown arguments", (t) => {
  const fixture = createFixture(t);
  installVersionQueryCurlStub(fixture.binDir);

  const helpResult = run("bash", [versionScriptPath, "--help"], fixture);
  assert.equal(helpResult.status, 0, helpResult.stderr);
  assert.match(helpResult.stdout, /latest_status=available\|not_published\|query_failed/);

  const invalidResult = run("bash", [versionScriptPath, "--unknown"], fixture);
  assert.equal(invalidResult.status, 2);
  assert.match(invalidResult.stderr, /unknown argument/);
});

test("harness requires a valid explicitly selected version", (t) => {
  const fixture = createFixture(t);

  const helpResult = run("bash", [harnessScriptPath, "--help"], fixture);
  assert.equal(helpResult.status, 0, helpResult.stderr);
  assert.match(helpResult.stdout, /--openclaw-version <version>/);

  const missingResult = run("bash", [harnessScriptPath, "--agent-dir", path.join(fixture.tempDir, "agent")], fixture);
  assert.equal(missingResult.status, 1);
  assert.match(missingResult.stderr, /--openclaw-version is required/);

  const invalidResult = run(
    "bash",
    [harnessScriptPath, "--agent-dir", path.join(fixture.tempDir, "agent"), "--openclaw-version", "latest"],
    fixture,
  );
  assert.equal(invalidResult.status, 1);
  assert.match(invalidResult.stderr, /must be a valid OpenClaw version/);
});

test("harness applies and verifies the selected version without a pseudo-terminal", (t) => {
  const fixture = createFixture(t);
  installHarnessStubs(fixture.binDir);
  const agentDir = path.join(fixture.tempDir, "agent");
  const dockerLogPath = path.join(fixture.tempDir, "docker.log");

  const result = run(
    "bash",
    [
      harnessScriptPath,
      "--agent-dir",
      agentDir,
      "--port",
      "19001",
      "--openclaw-version",
      "2026.2.0",
    ],
    fixture,
    {
      FAKE_DOCKER_LOG: dockerLogPath,
      FAKE_INSTALLED_VERSION: "2026.2.0",
    },
  );

  assert.equal(result.status, 0, result.stderr);
  assert.match(fs.readFileSync(path.join(agentDir, "Dockerfile"), "utf8"), /OPENCLAW_VERSION=2026\.2\.0/);
  assert.equal(fs.readFileSync(dockerLogPath, "utf8"), "build\n");
  assert.match(result.stdout, /openclaw_version: 2026\.2\.0/);

  const harnessSource = fs.readFileSync(harnessScriptPath, "utf8");
  assert.doesNotMatch(harnessSource, /script -qefc/);
  assert.doesNotMatch(harnessSource, /printf '\\n' \|/);
});

test("harness fails when the installed version differs from the selected version", (t) => {
  const fixture = createFixture(t);
  installHarnessStubs(fixture.binDir);
  const agentDir = path.join(fixture.tempDir, "agent");

  const result = run(
    "bash",
    [harnessScriptPath, "--agent-dir", agentDir, "--openclaw-version", "2026.2.0"],
    fixture,
    {
      FAKE_DOCKER_LOG: path.join(fixture.tempDir, "docker.log"),
      FAKE_INSTALLED_VERSION: "2026.1.1",
    },
  );

  assert.equal(result.status, 1);
  assert.match(result.stderr, /does not match requested version/);
});

test("installer applies an explicit version without prompting", (t) => {
  const fixture = createFixture(t);
  installInstallerCurlStub(fixture.binDir);
  const agentDir = path.join(fixture.tempDir, "agent");
  fs.mkdirSync(agentDir);

  const result = run(
    "bash",
    [installerScriptPath, "init", "--port", "19001", "--openclaw-version", "2026.2.0"],
    fixture,
    {},
    { cwd: agentDir },
  );

  assert.equal(result.status, 0, result.stderr);
  assert.match(fs.readFileSync(path.join(agentDir, "Dockerfile"), "utf8"), /OPENCLAW_VERSION=2026\.2\.0/);
  assert.doesNotMatch(result.stdout, /Press Enter to continue/);
});

test("installer rejects invalid explicit versions and documents the argument", (t) => {
  const fixture = createFixture(t);
  const agentDir = path.join(fixture.tempDir, "agent");
  fs.mkdirSync(agentDir);

  const invalidResult = run(
    "bash",
    [installerScriptPath, "init", "--openclaw-version", "latest"],
    fixture,
    {},
    { cwd: agentDir },
  );

  assert.equal(invalidResult.status, 1);
  assert.match(invalidResult.stderr, /must be a valid OpenClaw version/);

  const helpResult = run("bash", [installerScriptPath, "--help"], fixture);
  assert.equal(helpResult.status, 0, helpResult.stderr);
  assert.match(helpResult.stdout, /--openclaw-version <version>/);
});
