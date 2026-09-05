export const DOC_VERSIONS = [
  {
    value: '2.4',
    labels: {
      zh: '2.4 LTS',
      tc: '2.4 LTS',
      en: '2.4 LTS',
      ja: '2.4 LTS',
      ko: '2.4 LTS',
    },
  },
  {
    value: 'latest',
    labels: {
      zh: '最新版',
      tc: '最新版',
      en: 'Latest',
      ja: '最新版',
      ko: '최신판',
    },
  },
] as const

export const DEFAULT_DOC_VERSION = 'latest'

export const VERSION_SWITCHER_LABELS = {
  zh: '文档版本',
  tc: '文件版本',
  en: 'Documentation release',
  ja: 'ドキュメント版',
  ko: '문서 릴리스',
} as const
