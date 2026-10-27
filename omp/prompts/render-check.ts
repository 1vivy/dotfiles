// Render a candidate SYSTEM_TEMPLATE.md with the installed OMP release's own template engine.
// DeepSeek models must get the DeepSeek block with no unrendered tags; every other model must get
// output byte-identical to OMP's bundled block 0. Usage: bun render-check.ts <template> [version]
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const RAW = "https://raw.githubusercontent.com/can1357/oh-my-pi/v";
const templatePath = Bun.argv[2];
if (!templatePath) throw new Error("usage: bun render-check.ts <template> [version]");
const version =
	Bun.argv[3] ?? (await Bun.$`omp --version`.text()).match(/(\d+\.\d+\.\d+)/)?.[1] ?? "";
if (!version) throw new Error("cannot determine omp version");

async function fetchText(path: string): Promise<string> {
	const res = await fetch(`${RAW}${version}/${path}`);
	if (!res.ok) throw new Error(`${path}: HTTP ${res.status}`);
	return res.text();
}

const dir = await mkdtemp(join(tmpdir(), "omp-render-"));
// The engine's entry module and its relative imports (template.ts, lru.ts, …) move between
// releases, so fetch the modules the sources ask for instead of a hard-coded list.
const ENGINE_DIR = "packages/utils/src";
const pending = ["prompt.ts"];
const fetched = new Set<string>();
while (pending.length) {
	const name = pending.shift()!;
	if (fetched.has(name)) continue;
	fetched.add(name);
	const source = await fetchText(`${ENGINE_DIR}/${name}`);
	await Bun.write(join(dir, name), source);
	for (const [, specifier] of source.matchAll(/from\s+["'](\.\/[^"']+)["']/g)) {
		pending.push(`${specifier.slice(2)}.ts`);
	}
}
const bundled = await fetchText("packages/coding-agent/src/prompts/system/system-prompt.md");
// Dynamic import: the engine source is fetched for the installed OMP version at runtime.
const { render } = await import(join(dir, "prompt.ts"));
const candidate = await Bun.file(templatePath).text();

function tools(names: string[]) {
	return {
		tools: names,
		toolRefs: Object.fromEntries(names.map(n => [n, n])),
		toolInfo: names.map(name => ({ name, label: name })),
		toolListMode: true,
	};
}
const common = {
	skills: [{ name: "probe", description: "probe" }],
	alwaysApplyRules: [],
	rules: [],
	internalUrls: ["`skill://<name>`: instructions"],
	intentTracing: true,
	intentField: "i",
	secretsEnabled: true,
	autoQaEnabled: true,
	renderMermaid: true,
	MAX_CONCURRENCY: 32,
	taskBatch: true,
	taskIrcEnabled: true,
	scoutAvailable: true,
	browserEnabled: true,
	computerEnabled: true,
};
const cases: Record<string, Record<string, unknown>> = {
	scout: { ...common, ...tools(["read", "find", "grep", "glob", "web_search", "yield"]), subagent: true },
	task: {
		...common,
		...tools(["read", "bash", "edit", "eval", "glob", "grep", "task", "wait", "todo", "write", "yield", "lsp", "ast_edit"]),
		subagent: true,
		xdevTools: ["lsp", "ast_edit"],
		xdevDocs: "- xd://lsp",
		delegationBias: "eager",
	},
	main: {
		...common,
		...tools(["read", "bash", "edit", "eval", "glob", "grep", "task", "wait", "todo", "write", "ask"]),
		delegationBias: "eager",
		eagerTasks: true,
	},
};
// OMP >= 18.5.0 renders `model` as "provider/id:<effort>"; bare ids cover an unset level.
const models = [
	"omni/omp/deepseek-v4.1-flash",
	"omni/omp/deepseek-v4.1-flash:high",
	"omni/omp/deepseek-v4.1-flash:off",
	"openai-codex/gpt-5.6-sol:high",
	"anthropic/claude-opus-5-5:high",
	"",
];

let failures = 0;
for (const [name, data] of Object.entries(cases)) {
	for (const model of models) {
		const out: string = render(candidate, { ...data, model });
		const ds = model.includes("deepseek");
		const ok = ds
			? out.startsWith("You are DeepSeek") && !out.includes("{{")
			: out === render(bundled, { ...data, model });
		if (!ok) failures++;
		console.log(`${ok ? "ok  " : "FAIL"} omp ${version} ${name.padEnd(8)} ${model || "(hidden model)"}`);
	}
}
process.exit(failures ? 1 : 0);
