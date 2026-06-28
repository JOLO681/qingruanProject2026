/**
 * SSE 流式请求封装
 * 使用 fetch + ReadableStream（非 EventSource，因需要自定义 Authorization 头）
 * 通用化设计，不绑定具体业务（医师对话 / AI 助手 / 管理员对话均可复用）
 */

import { ref, readonly } from 'vue'
import { isTokenExpired, getStoredToken } from './useAuth'

/** SSE 事件回调（内联类型，匹配 Dify SSE 协议） */
interface SSECallbacks {
  onMessage?: (text: string, conversationId: string, messageId: string) => void
  onComplete?: (conversationId: string, messageId: string) => void
  onError?: (message: string, code: string) => void
}

interface SSEOptions {
  /** API 端点，如 /chat/doctor/123 */
  endpoint: string
  /** 请求体 */
  body: Record<string, unknown>
  /** SSE 事件回调 */
  callbacks?: SSECallbacks
  /** 请求超时，默认 30 秒 */
  timeout?: number
}

interface SSEResult {
  /** 是否正在连接/接收 */
  isConnecting: ReturnType<typeof readonly<ReturnType<typeof ref<boolean>>>>
  /** 最后一次错误信息 */
  error: ReturnType<typeof readonly<ReturnType<typeof ref<string | null>>>>
  /** 发起 SSE 连接 */
  connect: () => void
  /** 中断当前连接 */
  abort: () => void
}

/**
 * 通用 SSE 流式请求 composable
 *
 * @example
 * const { connect, abort, isConnecting } = useSSE({
 *   endpoint: '/chat/doctor/1',
 *   body: { message: '你好', conversation_id: 'xxx' },
 *   callbacks: {
 *     onMessage: (text, convId) => { ... },
 *     onComplete: (convId) => { ... },
 *     onError: (msg) => { ... },
 *   },
 * })
 */
export function useSSE(options: SSEOptions): SSEResult {
  const isConnecting = ref(false)
  const error = ref<string | null>(null)
  let abortController: AbortController | null = null

  function connect() {
    // 中断上一次连接
    abort()

    // 获取当前 Token 并校验
    const token = getStoredToken()
    if (!token) {
      error.value = '未登录'
      return
    }
    if (isTokenExpired(token)) {
      error.value = '登录已过期，请重新登录'
      return
    }

    isConnecting.value = true
    error.value = null
    abortController = new AbortController()

    const timeout = options.timeout || 30000
    const timeoutId = setTimeout(() => {
      abortController?.abort()
    }, timeout)

    fetch(`/api${options.endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(options.body),
      signal: abortController.signal,
    })
      .then(async (response) => {
        clearTimeout(timeoutId)

        if (!response.ok) {
          // 尝试从错误响应中提取消息
          let errorMsg = `请求失败 (${response.status})`
          try {
            const errBody = await response.json()
            if (errBody?.error?.message) errorMsg = errBody.error.message
          } catch { /* response is not JSON */ }

          // 401 由 useApi 拦截器统一处理，此处做 SSE 专属兜底
          if (response.status === 401) {
            errorMsg = '登录已过期，请重新登录'
          }

          error.value = errorMsg
          options.callbacks?.onError?.(errorMsg, `HTTP_${response.status}`)
          isConnecting.value = false
          return
        }

        const reader = response.body?.getReader()
        if (!reader) {
          error.value = '浏览器不支持流式读取'
          isConnecting.value = false
          return
        }

        const decoder = new TextDecoder()
        let buffer = ''

        function processSSELines(lines: string[]) {
          let eventType = ''
          let eventData = ''

          for (const line of lines) {
            if (line.startsWith('event: ')) {
              eventType = line.slice(7).trim()
            } else if (line.startsWith('data: ')) {
              eventData = line.slice(6)
            } else if (line === '') {
              // 空行表示一个 SSE 事件结束
              if (!eventData) continue

              try {
                const parsed = JSON.parse(eventData)

                if (eventType === 'error' || parsed.event === 'error') {
                  const msg = parsed.message || '服务暂时中断'
                  error.value = msg
                  options.callbacks?.onError?.(msg, parsed.code || 'SSE_ERROR')
                } else if (eventType === 'message_end' || parsed.event === 'message_end') {
                  options.callbacks?.onComplete?.(
                    parsed.conversation_id || '',
                    parsed.message_id || '',
                  )
                } else {
                  // 默认视为 message 事件（含流式文本增量）
                  const text = parsed.answer || ''
                  options.callbacks?.onMessage?.(
                    text,
                    parsed.conversation_id || '',
                    parsed.message_id || '',
                  )
                }
              } catch {
                // 非 JSON 数据，跳过
              }

              eventType = ''
              eventData = ''
            }
          }
        }

        // 递归读取流
        async function readStream(): Promise<void> {
          try {
            while (true) {
              const { done, value } = await reader!.read()
              if (done) {
                // 流结束，处理 buffer 中残留的数据
                if (buffer.trim()) {
                  processSSELines(buffer.split('\n'))
                }
                // 兜底：流自然结束但未收到 message_end 事件时，仍通知调用方
                options.callbacks?.onComplete?.('', '')
                isConnecting.value = false
                return
              }

              buffer += decoder.decode(value, { stream: true })
              // 按 \n\n 拆分成完整事件，至少保留最后一个不完整的事件
              const parts = buffer.split('\n\n')
              // 最后一段可能不完整，保留在 buffer
              buffer = parts.pop() || ''

              for (const part of parts) {
                if (part.trim()) {
                  processSSELines(part.split('\n'))
                }
              }
            }
          } catch (err: unknown) {
            if (err instanceof DOMException && err.name === 'AbortError') {
              // 用户主动取消，不算错误
            } else if (err instanceof TypeError) {
              error.value = '网络连接中断'
              options.callbacks?.onError?.('网络连接中断', 'NETWORK_ERROR')
            } else {
              error.value = '流读取异常'
              options.callbacks?.onError?.('流读取异常', 'STREAM_ERROR')
            }
            isConnecting.value = false
          }
        }

        readStream()
      })
      .catch((err: unknown) => {
        clearTimeout(timeoutId)
        if (err instanceof DOMException && err.name === 'AbortError') {
          // 用户取消或超时
        } else if (err instanceof TypeError) {
          error.value = '无法连接服务器'
          options.callbacks?.onError?.('无法连接服务器', 'NETWORK_ERROR')
        } else {
          error.value = '请求发送失败'
          options.callbacks?.onError?.('请求发送失败', 'REQUEST_ERROR')
        }
        isConnecting.value = false
      })
  }

  function abort() {
    if (abortController) {
      abortController.abort()
      abortController = null
    }
    isConnecting.value = false
  }

  return {
    isConnecting: readonly(isConnecting),
    error: readonly(error),
    connect,
    abort,
  }
}
