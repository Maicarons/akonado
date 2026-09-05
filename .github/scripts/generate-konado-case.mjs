/**
 * Refreshes the localized Made by Konado showcases in repository READMEs.
 */
import {
	access,
	mkdir,
	mkdtemp,
	readFile,
	rename,
	rm,
	writeFile,
} from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const API_URL =
	"https://godothub.com/api/public/works/feed?limit=200&category=game&classificationId=game_visual_novel&keyword=Konado%E8%A7%86%E8%A7%89%E5%B0%8F%E8%AF%B4%E5%88%9B%E6%84%8F%E5%91%A8&sortBy=default";
const WEBSITE_ORIGIN = "https://godothub.com";
const MEDIA_ORIGIN = "https://s1.godothub.com";
const MEDIA_PREFIX = "s/pb";
const WORK_MEDIA_COLLECTION = "pbc_works_0001";
const KONADO_TAG = "Konado视觉小说创意周";
const VISUAL_NOVEL_CLASSIFICATION = "game_visual_novel";
const BEGIN_MARKER = "<!-- BEGIN MADE BY KONADO -->";
const END_MARKER = "<!-- END MADE BY KONADO -->";
const SCRIPT_DIRECTORY = path.dirname(fileURLToPath(import.meta.url));
const REPOSITORY_ROOT = path.dirname(path.dirname(SCRIPT_DIRECTORY));
const GENERATED_ASSET_DIRECTORY = path.join(
	REPOSITORY_ROOT,
	"assets",
	"made-by-konado",
);
const MAX_EMBEDDED_IMAGE_BYTES = 1024 * 1024;
const THEMES = ["light", "dark"];
const LOCALES = [
	{
		directory: "en",
		readme: "README.md",
		licenseHeading: "## Open Source License",
		sectionHeading: "## Made by Konado",
		gameLabel: "Game",
		onlineLabel: "Play online",
		authorLabel: "Author",
		authorSeparator: ": ",
		heatLabel: "Heat",
		anonymous: "Anonymous",
		fallbackSummary: "A visual novel made with Konado",
		description(href) {
			return `> A showcase of Konado works from [GodotHub](${href}).`;
		},
	},
	{
		directory: "zh-CN",
		readme: "README.zh-CN.md",
		licenseHeading: "## 开源许可证",
		sectionHeading: "## 使用 Konado 制作",
		gameLabel: "游戏",
		onlineLabel: "在线运行",
		authorLabel: "作者",
		authorSeparator: "：",
		heatLabel: "热度",
		anonymous: "匿名用户",
		fallbackSummary: "使用 Konado 制作的视觉小说",
		description(href) {
			return `> 来自 [GodotHub](${href}) 的 Konado 作品展示。`;
		},
	},
	{
		directory: "zh-TW",
		readme: "README.zh-TW.md",
		licenseHeading: "## 開放原始碼授權條款",
		sectionHeading: "## 使用 Konado 製作",
		gameLabel: "遊戲",
		onlineLabel: "線上執行",
		authorLabel: "作者",
		authorSeparator: "：",
		heatLabel: "熱度",
		anonymous: "匿名使用者",
		fallbackSummary: "使用 Konado 製作的視覺小說",
		description(href) {
			return `> 來自 [GodotHub](${href}) 的 Konado 作品展示。`;
		},
	},
	{
		directory: "ja",
		readme: "README.ja.md",
		licenseHeading: "## オープンソースライセンス",
		sectionHeading: "## Konado で制作",
		gameLabel: "ゲーム",
		onlineLabel: "オンライン",
		authorLabel: "作者",
		authorSeparator: "：",
		heatLabel: "人気度",
		anonymous: "匿名ユーザー",
		fallbackSummary: "Konado で制作されたビジュアルノベル",
		description(href) {
			return `> [GodotHub](${href}) の Konado 制作作品です。`;
		},
	},
	{
		directory: "ko",
		readme: "README.ko.md",
		licenseHeading: "## 오픈 소스 라이선스",
		sectionHeading: "## Konado로 제작",
		gameLabel: "게임",
		onlineLabel: "온라인 실행",
		authorLabel: "제작자",
		authorSeparator: ": ",
		heatLabel: "인기도",
		anonymous: "익명 사용자",
		fallbackSummary: "Konado로 제작한 비주얼 노벨",
		description(href) {
			return `> [GodotHub](${href})의 Konado 제작 작품입니다.`;
		},
	},
];

function escapeHtml(value) {
	return String(value)
		.replaceAll("&", "&amp;")
		.replaceAll("<", "&lt;")
		.replaceAll(">", "&gt;")
		.replaceAll('"', "&quot;")
		.replaceAll("'", "&#39;");
}

function encodePathSegment(value) {
	return encodeURIComponent(String(value));
}

function getMediaUrl(work, filename) {
	const normalizedFilename = String(filename ?? "").trim();
	if (!normalizedFilename) return "";

	if (/^https:\/\//i.test(normalizedFilename)) {
		const absoluteUrl = new URL(normalizedFilename);
		if (absoluteUrl.origin !== MEDIA_ORIGIN) {
			throw new Error(`Untrusted work media origin: ${absoluteUrl.origin}`);
		}
		return absoluteUrl.href;
	}

	return [
		MEDIA_ORIGIN,
		MEDIA_PREFIX,
		WORK_MEDIA_COLLECTION,
		encodePathSegment(work.id),
		encodePathSegment(normalizedFilename),
	].join("/");
}

function getTagNames(work) {
	const expandedTags = work?.expand?.tags;
	if (!Array.isArray(expandedTags)) return [];

	return expandedTags
		.map((tag) => (typeof tag?.name === "string" ? tag.name.trim() : ""))
		.filter(Boolean);
}

function isKonadoVisualNovel(work) {
	return (
		work?.status === "approved" &&
		work?.category === "game" &&
		work?.distribution_mode === "online" &&
		Array.isArray(work?.classification_ids) &&
		work.classification_ids.includes(VISUAL_NOVEL_CLASSIFICATION) &&
		getTagNames(work).includes(KONADO_TAG)
	);
}

function normalizeWork(work) {
	const id = String(work?.id ?? "").trim();
	const title = String(work?.title ?? "").trim();
	if (!/^[a-zA-Z0-9_-]+$/.test(id) || !title) {
		throw new Error("GodotHub returned a work without a valid id or title");
	}

	const cardImage =
		work.icon_image || work.cover_image || work.screenshots?.[0] || "";
	if (!cardImage) {
		throw new Error(`GodotHub work "${id}" does not provide an image`);
	}
	const heat = Number(work.heat_score ?? work.view_count ?? 0);

	return {
		id,
		title,
		author: String(work.author_name ?? "").trim(),
		summary: String(
			work.short_description ?? work.description ?? "",
		).trim(),
		imageUrl: getMediaUrl(work, cardImage),
		heat: Number.isFinite(heat) ? Math.max(0, Math.round(heat)) : 0,
		workUrl: `${WEBSITE_ORIGIN}/asset/${encodeURIComponent(id)}`,
	};
}

async function fetchWithRetry(
	url,
	options,
	description,
	attempts = 3,
	retryDelayMs,
) {
	let lastError;

	for (let attempt = 1; attempt <= attempts; attempt += 1) {
		try {
			const response = await fetch(url, {
				...options,
				headers: {
					"User-Agent": "Konado-Docs-Showcase/1.0",
					...options?.headers,
				},
				signal: AbortSignal.timeout(20_000),
			});

			if (response.ok) return response;

			lastError = new Error(
				`${description} returned HTTP ${response.status} ${response.statusText}`,
			);
		} catch (error) {
			lastError = error;
		}

		if (attempt < attempts) {
			await new Promise((resolve) =>
				setTimeout(resolve, retryDelayMs ?? attempt * 750),
			);
		}
	}

	throw new Error(
		`${description} failed: ${lastError?.message ?? "unknown error"}`,
	);
}

async function fetchJson(url) {
	const response = await fetchWithRetry(
		url,
		{ headers: { Accept: "application/json" } },
		"GodotHub API request",
	);
	return response.json();
}

async function fetchAllWorks() {
	const works = [];
	const seenIds = new Set();
	let cursor = "";

	for (let page = 0; page < 20; page += 1) {
		const url = new URL(API_URL);
		if (cursor) url.searchParams.set("cursor", cursor);

		const payload = await fetchJson(url);
		if (!Array.isArray(payload?.items)) {
			throw new Error(
				"GodotHub API response does not contain an items array",
			);
		}

		for (const work of payload.items) {
			if (!isKonadoVisualNovel(work) || seenIds.has(work.id)) continue;
			seenIds.add(work.id);
			works.push(normalizeWork(work));
		}

		if (!payload.hasMore) return works;

		cursor = String(payload.nextCursor ?? "").trim();
		if (!cursor) {
			throw new Error(
				"GodotHub API indicated more data without a next cursor",
			);
		}
	}

	throw new Error("GodotHub API pagination exceeded the safety limit");
}

function getOptimizedImageUrl(sourceUrl, width, height, quality) {
	if (!sourceUrl) return "";

	const url = new URL(sourceUrl);
	if (url.origin === MEDIA_ORIGIN) {
		url.searchParams.set(
			"x-oss-process",
			`image/resize,m_fill,w_${width},h_${height}/format,webp/quality,q_${quality}`,
		);
	}
	return url.href;
}

async function fetchImageDataUrl(sourceUrl, width, height, quality) {
	if (!sourceUrl) return "";

	const optimizedUrl = getOptimizedImageUrl(
		sourceUrl,
		width,
		height,
		quality,
	);
	const response = await fetchWithRetry(
		optimizedUrl,
		{ headers: { Accept: "image/avif,image/webp,image/png,image/jpeg" } },
		"GodotHub media request",
		5,
		3_000,
	);
	const contentType = response.headers.get("content-type")?.split(";")[0];
	if (!contentType || !/^image\/(?:avif|webp|png|jpeg)$/.test(contentType)) {
		throw new Error(`Unsupported work image content type: ${contentType}`);
	}

	const image = Buffer.from(await response.arrayBuffer());
	if (image.byteLength > MAX_EMBEDDED_IMAGE_BYTES) {
		throw new Error(
			`Optimized work image exceeds ${MAX_EMBEDDED_IMAGE_BYTES} bytes`,
		);
	}

	return `data:${contentType};base64,${image.toString("base64")}`;
}

function hasExpectedImageSignature(contentType, image) {
	if (contentType === "image/png") {
		return image
			.subarray(0, 8)
			.equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
	}

	if (contentType === "image/jpeg") {
		return (
			image.length >= 3 &&
			image[0] === 0xff &&
			image[1] === 0xd8 &&
			image[2] === 0xff
		);
	}

	if (contentType === "image/webp") {
		return (
			image.subarray(0, 4).toString("ascii") === "RIFF" &&
			image.subarray(8, 12).toString("ascii") === "WEBP"
		);
	}

	if (contentType === "image/avif") {
		const brand = image.subarray(4, 12).toString("ascii");
		return brand === "ftypavif" || brand === "ftypavis";
	}

	return false;
}

function validateEmbeddedImageDataUrl(dataUrl) {
	const match =
		/^data:(image\/(?:avif|webp|png|jpeg));base64,([a-zA-Z0-9+/]+={0,2})$/.exec(
			dataUrl,
		);
	if (!match) return "";

	const [, contentType, encodedImage] = match;
	const image = Buffer.from(encodedImage, "base64");
	if (
		image.byteLength === 0 ||
		image.byteLength > MAX_EMBEDDED_IMAGE_BYTES ||
		!hasExpectedImageSignature(contentType, image)
	) {
		return "";
	}

	return dataUrl;
}

async function getPreviousEmbeddedIcon(workId) {
	for (const locale of LOCALES) {
		for (const theme of THEMES) {
			const cardPath = path.join(
				GENERATED_ASSET_DIRECTORY,
				locale.directory,
				theme,
				`${workId}.svg`,
			);
			let card;
			try {
				card = await readFile(cardPath, "utf8");
			} catch (error) {
				if (error?.code === "ENOENT") continue;
				throw error;
			}

			const iconMatch =
				/<image href="(data:image\/[^"]+)" x="20" y="20" width="80" height="80"/.exec(
					card,
				);
			const iconDataUrl = validateEmbeddedImageDataUrl(
				iconMatch?.[1] ?? "",
			);
			if (iconDataUrl) return iconDataUrl;
		}
	}

	return "";
}

function truncateText(value, maxUnits) {
	let units = 0;
	let result = "";

	for (const character of String(value)) {
		const characterUnits = /[\u0000-\u00ff]/.test(character) ? 1 : 2;
		if (units + characterUnits > maxUnits) return `${result}…`;
		result += character;
		units += characterUnits;
	}

	return result;
}

function getTextUnits(value) {
	return [...String(value)].reduce(
		(total, character) =>
			total + (/[\u0000-\u00ff]/.test(character) ? 1 : 2),
		0,
	);
}

function getBadgeWidth(label, minimumWidth) {
	return Math.min(120, Math.max(minimumWidth, getTextUnits(label) * 6 + 20));
}

function getCardStyles(theme) {
	if (theme === "dark") {
		return '.card-base{fill:#020617}.card-overlay{fill:url("#dark-overlay")}.card-border{fill:none;stroke:#263244}.panel{fill:#0f172a;fill-opacity:.9}.badge{fill:#10324a}.badge-text{fill:#75c7f5}.online-badge{fill:#172033}.online-text{fill:#b8c3d4}.title,.heat-text{fill:#f8fafc}.summary,.meta{fill:#9aa7ba}.heat-pill{fill:#111c2e;fill-opacity:.94}.icon-ring{fill:#111827;stroke:#fff;stroke-opacity:.14;stroke-width:2}';
	}

	return '.card-base{fill:#fff}.card-overlay{fill:url("#light-overlay")}.card-border{fill:none;stroke:#dbe3ec}.panel{fill:#f1f5f9;fill-opacity:.88}.badge{fill:#e5f2fa}.badge-text{fill:#2475a8}.online-badge{fill:#eef2f7}.online-text{fill:#475569}.title{fill:#0f172a}.summary,.meta{fill:#64748b}.heat-pill{fill:#f1f5f9;fill-opacity:.92}.heat-text{fill:#0f172a}.icon-ring{fill:#fff;stroke:#fff;stroke-width:2}';
}

function renderSvgCard(work, iconDataUrl, theme, locale) {
	const title = escapeHtml(truncateText(work.title, 48));
	const fullTitle = escapeHtml(work.title);
	const authorValue = work.author || locale.anonymous;
	const author = escapeHtml(truncateText(authorValue, 32));
	const summary = escapeHtml(
		truncateText(work.summary || locale.fallbackSummary, 74),
	);
	const gameLabel = escapeHtml(locale.gameLabel);
	const onlineLabel = escapeHtml(locale.onlineLabel);
	const authorLabel = escapeHtml(locale.authorLabel);
	const gameBadgeWidth = getBadgeWidth(locale.gameLabel, 52);
	const onlineBadgeWidth = getBadgeWidth(locale.onlineLabel, 64);
	const onlineBadgeX = 116 + gameBadgeWidth + 8;
	const icon = `<image href="${iconDataUrl}" x="20" y="20" width="80" height="80" preserveAspectRatio="xMidYMid slice" clip-path="url(#icon-clip)"/>`;

	return [
		'<svg xmlns="http://www.w3.org/2000/svg" width="592" height="204" viewBox="0 0 592 204" role="img" aria-labelledby="card-title card-description">',
		`<title id="card-title">${fullTitle}</title>`,
		`<desc id="card-description">${authorLabel}${escapeHtml(locale.authorSeparator)}${escapeHtml(authorValue)} · ${escapeHtml(locale.heatLabel)}${escapeHtml(locale.authorSeparator)}${work.heat}</desc>`,
		"<defs>",
		'<clipPath id="card-clip"><rect width="592" height="204" rx="28"/></clipPath>',
		'<clipPath id="icon-clip"><rect x="20" y="20" width="80" height="80" rx="16"/></clipPath>',
		'<filter id="icon-shadow" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="5" stdDeviation="7" flood-color="#0f172a" flood-opacity=".16"/></filter>',
		'<linearGradient id="light-overlay" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity=".76"/><stop offset=".54" stop-color="#ffffff" stop-opacity=".9"/><stop offset="1" stop-color="#f8fafc" stop-opacity=".98"/></linearGradient>',
		'<linearGradient id="dark-overlay" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0f172a" stop-opacity=".76"/><stop offset=".54" stop-color="#020617" stop-opacity=".9"/><stop offset="1" stop-color="#020617" stop-opacity=".98"/></linearGradient>',
		"<style>",
		getCardStyles(theme),
		"</style>",
		"</defs>",
		'<g clip-path="url(#card-clip)">',
		'<rect width="592" height="204" class="card-base"/>',
		'<rect width="592" height="204" class="card-overlay"/>',
		"</g>",
		'<rect x=".5" y=".5" width="591" height="203" rx="27.5" class="card-border"/>',
		'<g filter="url(#icon-shadow)"><rect x="20" y="20" width="80" height="80" rx="16" class="icon-ring"/></g>',
		icon,
		`<rect x="116" y="22" width="${gameBadgeWidth}" height="25" rx="12.5" class="badge"/>`,
		`<text x="${116 + gameBadgeWidth / 2}" y="39" text-anchor="middle" class="badge-text" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Noto Sans SC,sans-serif" font-size="12" font-weight="600">${gameLabel}</text>`,
		`<rect x="${onlineBadgeX}" y="22" width="${onlineBadgeWidth}" height="25" rx="12.5" class="online-badge"/>`,
		`<text x="${onlineBadgeX + onlineBadgeWidth / 2}" y="39" text-anchor="middle" class="online-text" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Noto Sans SC,sans-serif" font-size="12" font-weight="600">${onlineLabel}</text>`,
		`<text x="118" y="87" class="meta" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Noto Sans SC,sans-serif" font-size="14">${authorLabel}${escapeHtml(locale.authorSeparator)}${author}</text>`,
		'<rect x="484" y="68" width="88" height="30" rx="15" class="heat-pill"/>',
		'<path d="M502 90c-4 0-7-2.8-7-6.7 0-2.7 1.4-5.2 4.1-7.6-.1 2.5 1.2 3.8 2.6 4.8-.2-3.4 1.8-6.2 4.3-8.5 0 3.7 3 5.3 3 9.7 0 4.7-3 8.3-7 8.3Z" fill="#f97316"/>',
		`<text x="515" y="88" class="heat-text" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Noto Sans SC,sans-serif" font-size="14" font-weight="600">${work.heat}</text>`,
		'<rect x="20" y="116" width="552" height="68" rx="16" class="panel"/>',
		`<text x="36" y="143" class="title" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Noto Sans SC,sans-serif" font-size="20" font-weight="700">${title}</text>`,
		`<text x="36" y="169" class="summary" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Noto Sans SC,sans-serif" font-size="13">${summary}</text>`,
		"</svg>",
	].join("\n");
}

async function createCardAssets(work) {
	let iconDataUrl;
	let iconSource = "fresh";
	try {
		iconDataUrl = await fetchImageDataUrl(work.imageUrl, 160, 160, 82);
	} catch (error) {
		iconDataUrl = await getPreviousEmbeddedIcon(work.id);
		if (!iconDataUrl) {
			console.warn(
				`Skipping new work "${work.title}" after five icon download attempts: ${error.message}`,
			);
			return { cards: [], iconSource: "skipped", work };
		}

		iconSource = "cached";
		console.warn(
			`Reusing the previous embedded icon for "${work.title}" after five download attempts: ${error.message}`,
		);
	}

	return {
		cards: LOCALES.flatMap((locale) =>
			THEMES.map((theme) => ({
				filename: path.join(locale.directory, theme, `${work.id}.svg`),
				content: renderSvgCard(work, iconDataUrl, theme, locale),
			})),
		),
		iconSource,
		work,
	};
}

async function replaceGeneratedAssets(cards) {
	const assetsParent = path.dirname(GENERATED_ASSET_DIRECTORY);
	await mkdir(assetsParent, { recursive: true });
	const temporaryDirectory = await mkdtemp(
		path.join(assetsParent, ".made-by-konado-"),
	);

	try {
		await Promise.all([
			writeFile(path.join(temporaryDirectory, ".gdignore"), "", "utf8"),
			...LOCALES.flatMap((locale) =>
				THEMES.map((theme) =>
					mkdir(path.join(temporaryDirectory, locale.directory, theme), {
						recursive: true,
					}),
				),
			),
		]);
		await Promise.all(
			cards.map((card) =>
				writeFile(
					path.join(temporaryDirectory, card.filename),
					card.content,
					"utf8",
				),
			),
		);

		await rm(GENERATED_ASSET_DIRECTORY, { recursive: true, force: true });
		await rename(temporaryDirectory, GENERATED_ASSET_DIRECTORY);
	} catch (error) {
		await rm(temporaryDirectory, { recursive: true, force: true });
		throw error;
	}
}

function renderSection(works, locale) {
	if (works.length === 0) {
		throw new Error(
			"GodotHub returned no approved online works tagged for Konado",
		);
	}

	const rows = [];
	for (let index = 0; index < works.length; index += 2) {
		const cards = works.slice(index, index + 2).map((work) => {
			const title = escapeHtml(work.title);
			const author = escapeHtml(work.author || locale.anonymous);
			const workUrl = escapeHtml(work.workUrl);
			const lightAsset = `./assets/made-by-konado/${locale.directory}/light/${work.id}.svg`;
			const darkAsset = `./assets/made-by-konado/${locale.directory}/dark/${work.id}.svg`;
			const alt = `${title} — ${escapeHtml(locale.authorLabel)}${escapeHtml(locale.authorSeparator)}${author} · ${escapeHtml(locale.heatLabel)}${escapeHtml(locale.authorSeparator)}${work.heat}`;
			return [
				`<a href="${workUrl}"><picture>`,
				`<source media="(max-width: 767px) and (prefers-color-scheme: dark)" srcset="${darkAsset}" width="1200">`,
				`<source media="(max-width: 767px)" srcset="${lightAsset}" width="1200">`,
				`<source media="(prefers-color-scheme: dark)" srcset="${darkAsset}">`,
				`<img src="${lightAsset}" alt="${alt}" width="46.5%">`,
				"</picture></a>",
			].join("");
		});
		rows.push(`<p align="center">\n${cards.join("&emsp;")}\n</p>`);
	}

	return [
		BEGIN_MARKER,
		locale.sectionHeading,
		"",
		locale.description(
			`${WEBSITE_ORIGIN}/game/visual-novel`,
		),
		"",
		rows.join("\n"),
		END_MARKER,
	].join("\n");
}

function replaceGeneratedSection(readme, section, licenseHeading) {
	const beginIndex = readme.indexOf(BEGIN_MARKER);
	const endIndex = readme.indexOf(END_MARKER);

	if ((beginIndex === -1) !== (endIndex === -1)) {
		throw new Error("README contains only one Made by Konado marker");
	}

	if (beginIndex !== -1) {
		if (endIndex < beginIndex) {
			throw new Error("README Made by Konado markers are out of order");
		}

		const afterEnd = endIndex + END_MARKER.length;
		const remainder = readme.slice(afterEnd).replace(/^[\t \r\n]*/, "");
		return `${readme.slice(0, beginIndex)}${section}\n\n\n${remainder}`;
	}

	const licenseIndex = readme.indexOf(licenseHeading);
	if (licenseIndex === -1) {
		throw new Error(`README is missing the "${licenseHeading}" heading`);
	}

	return `${readme.slice(0, licenseIndex)}${section}\n\n\n${readme.slice(licenseIndex)}`;
}

async function writeReadme(readmePath, readme) {
	const temporaryPath = `${readmePath}.tmp-${process.pid}`;
	await writeFile(temporaryPath, readme, "utf8");
	await rename(temporaryPath, readmePath);
}

async function main() {
	const [readmes, works] = await Promise.all([
		Promise.all(
			LOCALES.map(async (locale) => {
				const readmePath = path.join(REPOSITORY_ROOT, locale.readme);
				return {
					locale,
					readmePath,
					content: await readFile(readmePath, "utf8"),
				};
			}),
		),
		fetchAllWorks(),
	]);
	if (works.length === 0) {
		console.warn(
			"GodotHub returned no approved Konado works; keeping the previous showcase unchanged",
		);
		return;
	}

	const cardResults = await Promise.all(works.map(createCardAssets));
	const includedResults = cardResults.filter(
		(result) => result.iconSource !== "skipped",
	);
	if (includedResults.length === 0) {
		console.warn(
			"No work icon was available; keeping the previous showcase unchanged",
		);
		return;
	}

	const includedWorks = includedResults.map((result) => result.work);
	const cards = includedResults.flatMap((result) => result.cards);
	const nextReadmes = readmes.map(({ locale, readmePath, content }) => ({
		readmePath,
		content: replaceGeneratedSection(
			content,
			renderSection(includedWorks, locale),
			locale.licenseHeading,
		),
	}));

	await replaceGeneratedAssets(cards);
	await Promise.all(
		nextReadmes.map(({ readmePath, content }) =>
			writeReadme(readmePath, content),
		),
	);
	await access(GENERATED_ASSET_DIRECTORY);

	console.log(
		[
			`Updated ${readmes.length} README files with ${includedWorks.length} Konado work cards each`,
			`(${cardResults.filter((result) => result.iconSource === "fresh").length} fresh icons,`,
			`${cardResults.filter((result) => result.iconSource === "cached").length} cached icons,`,
			`${cardResults.filter((result) => result.iconSource === "skipped").length} skipped works)`,
		].join(" "),
	);
}

await main();
