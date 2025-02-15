import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  Svg: React.ComponentType<React.ComponentProps<'svg'>>;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'Automation',
    Svg: require('@site/static/svg/workflow.svg').default,
    description: (
      <>
        Workflow automation support with n8n
      </>
    ),
  },
  {
    title: 'Privacy',
    Svg: require('@site/static/svg/anon.svg').default,
    description: (
      <>
        Focus on network privacy, security, and lab sandboxes.
      </>
    ),
  },
  {
    title: 'Research',
    Svg: require('@site/static/svg/ollama.svg').default,
    description: (
      <>
        AI powered research with self hosted LLM's, agents, and research tools
      </>
    ),
  },
];

function Feature({title, Svg, description}: FeatureItem) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <Svg className={styles.featureSvg} role="img" />
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <h3>A platform for</h3>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
