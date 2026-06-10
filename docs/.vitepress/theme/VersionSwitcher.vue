<script setup lang="ts">
import { computed } from 'vue'
import { useData, useRoute, withBase } from 'vitepress'
import { DEFAULT_DOC_VERSION, DOC_VERSIONS, VERSION_SWITCHER_LABELS } from '../versions'

const versions = DOC_VERSIONS
type Locale = keyof typeof VERSION_SWITCHER_LABELS

const versionPattern = versions.map(({ value }) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|')
const versionRoutePattern = new RegExp(`^/(?:zh|tc|en|ja|ko)/(${versionPattern})(?:/|$)`)
const versionReplacePattern = new RegExp(`^(/(?:zh|tc|en|ja|ko)/)(?:${versionPattern})(?=/|$)`)

const route = useRoute()
const { site } = useData()

const normalizedPath = computed(() => {
  const base = site.value.base
  if (base !== '/' && route.path.startsWith(base)) {
    return '/' + route.path.slice(base.length)
  }
  return route.path
})

const currentVersion = computed(() => {
  const match = normalizedPath.value.match(versionRoutePattern)
  return match?.[1] ?? DEFAULT_DOC_VERSION
})

const currentLocale = computed<Locale>(() => {
  const match = normalizedPath.value.match(/^\/(zh|tc|en|ja|ko)(?:\/|$)/)
  return (match?.[1] as Locale | undefined) ?? 'zh'
})

const switcherLabel = computed(() => VERSION_SWITCHER_LABELS[currentLocale.value])

function versionLabel(version: (typeof versions)[number]): string {
  return version.labels[currentLocale.value] ?? version.labels.en
}

function targetPath(version: string): string {
  if (normalizedPath.value.match(versionRoutePattern)) {
    return normalizedPath.value.replace(versionReplacePattern, `$1${version}`)
  }

  const localeMatch = normalizedPath.value.match(/^\/(zh|tc|en|ja|ko)(?:\/|$)/)
  const locale = localeMatch?.[1] ?? 'zh'
  return `/${locale}/${version}/`
}

function switchVersion(event: Event) {
  const nextVersion = (event.target as HTMLSelectElement).value
  if (nextVersion === currentVersion.value) return
  window.location.href = withBase(targetPath(nextVersion))
}
</script>

<template>
  <div class="KonadoVersionSwitcher">
    <select
      :aria-label="switcherLabel"
      :value="currentVersion"
      @change="switchVersion"
    >
      <option v-for="version in versions" :key="version.value" :value="version.value">
        {{ versionLabel(version) }}
      </option>
    </select>
  </div>
</template>
