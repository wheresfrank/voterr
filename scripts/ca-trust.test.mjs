import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, existsSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const here = fileURLToPath(new URL(".", import.meta.url));
const script = join(here, "distrust-compromised-cas.sh");
const fixture = (name) => readFileSync(join(here, "ca-fixtures", name + ".pem"), "utf8");
const run = (cmd, args) => spawnSync(cmd, args, { encoding: "utf8" });

test("distrusts renamed G3/AAA anchors, preserves unrelated roots, and is idempotent", () => {
  const root = mkdtempSync(join(tmpdir(), "ca-distrust-"));
  try {
    const ca = join(root, "usr/share/ca-certificates/mozilla");
    const local = join(root, "usr/local/share/ca-certificates");
    mkdirSync(ca, { recursive: true });
    mkdirSync(local, { recursive: true });
    mkdirSync(join(root, "etc"));
    writeFileSync(join(ca, "renamed.crt"), fixture("emsign"));
    writeFileSync(join(ca, "keep.crt"), fixture("isrg"));
    writeFileSync(join(local, "legacy-cross-sign-root.crt"), fixture("aaa"));
    // An imported duplicate must not restore trust.
    writeFileSync(join(local, "duplicate.crt"), fixture("emsign"));
    writeFileSync(join(root, "etc/ca-certificates.conf"), "# preserve comments\nmozilla/renamed.crt\nmozilla/keep.crt\n");
    for (let i = 0; i < 2; i++) {
      const result = run("sh", [script, root]);
      assert.equal(result.status, 0, result.stderr);
    }
    assert.equal(existsSync(join(ca, "renamed.crt")), false);
    assert.equal(existsSync(join(local, "legacy-cross-sign-root.crt")), false);
    assert.equal(existsSync(join(local, "duplicate.crt")), false);
    assert.equal(readFileSync(join(ca, "keep.crt"), "utf8"), fixture("isrg"));
    assert.equal(readFileSync(join(root, "etc/ca-certificates.conf"), "utf8"),
      "# preserve comments\n!mozilla/renamed.crt\nmozilla/keep.crt\n");

    const bundle = join(root, "filtered.pem");
    writeFileSync(bundle, readdirSync(ca).filter(p => p.endsWith(".crt")).map(p => readFileSync(join(ca, p), "utf8")).join("\n"));
    // -trusted isolates the fixture anchors, including on OpenSSL 3 where
    // -CAfile/-CApath alone can still consult the default CAstore.
    const args = ["verify", "-trusted", bundle];
    assert.equal(run("openssl", [...args, join(here, "ca-fixtures/isrg.pem")]).status, 0);
    for (const name of ["emsign", "aaa"]) {
      const result = run("openssl", [...args, join(here, "ca-fixtures", name + ".pem")]);
      assert.notEqual(result.status, 0, name + " must be distrusted: " + result.stdout + result.stderr);
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("fails on a malformed CA instead of silently leaving it trusted", () => {
  const root = mkdtempSync(join(tmpdir(), "ca-invalid-"));
  try {
    const ca = join(root, "usr/share/ca-certificates");
    mkdirSync(ca, { recursive: true });
    writeFileSync(join(ca, "bad.crt"), "not a certificate");
    assert.notEqual(run("sh", [script, root]).status, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
