import { mkdir, readdir, writeFile } from 'node:fs/promises'
import { dirname, join, relative, sep } from 'node:path'

const DOC_LOCALES = ['zh', 'tc', 'en', 'ja', 'ko'] as const
const LEGACY_VERSIONS = ['2.5', '2.6'] as const

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
}

function redirectDocument(target: string): string {
  const escapedTarget = escapeHtml(target)
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="robots" content="noindex">
    <meta http-equiv="refresh" content="0; url=${escapedTarget}">
    <link rel="canonical" href="${escapedTarget}">
    <title>Konado documentation moved</title>
    <script>window.location.replace(${JSON.stringify(target)} + window.location.search + window.location.hash)</script>
  </head>
  <body>
    <p>This documentation moved to <a href="${escapedTarget}">${escapedTarget}</a>.</p>
  </body>
</html>
`
}

async function collectHtmlFiles(root: string): Promise<string[]> {
  const files: string[] = []
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const path = join(root, entry.name)
    if (entry.isDirectory()) {
      files.push(...await collectHtmlFiles(path))
    } else if (entry.isFile() && entry.name.endsWith('.html')) {
      files.push(path)
    }
  }
  return files
}

function canonicalTarget(base: string, relativePath: string): string {
  const normalizedBase = `/${base.replace(/^\/+|\/+$/g, '')}/`
  const normalizedPath = relativePath.split(sep).join('/')
  const cleanPath = normalizedPath.endsWith('/index.html')
    ? normalizedPath.slice(0, -'index.html'.length)
    : normalizedPath
  return normalizedBase + cleanPath
}

export async function generateLegacyRedirects(
  outDir: string,
  base: string,
  currentVersion: string,
): Promise<void> {
  let redirectCount = 0
  for (const locale of DOC_LOCALES) {
    const currentRoot = join(outDir, locale, currentVersion)
    for (const currentFile of await collectHtmlFiles(currentRoot)) {
      const pagePath = relative(currentRoot, currentFile)
      const target = canonicalTarget(base, relative(outDir, currentFile))
      for (const legacyVersion of LEGACY_VERSIONS) {
        const redirectPath = join(outDir, locale, legacyVersion, pagePath)
        await mkdir(dirname(redirectPath), { recursive: true })
        await writeFile(redirectPath, redirectDocument(target), 'utf8')
        redirectCount += 1
      }
    }
  }
  console.info(`generated ${redirectCount} legacy documentation redirects`)
}
