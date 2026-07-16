const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const repoRoot = path.resolve(__dirname, "..");
const sourceScriptPath = path.join(
  repoRoot,
  ".openclaw",
  "skills",
  "authenticate-github-repo",
  "scripts",
  "authenticate-github-repo.sh",
);

function writeExecutable(filePath, contents) {
  fs.writeFileSync(filePath, contents);
  fs.chmodSync(filePath, 0o755);
}

function createFixture(t) {
  const tempRoot = path.join(repoRoot, ".tmp-smoke");
  fs.mkdirSync(tempRoot, { recursive: true });

  const tempDir = fs.mkdtempSync(path.join(tempRoot, "openclaw-auth-skill-"));
  const openclawDir = path.join(tempDir, ".openclaw");
  const scriptDir = path.join(openclawDir, "skills", "authenticate-github-repo", "scripts");
  const homeDir = path.join(tempDir, "home");
  const binDir = path.join(tempDir, "bin");
  const scriptPath = path.join(scriptDir, "authenticate-github-repo.sh");

  fs.mkdirSync(scriptDir, { recursive: true });
  fs.mkdirSync(path.join(openclawDir, "workspace"), { recursive: true });
  fs.mkdirSync(homeDir, { recursive: true });
  fs.mkdirSync(binDir, { recursive: true });

  fs.copyFileSync(sourceScriptPath, scriptPath);
  fs.chmodSync(scriptPath, 0o755);

  writeExecutable(
    path.join(binDir, "ssh-keyscan"),
    `#!/usr/bin/env bash
set -euo pipefail
echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKeyForTests"
`,
  );

  writeExecutable(
    path.join(binDir, "ssh-keygen"),
    `#!/usr/bin/env bash
set -euo pipefail

output_path=""
comment=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      output_path="$2"
      shift 2
      ;;
    -C)
      comment="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$output_path" ]]; then
  echo "missing -f for ssh-keygen stub" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_path")"
printf "PRIVATE KEY FOR %s\\n" "$comment" > "$output_path"
printf "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestPublicKey %s\\n" "$comment" > "\${output_path}.pub"
`,
  );

  writeExecutable(
    path.join(binDir, "git"),
    `#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ge 2 && "$1" == "ls-remote" ]]; then
  if [[ "\${GIT_LS_REMOTE_STATUS:-1}" == "0" ]]; then
    echo "0123456789abcdef0123456789abcdef01234567 HEAD"
    exit 0
  fi

  exit 1
fi

if [[ "$#" -eq 3 && "$1" == "clone" ]]; then
  mkdir -p "$3/.git"
  printf "%s\\n" "$2" > "$3/.origin-url"
  exit 0
fi

if [[ "$#" -eq 5 && "$1" == "-C" && "$3" == "remote" && "$4" == "get-url" && "$5" == "origin" ]]; then
  cat "$2/.origin-url"
  exit 0
fi

echo "unsupported git stub invocation: $*" >&2
exit 1
`,
  );

  t.after(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
    fs.rmSync(tempRoot, { recursive: true, force: true });
  });

  return {
    binDir,
    homeDir,
    openclawDir,
    scriptPath,
    tempDir,
  };
}

function runScript(fixture, args, extraEnv = {}) {
  return spawnSync("bash", [fixture.scriptPath, ...args], {
    cwd: fixture.openclawDir,
    encoding: "utf8",
    env: {
      ...process.env,
      HOME: fixture.homeDir,
      PATH: `${fixture.binDir}:${process.env.PATH}`,
      ...extraEnv,
    },
  });
}

test("prints help", (t) => {
  const fixture = createFixture(t);
  const result = runScript(fixture, ["--help"]);

  assert.equal(result.status, 0);
  assert.match(result.stdout, /Usage:/);
  assert.match(result.stdout, /prepare --github-repo-url/);
});

test("fails when github repo url is missing", (t) => {
  const fixture = createFixture(t);
  const result = runScript(fixture, ["prepare"]);

  assert.equal(result.status, 1);
  assert.match(result.stderr, /--github-repo-url is required/);
});

test("prepares auth material and finalizes clone", (t) => {
  const fixture = createFixture(t);
  const repoUrl = "https://github.com/owner/repo";
  const expectedOrigin = "git@github.com-openclaw-repo:owner/repo.git";

  const prepareResult = runScript(fixture, ["prepare", "--github-repo-url", repoUrl], {
    GIT_LS_REMOTE_STATUS: "1",
  });

  assert.equal(prepareResult.status, 0);
  assert.match(prepareResult.stdout, /GitHub deploy key setup:/);
  assert.match(
    prepareResult.stdout,
    /Public key host path:\n  \.\/\.openclaw\/_secrets\/git\/\.ssh\/openclaw_github_repo_ed25519\.pub/,
  );
  assert.match(prepareResult.stdout, /ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestPublicKey/);

  const metadataPath = path.join(fixture.openclawDir, "_secrets", "git", "repos", "repo.env");
  const clonePath = path.join(fixture.openclawDir, "workspace", "repos", "repo");

  assert.equal(fs.existsSync(path.join(fixture.homeDir, ".ssh", "openclaw_github_repo_ed25519")), true);
  assert.equal(fs.existsSync(path.join(fixture.homeDir, ".ssh", "openclaw_github_repo_ed25519.pub")), true);
  assert.match(fs.readFileSync(metadataPath, "utf8"), /GITHUB_REPO_URL=https:\/\/github.com\/owner\/repo/);

  const finalizeResult = runScript(fixture, ["finalize", "--github-repo-url", repoUrl], {
    GIT_LS_REMOTE_STATUS: "0",
  });

  assert.equal(finalizeResult.status, 0);
  assert.match(finalizeResult.stdout, /GitHub repo authenticated and cloned:/);
  assert.match(finalizeResult.stdout, new RegExp(expectedOrigin.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.equal(fs.existsSync(clonePath), true);
  assert.equal(fs.readFileSync(path.join(clonePath, ".origin-url"), "utf8").trim(), expectedOrigin);

  const collisionResult = runScript(fixture, ["finalize", "--github-repo-url", repoUrl], {
    GIT_LS_REMOTE_STATUS: "0",
  });

  assert.equal(collisionResult.status, 1);
  assert.match(collisionResult.stderr, /clone target already exists/);
  assert.match(collisionResult.stderr, /--replace-clone/);
});
