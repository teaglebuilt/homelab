import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';
import Heading from '@theme/Heading';

import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('', styles.heroBanner)}>
      <div className="container">
        <img src="img/homelab-icon.png" className={styles.heroImg}/>
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        {/* <p className="hero__subtitle">{siteConfig.tagline}</p> */}
        <div>
          <img src="https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white" />
          <img src="https://img.shields.io/badge/NVIDIA-GTX4070-76B900?style=for-the-badge&logo=nvidia&logoColor=white" />
          <img src="https://img.shields.io/badge/Intel%20Core_i9_10th-0071C5?style=for-the-badge&logo=intel&logoColor=white" />
          <img src="https://img.shields.io/badge/Argo%20CD-1e0b3e?style=for-the-badge&logo=argo&logoColor=#d16044" />
        </div>
      </div>
    </header>
    
  );
}

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`Hello from ${siteConfig.title}`}
      description="Description will go into a meta tag in <head />">
      <HomepageHeader />
      <main>
        {/* <HomepageFeatures /> */}
      </main>
    </Layout>
  );
}