/**
 * 通用工具函数
 * 从各 View 中提取整合，避免重复实现
 */

// ========== 日期时间格式化 ==========

/**
 * 格式化 ISO 日期字符串为 YYYY-MM-DD
 * 原实现：Profile.vue formatDate()
 */
export function formatDate(iso: string): string {
  const d = new Date(iso)
  if (isNaN(d.getTime())) return ''
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

/**
 * 格式化 ISO 日期字符串为 YYYY-MM-DD HH:mm
 */
export function formatDateTime(iso: string): string {
  const d = new Date(iso)
  if (isNaN(d.getTime())) return ''
  return `${formatDate(iso)} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

/**
 * 格式化时间戳（秒）为相对时间描述
 */
export function formatRelativeTime(timestamp: number): string {
  const now = Date.now()
  const diff = now - timestamp * 1000
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)
  const days = Math.floor(diff / 86400000)

  if (minutes < 1) return '刚刚'
  if (minutes < 60) return `${minutes} 分钟前`
  if (hours < 24) return `${hours} 小时前`
  if (days < 7) return `${days} 天前`
  return formatDate(new Date(timestamp * 1000).toISOString())
}

// ========== 数值校验 ==========

/**
 * 校验数值是否在合法范围内
 * 原实现：Risk.vue isValidNumber()
 */
export function isValidNumber(val: unknown, min: number, max: number): boolean {
  if (val === null || val === undefined) return false
  if (typeof val !== 'number') return false
  if (!Number.isFinite(val)) return false
  return val >= min && val <= max
}

/**
 * 数值限幅
 */
export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max)
}

// ========== 防抖 & 节流 ==========

/**
 * 防抖 —— 延迟执行，期间重复调用则重置计时
 */
export function debounce<T extends (...args: unknown[]) => unknown>(
  fn: T,
  delay: number,
): (...args: Parameters<T>) => void {
  let timer: ReturnType<typeof setTimeout> | null = null
  return (...args: Parameters<T>) => {
    if (timer) clearTimeout(timer)
    timer = setTimeout(() => {
      fn(...args)
      timer = null
    }, delay)
  }
}

/**
 * 节流 —— 固定间隔内最多执行一次
 */
export function throttle<T extends (...args: unknown[]) => unknown>(
  fn: T,
  interval: number,
): (...args: Parameters<T>) => void {
  let lastTime = 0
  return (...args: Parameters<T>) => {
    const now = Date.now()
    if (now - lastTime >= interval) {
      lastTime = now
      fn(...args)
    }
  }
}

// ========== URL / 字符串 ==========

/**
 * 校验头像 URL 合法性（相对路径，非 // 开头）
 * 原实现：Profile.vue isValidAvatarUrl()
 */
export function isValidRelativeUrl(url: string): boolean {
  return url.startsWith('/') && !url.startsWith('//')
}

/**
 * 截断字符串，超出长度追加省略号
 */
export function truncate(str: string, maxLen: number): string {
  if (str.length <= maxLen) return str
  return str.slice(0, maxLen - 1) + '…'
}

/**
 * 首字母大写
 */
export function capitalize(str: string): string {
  if (!str) return ''
  return str.charAt(0).toUpperCase() + str.slice(1)
}

// ========== 数组 ==========

/**
 * 将数组按指定大小分块
 */
export function chunk<T>(arr: T[], size: number): T[][] {
  const result: T[][] = []
  for (let i = 0; i < arr.length; i += size) {
    result.push(arr.slice(i, i + size))
  }
  return result
}
