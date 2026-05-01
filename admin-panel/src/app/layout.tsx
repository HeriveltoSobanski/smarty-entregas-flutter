import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Smarty Admin',
  description: 'Painel administrativo Smarty Entregas',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body className="bg-gray-50 text-gray-900 antialiased">{children}</body>
    </html>
  )
}
