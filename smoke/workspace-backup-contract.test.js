const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const repoRoot = path.resolve(__dirname, "..");
const backupScriptSourcePath = path.join(
  repoRoot,
  ".openclaw",
  "skills",
  "backup-workspace-to-git",
  "scripts",
  "backup-workspace-to-git.sh",
);
const initializeScriptSourcePath = path.join(
  repoRoot,
  ".openclaw",
  "_scripts",
  "initialize-workspace.sh",
);
const workspaceGitignoreSourcePath = path.join(repoRoot, ".openclaw", "workspace.gitignore");

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function runCommand(command, args, options = {}) {
  return spawnSync(command, args, {
    encoding: "utf8",
    ...options,
  });
}

function createTempRoot(t, prefix) {
  const tempRoot = path.join(repoRoot, ".tmp-smoke");
  ensureDir(tempRoot);
  const tempDir = fs.mkdtempSync(path.join(tempRoot, prefix));

  t.after(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
    try {
      fs.rmdirSync(tempRoot);
    } catch {
      // Another test may still be using the shared temp root.
    }
  });

  return tempDir;
}

test("backup-workspace-to-git stages repo-tracked content from .gitignore", (t) => {
  const tempDir = createTempRoot(t, "backup-workspace-");
  const openclawDir = path.join(tempDir, ".openclaw");
  const scriptDir = path.join(openclawDir, "skills", "backup-workspace-to-git", "scripts");

  ensureDir(scriptDir);
  ensureDir(path.join(openclawDir, "workspace"));
  ensureDir(path.join(openclawDir, "skills", "custom-skill"));
  ensureDir(path.join(openclawDir, "_secrets"));

  fs.copyFileSync(backupScriptSourcePath, path.join(scriptDir, "backup-workspace-to-git.sh"));
  fs.copyFileSync(workspaceGitignoreSourcePath, path.join(openclawDir, ".gitignore"));
  fs.chmodSync(path.join(scriptDir, "backup-workspace-to-git.sh"), 0o755);

  fs.writeFileSync(path.join(openclawDir, "workspace", "notes.md"), "workspace data\n");
  fs.writeFileSync(path.join(openclawDir, "skills", "custom-skill", "SKILL.md"), "custom skill\n");
  fs.writeFileSync(path.join(openclawDir, "_secrets", "token.txt"), "ignore me\n");

  let result = runCommand("git", ["init"], { cwd: openclawDir });
  assert.equal(result.status, 0, result.stderr);

  result = runCommand("git", ["config", "user.name", "Test User"], { cwd: openclawDir });
  assert.equal(result.status, 0, result.stderr);

  result = runCommand("git", ["config", "user.email", "test@example.com"], { cwd: openclawDir });
  assert.equal(result.status, 0, result.stderr);

  result = runCommand("bash", [path.join(scriptDir, "backup-workspace-to-git.sh")], { cwd: openclawDir });
  assert.equal(result.status, 0, result.stderr);

  result = runCommand("git", ["ls-files"], { cwd: openclawDir });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /(^|\n)\.gitignore(\n|$)/);
  assert.match(result.stdout, /(^|\n)workspace\/notes\.md(\n|$)/);
  assert.match(result.stdout, /(^|\n)skills\/custom-skill\/SKILL\.md(\n|$)/);
  assert.doesNotMatch(result.stdout, /_secrets\/token\.txt/);

  result = runCommand("git", ["log", "--format=%s", "-1"], { cwd: openclawDir });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), "backup workspace");
});

test("initialize-workspace restores workspace, skills, and .gitignore", (t) => {
  const tempDir = createTempRoot(t, "initialize-workspace-");
  const sourceDir = path.join(tempDir, "source", ".openclaw");
  const targetDir = path.join(tempDir, "target", ".openclaw");
  const scriptDir = path.join(tempDir, "script-home", ".openclaw", "_scripts");
  const scriptPath = path.join(scriptDir, "initialize-workspace.sh");

  ensureDir(path.join(sourceDir, "workspace"));
  ensureDir(path.join(sourceDir, "skills", "custom-skill"));
  ensureDir(targetDir);
  ensureDir(scriptDir);

  fs.copyFileSync(initializeScriptSourcePath, scriptPath);
  fs.chmodSync(scriptPath, 0o755);

  fs.writeFileSync(path.join(sourceDir, "workspace", "notes.md"), "workspace restored\n");
  fs.writeFileSync(path.join(sourceDir, "skills", "custom-skill", "SKILL.md"), "skill restored\n");
  fs.writeFileSync(path.join(sourceDir, ".gitignore"), "*\n!/.gitignore\n!/workspace/\n!/workspace/**\n!/skills/\n!/skills/**\n");

  const result = runCommand("bash", [scriptPath, sourceDir], {
    cwd: tempDir,
    env: {
      ...process.env,
      TARGET_DIR: targetDir,
    },
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Initialized workspace: workspace/);
  assert.match(result.stdout, /Initialized workspace: skills/);
  assert.match(result.stdout, /Initialized workspace: \.gitignore/);
  assert.equal(fs.readFileSync(path.join(targetDir, "workspace", "notes.md"), "utf8"), "workspace restored\n");
  assert.equal(fs.readFileSync(path.join(targetDir, "skills", "custom-skill", "SKILL.md"), "utf8"), "skill restored\n");
  assert.match(fs.readFileSync(path.join(targetDir, ".gitignore"), "utf8"), /!\/skills\/\*\*/);
});
