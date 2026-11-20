import type {Metadata} from 'next';
import './globals.css';

export const metadata: Metadata = {title: 'NightShift staff', description: 'Restricted NightShift staff workspace', robots: {index: false, follow: false}};
export default function Layout({children}: Readonly<{children: React.ReactNode}>) {
  return <html lang="en"><body><a className="skip-link" href="#main">Skip to workspace</a>{children}</body></html>;
}
