import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title:'TaskLy Admin | Command Center', description:'TaskLy Admin mock-data management dashboard' };
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="vi"><body>{children}</body></html>}
