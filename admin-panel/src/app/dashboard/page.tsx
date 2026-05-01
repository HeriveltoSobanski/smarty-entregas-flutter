export default function DashboardPage() {
  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900 mb-2">Visão geral</h1>
      <p className="text-gray-500 text-sm">Bem-vindo ao painel administrativo Smarty Entregas.</p>

      <div className="mt-8 grid grid-cols-1 sm:grid-cols-2 gap-4">
        <a
          href="/dashboard/cupons"
          className="bg-white border border-gray-200 rounded-xl p-6 hover:border-blue-300 transition-colors group"
        >
          <h2 className="font-semibold text-gray-900 group-hover:text-blue-700">Cupons</h2>
          <p className="text-sm text-gray-500 mt-1">Criar e gerenciar cupons de desconto</p>
        </a>
      </div>
    </div>
  )
}
