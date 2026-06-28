/**
 * UI 工具
 * 统一 Toast 提示和 Loading 状态管理
 */

import { ref, readonly } from 'vue'

// ========== Toast ==========

interface ToastOptions {
  icon?: 'success' | 'error' | 'warning' | 'info' | 'question'
  title: string
  text?: string
  duration?: number
  position?: 'top' | 'top-end' | 'bottom'
}

/**
 * 非阻断式 Toast 提示（自动消失）
 * 封装 SweetAlert2 toast 模式
 */
export async function showToast(options: ToastOptions): Promise<void> {
  const Swal = (await import('sweetalert2')).default
  Swal.fire({
    toast: true,
    position: options.position || 'top',
    icon: options.icon || 'info',
    title: options.title,
    text: options.text,
    showConfirmButton: false,
    timer: options.duration || 2500,
    timerProgressBar: true,
  })
}

/**
 * 确认对话框
 */
export async function showConfirm(
  title: string,
  text?: string,
  confirmText = '确认',
  cancelText = '取消',
): Promise<boolean> {
  const Swal = (await import('sweetalert2')).default
  const result = await Swal.fire({
    title,
    text,
    icon: 'question',
    showCancelButton: true,
    confirmButtonText: confirmText,
    cancelButtonText: cancelText,
  })
  return result.isConfirmed
}

/**
 * 成功提示（快捷方法）
 */
export function toastSuccess(title: string): void {
  showToast({ icon: 'success', title, duration: 2000 })
}

/**
 * 错误提示（快捷方法）
 */
export function toastError(title: string): void {
  showToast({ icon: 'error', title, duration: 3000 })
}

/**
 * 警告提示（快捷方法）
 */
export function toastWarning(title: string): void {
  showToast({ icon: 'warning', title, duration: 3000 })
}

// ========== Loading ==========

/**
 * 响应式 loading 状态 composable
 * 用于组件级按钮 loading、页面加载等场景
 */
export function useLoading(initial = false) {
  const loading = ref(initial)

  function start() {
    loading.value = true
  }

  function stop() {
    loading.value = false
  }

  /**
   * 包装异步函数，自动管理 loading 状态
   */
  async function run<T>(fn: () => Promise<T>): Promise<T> {
    start()
    try {
      return await fn()
    } finally {
      stop()
    }
  }

  return {
    loading: readonly(loading),
    start,
    stop,
    run,
  }
}
