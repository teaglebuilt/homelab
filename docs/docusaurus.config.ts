import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'Built At Home',
  tagline: 'by dillan teagle',
  favicon: 'img/favicon.ico',

  // Set the production url of your site here
  url: 'https://your-docusaurus-site.example.com',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',
  organizationName: 'teaglebuilt',
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
