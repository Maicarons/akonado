import * as vscode from "vscode";
import { analyzeDocument, type DiagnosticSpec } from "./language";
import { isChineseUi, text } from "./localization";
import type { ProjectIndex } from "./project-index";

const VALIDATION_DELAY_MS = 150;

export class DiagnosticManager implements vscode.Disposable {
	private readonly collection =
		vscode.languages.createDiagnosticCollection("konado");
	private readonly timers = new Map<string, NodeJS.Timeout>();
	private readonly specs = new Map<string, DiagnosticSpec[]>();
	private readonly subscriptions: vscode.Disposable[] = [];

	constructor(private readonly index: ProjectIndex) {
		this.subscriptions.push(
			vscode.workspace.onDidOpenTextDocument((document) =>
				this.schedule(document, 0),
			),
			vscode.workspace.onDidChangeTextDocument(({ document }) => {
				this.index.updateDocument(document);
				this.schedule(document);
			}),
			vscode.workspace.onDidSaveTextDocument((document) => {
				this.index.scheduleRebuild();
				this.schedule(document, 0);
			}),
			vscode.workspace.onDidCloseTextDocument((document) => {
				const key = document.uri.toString();
				const timer = this.timers.get(key);
				if (timer) {
					clearTimeout(timer);
					this.timers.delete(key);
				}
				this.specs.delete(key);
				this.collection.delete(document.uri);
			}),
			vscode.workspace.onDidChangeConfiguration((event) => {
				if (event.affectsConfiguration("konado.diagnostics.enable")) {
					void this.validateOpenDocuments();
				}
			}),
			this.index.onDidChange(() => {
				void this.validateOpenDocuments();
			}),
		);
	}

	dispose(): void {
		for (const timer of this.timers.values()) {
			clearTimeout(timer);
		}
		this.timers.clear();
		this.subscriptions.forEach((subscription) => subscription.dispose());
		this.collection.dispose();
	}

	getSpecs(uri: vscode.Uri): readonly DiagnosticSpec[] {
		return this.specs.get(uri.toString()) ?? [];
	}

	schedule(document: vscode.TextDocument, delay = VALIDATION_DELAY_MS): void {
		if (document.languageId !== "konadoscript") {
			return;
		}
		const key = document.uri.toString();
		const existing = this.timers.get(key);
		if (existing) {
			clearTimeout(existing);
		}
		const timer = setTimeout(() => {
			this.timers.delete(key);
			this.validate(document);
		}, delay);
		this.timers.set(key, timer);
	}

	validate(document: vscode.TextDocument): number {
		const enabled = vscode.workspace
			.getConfiguration("konado")
			.get<boolean>("diagnostics.enable", true);
		if (!enabled) {
			this.specs.delete(document.uri.toString());
			this.collection.delete(document.uri);
			return 0;
		}
		const specs = analyzeDocument(document.getText(), this.index);
		this.specs.set(document.uri.toString(), specs);
		this.collection.set(
			document.uri,
			specs.map((spec) => toDiagnostic(spec)),
		);
		return specs.length;
	}

	async validateOpenDocuments(): Promise<void> {
		for (const document of vscode.workspace.textDocuments) {
			if (document.languageId === "konadoscript") {
				this.validate(document);
			}
		}
	}

	async validateWorkspace(): Promise<void> {
		await this.index.rebuild();
		const uris = await vscode.workspace.findFiles(
			"**/*.ks",
			"**/{.git,.godot,node_modules,build,dist}/**",
		);
		let errors = 0;
		let warnings = 0;
		await vscode.window.withProgress(
			{
				location: vscode.ProgressLocation.Notification,
				title: text(
					"Validating KonadoScript files",
					"正在检查 KonadoScript 文件",
				),
			},
			async (progress) => {
				for (let index = 0; index < uris.length; index += 1) {
					const uri = uris[index];
					if (!uri) {
						continue;
					}
					const document =
						await vscode.workspace.openTextDocument(uri);
					const specs = analyzeDocument(
						document.getText(),
						this.index,
					);
					this.specs.set(uri.toString(), specs);
					this.collection.set(
						uri,
						specs.map((spec) => toDiagnostic(spec)),
					);
					errors += specs.filter(
						(spec) => spec.severity === "error",
					).length;
					warnings += specs.filter(
						(spec) => spec.severity === "warning",
					).length;
					progress.report({
						increment: 100 / Math.max(1, uris.length),
						message: `${index + 1}/${uris.length}`,
					});
				}
			},
		);
		void vscode.window.showInformationMessage(
			isChineseUi()
				? `KonadoScript 检查完成：${errors} 个错误，${warnings} 个警告。`
				: `KonadoScript validation completed: ${errors} errors, ${warnings} warnings.`,
		);
	}
}

function toDiagnostic(spec: DiagnosticSpec): vscode.Diagnostic {
	const diagnostic = new vscode.Diagnostic(
		new vscode.Range(spec.line, spec.start, spec.line, spec.end),
		isChineseUi() ? spec.messageZh : spec.message,
		spec.severity === "error"
			? vscode.DiagnosticSeverity.Error
			: vscode.DiagnosticSeverity.Warning,
	);
	diagnostic.source = "KonadoScript";
	diagnostic.code = spec.code;
	return diagnostic;
}
