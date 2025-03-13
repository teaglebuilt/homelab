import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'Built At Home',
  tagline: 'by dillan teagle',
  favicon: 'img/favicon.ico',
  url: 'https://teaglebuilt.github.io',
  baseUrl: '/homelab',
  organizationName: 'teaglebuilt',
  trailingSlash: false,
  projectName: 'homelab',
  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },
  presets: [
    [
      '@docusaurus/preset-classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          routeBasePath: '/',
        },
        blog: false
        // theme: {
        //   customCss: './src/css/custom.css',
        // },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // zoom: {
    //   selector: '.markdown :not(em) > img',
    //   background: {
    //     light: 'rgb(255, 255, 255)',
    //     dark: 'rgb(50, 50, 50)'
    //   },
    //   config: {
    //     // options you can specify via https://github.com/francoischalifour/medium-zoom#usage
    //   },
    // },
    image: 'img/homelab-icon.png',
    navbar: {
      title: 'Homelab',
      logo: {
        alt: '',
        src: 'logo.svg',
      },
      items: [
        {
          type: "docsVersionDropdown",
          position: "left",
          dropdownActiveClassDisabled: true,
          dropdownItemsAfter: [
            {
              type: "html",
              value: '<hr class="dropdown-separator">',
            },
            {
              to: "/versions",
              label: "All versions",
            },
          ],
        },
        {
          type: 'docSidebar',
          sidebarId: 'sidebar',
          label: 'Docs',
          position: 'left',
        },
        {
          href: 'https://github.com/teaglebuilt/homelab',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
