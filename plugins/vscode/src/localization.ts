import * as path from "node:path";
import * as vscode from "vscode";
import { commandKey } from "./catalog";
import { tokenizeLine } from "./language";

const SCRIPT_LOCALES = [
	{ suffix: "", label: "Default", labelZh: "默认" },
	{ suffix: "zh_Hans", label: "Simplified Chinese", labelZh: "简体中文" },
	{ suffix: "zh_Hant", label: "Traditional Chinese", labelZh: "繁體中文" },
	{ suffix: "en", label: "English", labelZh: "英语" },
	{ suffix: "ja", label: "日本語", labelZh: "日语" },
	{ suffix: "ko", label: "한국어", labelZh: "韩语" },
] as const;

const DOC_PATHS: Readonly<Record<string, string>> = {
	screentext: "screentext",
	showtextbox: "dialogbox",
	hidetextbox: "dialogbox",
	waitsignal: "waitsignal",
	background: "background/background-switch",
	actor: "actor/index",
	"actor show": "actor/create-actor",
	"actor exit": "actor/actor-leave",
	"actor change": "actor/actor-change-state",
	"actor move": "actor/actor-move",
	"actor motion": "actor/actor-change-state",
	play: "audio/index",
	"play bgm": "audio/play-bgm",
	"play sfx": "audio/play-sound-effect",
	stop: "audio/stop-bgm",
	choice: "choice",
	branch: "branch",
	if: "if-else-branch",
	else: "if-else-branch",
	endif: "if-else-branch",
	set: "variable-system",
	add: "variable-system",
	sub: "variable-system",
	mul: "variable-system",
	div: "variable-system",
	jump: "branch",
	jump_branch: "branch",
	signal: "signal",
	achievement: "foundation",
	cam: "camera/index",
	"cam move": "camera/cam-move",
	"cam reset": "camera/cam-reset",
	"cam shake": "camera/cam-shake",
	asyncam: "camera/asyncam",
	end: "end-the-conversation",
};

export function isChineseUi(): boolean {
	return vscode.env.language.toLowerCase().startsWith("zh");
}

export function text(english: string, chinese: string): string {
	return isChineseUi() ? chinese : english;
}

export function documentationUri(
	editor = vscode.window.activeTextEditor,
): vscode.Uri {
	const configured = vscode.workspace
		.getConfiguration("konado")
		.get<string>("documentation.language", "auto");
	const locale =
		configured === "auto"
			? documentationLocale(vscode.env.language)
			: configured;
	let page = "konado-script";
	if (editor?.document.languageId === "konadoscript") {
		const line = editor.document.lineAt(editor.selection.active.line).text;
		const words = tokenizeLine(line).map((token) => token.text);
		page = DOC_PATHS[commandKey(words)] ?? page;
	}
	return vscode.Uri.parse(
		`https://godothub.com/oss/konado/${locale}/latest/tutorial/script/${page}.html`,
	);
}

function documentationLocale(locale: string): string {
	const normalized = locale.toLowerCase();
	if (normalized.startsWith("zh-tw") || normalized.startsWith("zh-hk")) {
		return "tc";
	}
	if (normalized.startsWith("zh")) {
		return "zh";
	}
	if (normalized.startsWith("ja")) {
		return "ja";
	}
	if (normalized.startsWith("ko")) {
		return "ko";
	}
	return "en";
}

export async function localizedVariants(
	document: vscode.TextDocument,
): Promise<{ uri: vscode.Uri; label: string; current: boolean }[]> {
	if (document.uri.scheme !== "file" || !document.uri.path.endsWith(".ks")) {
		return [];
	}
	const currentStem = path.basename(document.uri.fsPath, ".ks");
	const matchedLocale = SCRIPT_LOCALES.find(
		({ suffix }) => suffix.length > 0 && currentStem.endsWith(`.${suffix}`),
	);
	const baseStem = matchedLocale
		? currentStem.slice(0, -(matchedLocale.suffix.length + 1))
		: currentStem;
	const folder = vscode.Uri.file(path.dirname(document.uri.fsPath));
	const results: { uri: vscode.Uri; label: string; current: boolean }[] = [];
	for (const locale of SCRIPT_LOCALES) {
		const fileName = `${baseStem}${locale.suffix ? `.${locale.suffix}` : ""}.ks`;
		const uri = vscode.Uri.joinPath(folder, fileName);
		try {
			await vscode.workspace.fs.stat(uri);
			results.push({
				uri,
				label: isChineseUi() ? locale.labelZh : locale.label,
				current: uri.toString() === document.uri.toString(),
			});
		} catch {
			// The locale is not available for this script.
		}
	}
	return results.length > 1 ? results : [];
}

export async function switchLocalization(): Promise<void> {
	const editor = vscode.window.activeTextEditor;
	if (!editor || editor.document.languageId !== "konadoscript") {
		return;
	}
	const variants = await localizedVariants(editor.document);
	if (variants.length < 2) {
		void vscode.window.showInformationMessage(
			text(
				"No localized versions were found for this script.",
				"当前剧本没有可切换的多语言版本。",
			),
		);
		return;
	}
	const selected = await vscode.window.showQuickPick(
		variants.map((variant) => ({
			label: variant.label,
			description: variant.current ? text("Current", "当前") : undefined,
			variant,
		})),
		{
			placeHolder: text("Select a script language", "选择剧本语言"),
		},
	);
	if (!selected || selected.variant.current) {
		return;
	}
	const document = await vscode.workspace.openTextDocument(
		selected.variant.uri,
	);
	await vscode.window.showTextDocument(document, {
		viewColumn: editor.viewColumn,
		preserveFocus: false,
		preview: false,
	});
}
