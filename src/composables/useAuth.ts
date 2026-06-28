/**
 * JWT 认证工具
 * 整合分散在 authStore + useApi 中的 Token 处理逻辑
 */

interface JwtPayload {
  id: number
  username: string
  role: 'user' | 'admin'
  iat: number
  exp: number
}

const TOKEN_KEY = 'token'
const ROLE_KEY = 'role'
const USER_KEY = 'user'
const MUST_CHANGE_PW_KEY = 'must_change_password'

// ========== Token 解析 ==========

/**
 * 解析 JWT Token 的 payload 部分（不验证签名，仅解码）
 */
export function parseToken(token: string): JwtPayload | null {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    // JWT 使用 base64url 编码，需转换为标准 base64 才能用 atob 解码
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/')
    const payload = JSON.parse(atob(base64))
    if (
      typeof payload.id !== 'number' ||
      typeof payload.exp !== 'number'
    ) {
      return null
    }
    return payload as JwtPayload
  } catch {
    return null
  }
}

/**
 * 检查 Token 是否已过期（基于 exp 字段）
 */
export function isTokenExpired(token: string): boolean {
  const payload = parseToken(token)
  if (!payload) return true // 无法解析视为过期
  // exp 是秒级时间戳，Date.now() 是毫秒
  return payload.exp * 1000 < Date.now()
}

/**
 * 获取 Token 剩余有效时间（毫秒），已过期返回 0
 */
export function tokenRemainingTime(token: string): number {
  const payload = parseToken(token)
  if (!payload) return 0
  const remaining = payload.exp * 1000 - Date.now()
  return Math.max(0, remaining)
}

// ========== localStorage 读写 ==========

export function getStoredToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function setStoredToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token)
}

export function removeStoredToken(): void {
  localStorage.removeItem(TOKEN_KEY)
}

export function getStoredRole(): 'user' | 'admin' | null {
  const role = localStorage.getItem(ROLE_KEY)
  if (role === 'user' || role === 'admin') return role
  return null
}

export function setStoredRole(role: 'user' | 'admin'): void {
  localStorage.setItem(ROLE_KEY, role)
}

export function getStoredUser(): Record<string, unknown> | null {
  try {
    const raw = localStorage.getItem(USER_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw)
    if (typeof parsed === 'object' && parsed) return parsed
  } catch { /* corrupted */ }
  return null
}

export function setStoredUser(user: Record<string, unknown>): void {
  localStorage.setItem(USER_KEY, JSON.stringify(user))
}

export function getMustChangePassword(): boolean {
  return localStorage.getItem(MUST_CHANGE_PW_KEY) === 'true'
}

export function setMustChangePassword(value: boolean): void {
  if (value) {
    localStorage.setItem(MUST_CHANGE_PW_KEY, 'true')
  } else {
    localStorage.removeItem(MUST_CHANGE_PW_KEY)
  }
}

/**
 * 清除所有认证相关的 localStorage 键
 */
export function clearAuthStorage(): void {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(ROLE_KEY)
  localStorage.removeItem(USER_KEY)
  localStorage.removeItem(MUST_CHANGE_PW_KEY)
}

/**
 * 校验当前存储的 Token 是否有效且未过期
 */
export function isAuthenticated(): boolean {
  const token = getStoredToken()
  if (!token) return false
  return !isTokenExpired(token)
}
