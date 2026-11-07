import { cp, mkdir, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const releaseName = "voicenotes-controls-0.1.0";
const release = path.join(root, "releases", releaseName);
const manifest = JSON.parse(
  await readFile(path.join(root, "package.json"), "utf8"),
);
const built = JSON.parse(
  await readFile(path.join(root, "dist/package.json"), "utf8"),
);
if (
  built.author !== manifest.author ||
  built.commands.length !== 4 ||
  built.commands.some((c) => c.preferences || c.name === "search-notes")
) {
  throw new Error("Rebuild the recording-only distribution before packaging.");
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
for (const [folder, zip] of [
  [source, sourceZip],
  [compiled, compiledZip],
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
  validatedVoicenotesVersions: ["2.4.2", "2.4.3"],
  raycastApi: manifest.dependencies["@raycast/api"],
  nativeBinaries,
  status: "release-candidate; not submitted to the Raycast Store",
};
await writeFile(
  path.join(release, "RELEASE.json"),
  `${JSON.stringify(metadata, null, 2)}\n`,
);
const sums = [];
for (const filename of [
  sourceZip,
  compiledZip,
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
  `Packaged ${releaseName}: source ZIP, compiled ZIP, RELEASE.json, SHA256SUMS`,
);
