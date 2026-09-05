import { context } from "esbuild";

const watch = process.argv.includes("--watch");
const build = await context({
	entryPoints: ["src/extension.ts"],
	bundle: true,
	outfile: "dist/extension.js",
	external: ["vscode"],
	format: "cjs",
	platform: "node",
	target: "node20",
	sourcemap: true,
	sourcesContent: false,
	logLevel: "info",
});

if (watch) {
	await build.watch();
} else {
	await build.rebuild();
	await build.dispose();
}
