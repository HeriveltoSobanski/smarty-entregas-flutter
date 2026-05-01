'use client'

import { useEffect, useState, FormEvent } from 'react'
import { listCupons, createCupom, toggleCupom, type Cupom, type CupomPayload } from '@/lib/api'

const EMPTY: CupomPayload = {
  codigo: '',
  tipo: 'percentual',
  valor: 0,
  valor_minimo: 0,
  usos_maximos: undefined,
  valido_ate: '',
}

function formatDate(iso: string | null) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('pt-BR')
}

export default function CuponsPage() {
  const [cupons, setCupons] = useState<Cupom[]>([])
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState<CupomPayload>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [formErro, setFormErro] = useState('')
  const [toggling, setToggling] = useState<string | null>(null)

  async function load() {
    setLoading(true)
    setErro('')
    try {
      setCupons(await listCupons())
    } catch (e) {
      setErro(e instanceof Error ? e.message : 'Erro ao carregar cupons')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  async function handleCreate(e: FormEvent) {
    e.preventDefault()
    setFormErro('')
    setSaving(true)
    try {
      const payload: CupomPayload = {
        codigo: form.codigo.trim().toUpperCase(),
        tipo: form.tipo,
        valor: Number(form.valor),
        ...(form.valor_minimo ? { valor_minimo: Number(form.valor_minimo) } : {}),
        ...(form.usos_maximos ? { usos_maximos: Number(form.usos_maximos) } : {}),
        ...(form.valido_ate ? { valido_ate: form.valido_ate } : {}),
      }
      await createCupom(payload)
      setForm(EMPTY)
      setShowForm(false)
      await load()
    } catch (e) {
      setFormErro(e instanceof Error ? e.message : 'Erro ao criar cupom')
    } finally {
      setSaving(false)
    }
  }

  async function handleToggle(codigo: string) {
    setToggling(codigo)
    try {
      await toggleCupom(codigo)
      setCupons((prev) =>
        prev.map((c) => (c.codigo === codigo ? { ...c, ativo: !c.ativo } : c))
      )
    } catch (e) {
      setErro(e instanceof Error ? e.message : 'Erro ao alterar cupom')
    } finally {
      setToggling(null)
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Cupons</h1>
          <p className="text-sm text-gray-500 mt-1">{cupons.length} cupom(s) cadastrado(s)</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors"
        >
          {showForm ? 'Cancelar' : '+ Novo cupom'}
        </button>
      </div>

      {/* Form */}
      {showForm && (
        <div className="bg-white border border-gray-200 rounded-xl p-6 mb-6">
          <h2 className="font-semibold text-gray-900 mb-4">Novo cupom</h2>
          <form onSubmit={handleCreate} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Código *</label>
              <input
                required
                value={form.codigo}
                onChange={(e) => setForm({ ...form, codigo: e.target.value })}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm uppercase focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="DESCONTO10"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Tipo *</label>
              <select
                value={form.tipo}
                onChange={(e) => setForm({ ...form, tipo: e.target.value as 'percentual' | 'fixo' })}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="percentual">Percentual (%)</option>
                <option value="fixo">Fixo (R$)</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Valor * {form.tipo === 'percentual' ? '(%)' : '(R$)'}
              </label>
              <input
                required
                type="number"
                min="0.01"
                step="0.01"
                value={form.valor || ''}
                onChange={(e) => setForm({ ...form, valor: parseFloat(e.target.value) })}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="10"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Pedido mínimo (R$)</label>
              <input
                type="number"
                min="0"
                step="0.01"
                value={form.valor_minimo || ''}
                onChange={(e) => setForm({ ...form, valor_minimo: parseFloat(e.target.value) })}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="0"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Usos máximos</label>
              <input
                type="number"
                min="1"
                value={form.usos_maximos || ''}
                onChange={(e) => setForm({ ...form, usos_maximos: parseInt(e.target.value) })}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Ilimitado"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Válido até</label>
              <input
                type="date"
                value={form.valido_ate || ''}
                onChange={(e) => setForm({ ...form, valido_ate: e.target.value })}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            {formErro && (
              <div className="sm:col-span-2">
                <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
                  {formErro}
                </p>
              </div>
            )}

            <div className="sm:col-span-2">
              <button
                type="submit"
                disabled={saving}
                className="bg-blue-600 text-white px-6 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50 transition-colors"
              >
                {saving ? 'Salvando...' : 'Criar cupom'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Error */}
      {erro && (
        <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2 mb-4">
          {erro}
        </p>
      )}

      {/* Table */}
      <div className="bg-white border border-gray-200 rounded-xl overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-sm text-gray-400">Carregando...</div>
        ) : cupons.length === 0 ? (
          <div className="p-8 text-center text-sm text-gray-400">Nenhum cupom cadastrado.</div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-200 bg-gray-50">
                <th className="text-left px-4 py-3 font-medium text-gray-600">Código</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Tipo</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Valor</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Mínimo</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Usos</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Validade</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Status</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {cupons.map((c) => (
                <tr key={c.id_cupom} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-mono font-semibold text-gray-900">{c.codigo}</td>
                  <td className="px-4 py-3 text-gray-600 capitalize">{c.tipo}</td>
                  <td className="px-4 py-3 text-gray-900">
                    {c.tipo === 'percentual' ? `${c.valor}%` : `R$ ${Number(c.valor).toFixed(2)}`}
                  </td>
                  <td className="px-4 py-3 text-gray-600">
                    {c.valor_minimo > 0 ? `R$ ${Number(c.valor_minimo).toFixed(2)}` : '—'}
                  </td>
                  <td className="px-4 py-3 text-gray-600">
                    {c.usos_atuais}/{c.usos_maximos ?? '∞'}
                  </td>
                  <td className="px-4 py-3 text-gray-600">{formatDate(c.valido_ate)}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                        c.ativo
                          ? 'bg-green-100 text-green-700'
                          : 'bg-gray-100 text-gray-500'
                      }`}
                    >
                      {c.ativo ? 'Ativo' : 'Inativo'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      onClick={() => handleToggle(c.codigo)}
                      disabled={toggling === c.codigo}
                      className="text-xs text-blue-600 hover:text-blue-800 disabled:opacity-50"
                    >
                      {toggling === c.codigo ? '...' : c.ativo ? 'Desativar' : 'Ativar'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
