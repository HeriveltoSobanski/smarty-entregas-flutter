import { getToken, clearToken } from './auth'

const BASE = process.env.NEXT_PUBLIC_API_URL ?? ''

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const token = getToken()
  const res = await fetch(`${BASE}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init?.headers,
    },
  })
  if (res.status === 401) {
    clearToken()
    window.location.href = '/login'
    throw new Error('Não autorizado')
  }
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body.erro ?? `Erro ${res.status}`)
  }
  return res.json()
}

export type LoginResponse = { token: string; tipoUsuario: string }

export async function login(email: string, senha: string): Promise<LoginResponse> {
  return request<LoginResponse>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, senha }),
  })
}

export type Cupom = {
  id_cupom: number
  codigo: string
  tipo: 'percentual' | 'fixo'
  valor: number
  valor_minimo: number
  usos_maximos: number | null
  usos_atuais: number
  ativo: boolean
  valido_ate: string | null
  criado_em: string
}

export async function listCupons(): Promise<Cupom[]> {
  const data = await request<{ cupons: Cupom[] }>('/cupons')
  return data.cupons
}

export type CupomPayload = {
  codigo: string
  tipo: 'percentual' | 'fixo'
  valor: number
  valor_minimo?: number
  usos_maximos?: number
  valido_ate?: string
}

export async function createCupom(payload: CupomPayload): Promise<void> {
  await request('/cupons', { method: 'POST', body: JSON.stringify(payload) })
}

export async function toggleCupom(codigo: string): Promise<void> {
  await request(`/cupons/${codigo}/ativo`, { method: 'PATCH' })
}
