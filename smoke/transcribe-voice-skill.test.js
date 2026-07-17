const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const repoRoot = path.resolve(__dirname, "..");
const skillDir = path.join(repoRoot, ".openclaw", "skills", "transcribe-voice");
const skillMarkdownPath = path.join(skillDir, "SKILL.md");
const scriptPath = path.join(skillDir, "scripts", "transcribe.mjs");
const packageJsonPath = path.join(skillDir, "scripts", "package.json");

test("transcribe-voice skill files exist and match the expected contract", () => {
  assert.equal(fs.existsSync(skillMarkdownPath), true);
  assert.equal(fs.existsSync(scriptPath), true);
  assert.equal(fs.existsSync(packageJsonPath), true);

  const skillMarkdown = fs.readFileSync(skillMarkdownPath, "utf8");
  assert.match(skillMarkdown, /^name: transcribe-voice$/m);
  assert.match(skillMarkdown, /npm install --prefix \/home\/node\/\.openclaw\/skills\/transcribe-voice\/scripts/);
  assert.match(skillMarkdown, /node \/home\/node\/\.openclaw\/skills\/transcribe-voice\/scripts\/transcribe\.mjs \/path\/to\/audio\.ogg 2>\/dev\/null/);

  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
  assert.equal(packageJson.name, "transcribe-voice-scripts");
  assert.equal(packageJson.type, "module");
  assert.equal(packageJson.dependencies["@xenova/transformers"], "^2.17.2");
  assert.equal(packageJson.dependencies["ffmpeg-static"], "^5.3.0");
  assert.equal(packageJson.dependencies.wavefile, "^11.0.0");
});

test("transcribe.mjs passes node syntax check", () => {
  const result = spawnSync("node", ["--check", scriptPath], {
    encoding: "utf8",
    cwd: repoRoot,
  });

  assert.equal(result.status, 0, result.stderr || result.stdout);
});
