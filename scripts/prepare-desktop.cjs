// Run from windows/ or linux/: both platforms ship the same maintained UI.
const fs = require("node:fs");
const path = require("node:path");
const { createRequire } = require("node:module");
const root = path.resolve(__dirname, "..");
const platform = process.cwd();
if (!["windows", "linux"].includes(path.basename(platform)))
  throw new Error("Run from windows/ or linux/");
const requirePlatform = createRequire(path.join(platform, "package.json"));
async function build() {
  for (const name of ["index.html", "desktop.css"])
    fs.copyFileSync(
      path.join(root, "shared/desktop", name),
      path.join(platform, "src", name),
    );
  fs.cpSync(
    path.join(root, "shared/editor"),
    path.join(platform, "src/editor"),
    { recursive: true },
  );
  await requirePlatform("esbuild").build({
    entryPoints: [path.join(root, "shared/desktop/main.js")],
    bundle: true,
    outfile: path.join(platform, "src/main.js"),
    nodePaths: [path.join(platform, "node_modules")],
    target: ["chrome105", "safari15"],
    format: "iife",
  });
}
build().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
