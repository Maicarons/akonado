export const DOC_VERSIONS = [
  {
    value: '2.4',
    labels: {
      zh: '2.4 LTS版',
      tc: '2.4 LTS版',
      en: '2.4 LTS',
      ja: '2.4 LTS版',
      ko: '2.4 LTS판',
    },
  },
  {
    value: '2.5',
    labels: {
      zh: '2.5最新版',
      tc: '2.5 最新版',
      en: '2.5 Latest',
      ja: '2.5最新版',
      ko: '2.5 최신판',
    },
  },
] as const

export const DEFAULT_DOC_VERSION = '2.4'

export const VERSION_SWITCHER_LABELS = {
  zh: '文档版本',
  tc: '文件版本',
  en: 'Documentation release',
  ja: 'ドキュメント版',
  ko: '문서 릴리스',
} as const
