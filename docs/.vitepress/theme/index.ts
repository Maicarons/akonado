// https://vitepress.dev/guide/custom-theme
import { h } from 'vue'
import type { Theme } from 'vitepress'
import DefaultTheme from 'vitepress/theme'
import './style.css'
import VersionSwitcher from './VersionSwitcher.vue'

import '@theojs/lumen/style'
import { googleAnalytics } from '@theojs/lumen'

export default {
  extends: DefaultTheme,
  Layout: () => {
    return h(DefaultTheme.Layout, null, {
      // https://vitepress.dev/guide/extending-default-theme#layout-slots
      'nav-bar-content-after': () => h(VersionSwitcher),
      'nav-screen-content-after': () => h(VersionSwitcher),
    })
  },
  enhanceApp({ app, router, siteData }) {
    googleAnalytics({ id: 'G-DVCMR9LD73' }) 
  }
} satisfies Theme
