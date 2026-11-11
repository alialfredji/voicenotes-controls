import { cp, mkdir, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const releaseName = "voicenotes-controls-0.2.0";
const release = path.join(root, "releases", releaseName);
const manifest = JSON.parse(
  await readFile(path.join(root, "package.json"), "utf8"),
);
const built = JSON.parse(
  await readFile(path.join(root, "dist/package.json"), "utf8"),
);
if (
  built.author !== manifest.author ||
  built.description !== manifest.description ||
  JSON.stringify(built.commands) !== JSON.stringify(manifest.commands)
) {
  throw new Error(
    "Rebuild the distribution from the current manifest before packaging.",
  );
}
const screenshots = (await readdir(path.join(root, "metadata"))).filter(
  (name) => name.endsWith(".png"),
);
if (!screenshots.length)
  throw new Error(
    "Add a current, privacy-safe Store screenshot before packaging.",
  );
await rm(release, { recursive: true, force: true });
const source = path.join(release, "source", manifest.name);
const compiled = path.join(release, "compiled", manifest.name);
await mkdir(source, { recursive: true });
await mkdir(path.dirname(compiled), { recursive: true });
const excluded = new Set([
  "node_modules",
  ".git",
  ".build",
  ".swiftpm",
  ".raycast-swift-build",
  ".native-tests",
  "compiled_raycast_swift",
  "compiled_raycast_rust",
  ".DS_Store",
]);
const sourceFiles = [
  "package.json",
  "package-lock.json",
  "README.md",
  "TODO.md",
  "help.md",
  "CHANGELOG.md",
  "LICENSE",
  "UPSTREAM.md",
  "tsconfig.json",
  "eslint.config.mjs",
  ".gitignore",
  "src",
  "native",
  "assets",
  "metadata",
  "scripts",
  "tools",
  "docs",
];
for (const name of sourceFiles) {
  await cp(path.join(root, name), path.join(source, name), {
    recursive: true,
    filter: (entry) => !excluded.has(path.basename(entry)),
  });
}
await cp(path.join(root, "dist"), compiled, { recursive: true });
async function files(folder) {
  const found = [];
  for (const entry of await readdir(folder, { withFileTypes: true })) {
    const full = path.join(folder, entry.name);
    if (entry.isDirectory()) found.push(...(await files(full)));
    else if (entry.isFile()) found.push(full);
  }
  return found;
}
const nativeBinaries = [];
for (const file of await files(compiled)) {
  const data = await readFile(file);
  if (
    ["cafebabe", "bebafeca", "cafebabf", "bfbafeca"].includes(
      data.subarray(0, 4).toString("hex"),
    )
  ) {
    const architectures = execFileSync("/usr/bin/lipo", ["-archs", file], {
      encoding: "utf8",
    })
      .trim()
      .split(/\s+/);
    if (!architectures.includes("arm64") || !architectures.includes("x86_64"))
      throw new Error("Native binary must include both Mac architectures.");
    nativeBinaries.push({
      file: path.relative(compiled, file),
      architectures,
      sha256: createHash("sha256").update(data).digest("hex"),
    });
  }
}
if (!nativeBinaries.length)
  throw new Error("The distribution has no universal native module.");
const sourceZip = path.join(release, `${releaseName}-source.zip`);
const compiledZip = path.join(release, `${releaseName}-compiled.zip`);
// Public Raycast currently rejects .rayext imports. Ship JavaScript entry points
// plus the prebuilt Swift module so the normal local build needs no Swift tools.
const install = path.join(release, "local-install", releaseName);
await mkdir(path.join(install, "src"), { recursive: true });
await cp(path.join(compiled, "assets"), path.join(install, "assets"), {
  recursive: true,
});
for (const command of manifest.commands) {
  await cp(
    path.join(compiled, `${command.name}.js`),
    path.join(install, "src", `${command.name}.js`),
  );
}
await writeFile(
  path.join(install, "package.json"),
  `${JSON.stringify(
    {
      ...manifest,
      scripts: { "install:local": "ray build", dev: "ray develop" },
    },
    null,
    2,
  )}\n`,
);
for (const name of [
  "package-lock.json",
  "LICENSE",
  "UPSTREAM.md",
  "help.md",
  "README.md",
  "TODO.md",
  "CHANGELOG.md",
]) {
  await cp(path.join(root, name), path.join(install, name));
}
await writeFile(
  path.join(install, "install.sh"),
  `#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Voicenotes Controls requires macOS."
  exit 1
fi
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "Install Node.js 22.22.2 or newer from https://nodejs.org/, then rerun this script."
  exit 1
fi
node -e 'const [m,n,p]=process.versions.node.split(".").map(Number); if (!(m>22||(m===22&&(n>22||(n===22&&p>=2))))) { console.error("Node.js 22.22.2 or newer is required."); process.exit(1); }'
if [[ ! -d /Applications/Raycast.app && ! -d "$HOME/Applications/Raycast.app" ]]; then
  echo "Install Raycast in Applications before continuing."
  exit 1
fi
npm ci --omit=dev
npm run install:local
echo "Installed Voicenotes Controls. Open Raycast and run Recording Setup and Status."
`,
  { mode: 0o755 },
);
const installZip = path.join(release, `${releaseName}-macos.zip`);
for (const [folder, zip] of [
  [source, sourceZip],
  [compiled, compiledZip],
  [install, installZip],
]) {
  execFileSync("/usr/bin/ditto", ["-c", "-k", "--keepParent", folder, zip]);
}
const metadata = {
  release: releaseName,
  createdAt: new Date().toISOString(),
  sourceCommit: execFileSync("git", ["rev-parse", "HEAD"], {
    cwd: root,
    encoding: "utf8",
  }).trim(),
  sourceHadUncommittedChanges: Boolean(
    execFileSync("git", ["status", "--porcelain"], {
      cwd: root,
      encoding: "utf8",
    }).trim(),
  ),
  manifest: {
    name: manifest.name,
    title: manifest.title,
    author: manifest.author,
    commands: manifest.commands.map((c) => c.name),
  },
  validatedVoicenotesVersions: ["2.4.2", "2.4.3", "2.4.4"],
  navigationVoicenotesVersions: ["2.4.4"],
  raycastApi: manifest.dependencies["@raycast/api"],
  nativeBinaries,
  installation: {
    archive: path.basename(installZip),
    command: "bash install.sh",
    requires: [
      "macOS 14+",
      "Raycast",
      "Node.js 22.22.2+ and npm",
      "Voicenotes 2.4.4 for all commands (2.4.2/2.4.3 for recording only)",
    ],
    requiresXcode: false,
    rayext: "Public Raycast 2.11.1 rejects bundles: internal builds only",
  },
  status: "GitHub release; not submitted to the Raycast Store",
};
await writeFile(
  path.join(release, "RELEASE.json"),
  `${JSON.stringify(metadata, null, 2)}\n`,
);
const sums = [];
for (const filename of [
  sourceZip,
  compiledZip,
  installZip,
  path.join(release, "RELEASE.json"),
]) {
  sums.push(
    `${createHash("sha256")
      .update(await readFile(filename))
      .digest("hex")}  ${path.basename(filename)}`,
  );
}
await writeFile(path.join(release, "SHA256SUMS"), `${sums.join("\n")}\n`);
console.log(
  `Packaged ${releaseName}: macOS installer ZIP, source ZIP, compiled ZIP, RELEASE.json, SHA256SUMS`,
);
