import * as vscode from "vscode";
import { DiagnosticManager } from "./diagnostics";
import {
	documentationUri,
	localizedVariants,
	switchLocalization,
	text,
} from "./localization";
import { ProjectIndex } from "./project-index";
import { registerLanguageProviders } from "./providers";

export async function activate(
	context: vscode.ExtensionContext,
): Promise<void> {
	const output = vscode.window.createOutputChannel("Konado");
	const index = new ProjectIndex(output);
	const diagnostics = new DiagnosticManager(index);
	const localeStatus = vscode.window.createStatusBarItem(
		vscode.StatusBarAlignment.Right,
		90,
	);
	localeStatus.name = "Konado Script Language";
	localeStatus.command = "konado.switchLocalization";
	localeStatus.tooltip = text("Switch script language", "切换剧本语言");

	context.subscriptions.push(output, index, diagnostics, localeStatus);
	registerLanguageProviders(context, index, diagnostics);

	context.subscriptions.push(
		vscode.commands.registerCommand(
			"konado.openDocumentation",
			async () => {
				await vscode.env.openExternal(documentationUri());
			},
		),
		vscode.commands.registerCommand(
			"konado.switchLocalization",
			switchLocalization,
		),
		vscode.commands.registerCommand("konado.reindexProject", async () => {
			await vscode.window.withProgress(
				{
					location: vscode.ProgressLocation.Notification,
					title: text(
						"Indexing the Konado project",
						"正在索引 Konado 项目",
					),
				},
				() => index.rebuild(),
			);
			void vscode.window.showInformationMessage(
				text(
					"Konado project index updated.",
					"Konado 项目索引已更新。",
				),
			);
		}),
		vscode.commands.registerCommand("konado.validateWorkspace", () =>
			diagnostics.validateWorkspace(),
		),
	);

	const updateLocaleStatus = async (): Promise<void> => {
		const editor = vscode.window.activeTextEditor;
		if (!editor || editor.document.languageId !== "konadoscript") {
			localeStatus.hide();
			await vscode.commands.executeCommand(
				"setContext",
				"konado.hasLocalizations",
				false,
			);
			return;
		}
		const variants = await localizedVariants(editor.document);
		const hasVariants = variants.length > 1;
		await vscode.commands.executeCommand(
			"setContext",
			"konado.hasLocalizations",
			hasVariants,
		);
		if (!hasVariants) {
			localeStatus.hide();
			return;
		}
		const current = variants.find((variant) => variant.current);
		localeStatus.text = `$(globe) ${current?.label ?? text("Default", "默认")}`;
		localeStatus.show();
	};

	const localeWatcher = vscode.workspace.createFileSystemWatcher("**/*.ks");
	localeWatcher.onDidCreate(() => void updateLocaleStatus());
	localeWatcher.onDidDelete(() => void updateLocaleStatus());
	context.subscriptions.push(
		localeWatcher,
		vscode.window.onDidChangeActiveTextEditor(
			() => void updateLocaleStatus(),
		),
	);

	await index.rebuild();
	await diagnostics.validateOpenDocuments();
	await updateLocaleStatus();
	output.appendLine("KonadoScript language services activated.");
}

export function deactivate(): void {
	// All resources are owned by the extension context.
}
