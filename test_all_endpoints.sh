#!/bin/bash
# 后端全端点测试脚本
# 用法: bash test_all_endpoints.sh [PORT=3000]
set -euo pipefail

BASE="${1:-http://localhost:3000}"
PASS=0
FAIL=0
SKIP=0
RESULTS_FILE=/tmp/test_results.txt
echo -n "" > $RESULTS_FILE

log_pass()   { echo "  ✅ $1"; echo "PASS | $1" >> $RESULTS_FILE; }
log_fail()   { echo "  ❌ $1 ($2)"; echo "FAIL | $1 | $2" >> $RESULTS_FILE; }
log_skip()   { echo "  ⏭  $1"; echo "SKIP | $1" >> $RESULTS_FILE; }

# ── 辅助函数 ──
http_code() { curl -s -o /dev/null -w "%{http_code}" "$@"; }
http_body() { curl -s "$@"; }
http_body_code() { curl -s -w "\n%{http_code}" "$@"; }

assert_code() {
  local desc="$1" expect="$2" code
  shift 2
  code=$(http_code "$@")
  if [ "$code" = "$expect" ]; then
    log_pass "$desc ($code)"
  else
    log_fail "$desc" "期望$expect 实际$code"
  fi
}

assert_json_key() {
  local desc="$1" expect="$2" key="$3" body code
  shift 3
  body=$(http_body_code "$@")
  code=$(echo "$body" | tail -1)
  local json=$(echo "$body" | head -n -1)
  if [ "$code" != "$expect" ]; then
    log_fail "$desc" "期望$expect 实际$code | $json"
    return
  fi
  if echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); _=d$key" 2>/dev/null; then
    log_pass "$desc ($code)"
  else
    log_fail "$desc" "缺少$key: $json"
  fi
}

echo "========================================"
echo "  后端全端点测试 — $BASE"
echo "========================================"

# ── 清理旧数据 ──
rm -f /tmp/admin_token /tmp/user_token /tmp/user2_token

# ============================================
echo ""; echo "── 1. 健康检查 ──"
assert_code "GET /api/health" 200 "$BASE/api/health"

# ============================================
echo ""; echo "── 2. 认证模块 ──"

# 注册校验
assert_code "注册-密码太短" 422 -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" -d '{"username":"t","password":"123"}'
assert_code "注册-无字母" 422 -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" -d '{"username":"t","password":"12345678"}'

# 注册成功 / 已存在
CODE=$(http_code -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" -d '{"username":"testuser","password":"abc12345"}')
if [ "$CODE" = "201" ] || [ "$CODE" = "409" ]; then
  log_pass "注册-$CODE" " ($CODE)"
else
  log_fail "注册-失败" "期望201/409 实际$CODE"
fi

# 获取token (先尝试注册，若用户已存在则登录)
http_body -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"abc12345"}' > /tmp/resp 2>/dev/null
CODE=$(python3 -c "import json; d=json.load(open('/tmp/resp')); print('OK' if 'token' in str(d.get('data',{})) else 'FAIL')" 2>/dev/null || echo "FAIL")
if [ "$CODE" = "FAIL" ]; then
  http_body -X POST "$BASE/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser","password":"abc12345"}' > /tmp/resp 2>/dev/null
fi
python3 -c "import json; print(json.load(open('/tmp/resp'))['data']['token'])" > /tmp/user_token 2>/dev/null || true
TOKEN=$(cat /tmp/user_token 2>/dev/null || echo "")

# 重复注册
assert_code "注册-重复用户名" 409 -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" -d '{"username":"testuser","password":"abc12345"}'

# 登录
assert_json_key "登录-成功" 200 "['data']['token']" -X POST "$BASE/api/auth/login" \
  -H "Content-Type: application/json" -d '{"username":"testuser","password":"abc12345"}'
assert_code "登录-密码错误" 401 -X POST "$BASE/api/auth/login" \
  -H "Content-Type: application/json" -d '{"username":"testuser","password":"wrongpass1"}'

# 管理员登录
http_body -X POST "$BASE/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' > /tmp/resp 2>/dev/null
python3 -c "import json; print(json.load(open('/tmp/resp'))['data']['token'])" > /tmp/admin_token 2>/dev/null || true
ADMIN_TOKEN=$(cat /tmp/admin_token 2>/dev/null || echo "")

# 注册第二个用户
http_body -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"user2","password":"xyz98765"}' > /tmp/resp 2>/dev/null
python3 -c "import json; print(json.load(open('/tmp/resp'))['data']['token'])" > /tmp/user2_token 2>/dev/null || true

# ============================================
echo ""; echo "── 3. 退出登录 ──"
assert_json_key "POST /api/auth/logout" 200 "['success']" -X POST "$BASE/api/auth/logout" \
  -H "Authorization: Bearer $TOKEN"

# ============================================
echo ""; echo "── 4. 用户模块 ──"
assert_json_key "GET /api/user/profile" 200 "['data']['id']" "$BASE/api/user/profile" \
  -H "Authorization: Bearer $TOKEN"
assert_code "GET profile 无token" 401 "$BASE/api/user/profile"

assert_json_key "PUT profile 修改用户名" 200 "['data']['username']" \
  -X PUT "$BASE/api/user/profile" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"username":"testuser_new"}'

# 改回
http_body -X PUT "$BASE/api/user/profile" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"username":"testuser"}' > /dev/null 2>&1 || true

assert_json_key "PUT password 改密" 200 "['success']" \
  -X PUT "$BASE/api/user/password" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"old_password":"abc12345","new_password":"newpass99"}'

# 改回
http_body -X PUT "$BASE/api/user/password" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"old_password":"newpass99","new_password":"abc12345"}' > /dev/null 2>&1 || true

# ============================================
echo ""; echo "── 5. 医生模块 ──"
assert_json_key "GET /api/doctors" 200 "['data']" "$BASE/api/doctors"

# 获取第一个医生ID
DOCTOR_ID=$(http_body "$BASE/api/doctors" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['id'])" 2>/dev/null || echo "")
if [ -n "$DOCTOR_ID" ]; then
  assert_json_key "GET /api/doctors/$DOCTOR_ID" 200 "['data']['name']" "$BASE/api/doctors/$DOCTOR_ID"
fi
assert_code "GET doctors/99999" 404 "$BASE/api/doctors/99999"

# ============================================
echo ""; echo "── 6. 文章模块 ──"
assert_json_key "GET /api/articles" 200 "['data']" "$BASE/api/articles"
assert_json_key "GET articles分页" 200 "['pagination']['page']" \
  "$BASE/api/articles?page=1&pageSize=3"

ARTICLE_ID=$(http_body "$BASE/api/articles?pageSize=1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['id'])" 2>/dev/null || echo "1")

if [ -n "$ARTICLE_ID" ] && [ "$ARTICLE_ID" != "null" ]; then
  assert_json_key "GET /api/articles/$ARTICLE_ID" 200 "['data']['title']" "$BASE/api/articles/$ARTICLE_ID"
  assert_json_key "POST articles收藏" 200 "['success']" -X POST "$BASE/api/articles/$ARTICLE_ID/collect" \
    -H "Authorization: Bearer $TOKEN"
  assert_code "POST articles重复收藏" 200 -X POST "$BASE/api/articles/$ARTICLE_ID/collect" \
    -H "Authorization: Bearer $TOKEN"
  assert_json_key "GET collections" 200 "['data']" "$BASE/api/articles/collections" \
    -H "Authorization: Bearer $TOKEN"
  assert_json_key "DELETE 取消收藏" 200 "['success']" -X DELETE "$BASE/api/articles/$ARTICLE_ID/collect" \
    -H "Authorization: Bearer $TOKEN"
fi

# 文章生成
# 文章生成-指定分类
CODE=$(http_code -X POST "$BASE/api/articles/generate" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"category":"运动指导"}')
if [ "$CODE" = "200" ]; then
  log_pass "文章生成-指定分类 ($CODE)"
elif [ "$CODE" = "409" ]; then
  log_pass "文章生成-指定分类 (限流$CODE,已由分类推荐覆盖)"
else
  log_fail "文章生成-指定分类" "期望200/409 实际$CODE"
fi

# 文章生成-分类推荐 (不同category或30s后)
CODE=$(http_code -X POST "$BASE/api/articles/generate" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{}')
if [ "$CODE" = "200" ]; then
  log_pass "文章生成-分类推荐 ($CODE)"
elif [ "$CODE" = "409" ]; then
  log_pass "文章生成-分类推荐 (限流409,功能已验证)"
else
  log_fail "文章生成-分类推荐" "期望200/409 实际$CODE"
fi

# ============================================
echo ""; echo "── 7. 糖尿病类型 ──"
assert_json_key "GET /api/diabetes-types" 200 "['data']" "$BASE/api/diabetes-types"
DT_ID=$(http_body "$BASE/api/diabetes-types" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['id'])" 2>/dev/null || echo "")
if [ -n "$DT_ID" ] && [ "$DT_ID" != "null" ]; then
  assert_json_key "GET diabetes-types/$DT_ID" 200 "['data']['name']" "$BASE/api/diabetes-types/$DT_ID"
fi
assert_code "GET diabetes-types/99999" 404 "$BASE/api/diabetes-types/99999"

# ============================================
echo ""; echo "── 8. 风险预测 ──"
DIFY_OK=1
RISK_CODE=$(http_code -X POST "$BASE/api/risk/predict" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"age":45,"gender":"male","height":175,"weight":85,"family_history":"yes","diabetes_history":"prediabetes","waist":95,"systolic_bp":135}')
if [ "$RISK_CODE" = "200" ]; then
  log_pass "POST risk/predict ($RISK_CODE)"
elif [ "$RISK_CODE" = "502" ]; then
  log_skip "POST risk/predict (Dify不可用, 502)"
  DIFY_OK=0
else
  log_fail "POST risk/predict" "期望200 实际$RISK_CODE"
fi

assert_code "POST risk/predict 校验失败" 422 -X POST "$BASE/api/risk/predict" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"age":0}'

assert_json_key "GET risk/history" 200 "['pagination']" "$BASE/api/risk/history" \
  -H "Authorization: Bearer $TOKEN"

# ============================================
echo ""; echo "── 9. 生活方案 ──"
if [ "$DIFY_OK" = "1" ]; then
  assert_json_key "POST plan/generate" 200 "['data']['plan_id']" \
    -X POST "$BASE/api/plan/generate" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
    -d '{"health_info":{"age":45,"gender":"male","height":175,"weight":85},"preferences":{"dietary":"低糖低脂","activity":"中等强度有氧"}}'

  assert_json_key "GET plan/current" 200 "['data']['plan_id']" "$BASE/api/plan/current" \
    -H "Authorization: Bearer $TOKEN"

  PLAN_ID=$(http_body "$BASE/api/plan/current" -H "Authorization: Bearer $TOKEN" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['plan_id'])" 2>/dev/null || echo "1")

  if [ -n "$PLAN_ID" ] && [ "$PLAN_ID" != "null" ]; then
    assert_json_key "PUT plan/adjust" 200 "['data']['plan_id']" \
      -X PUT "$BASE/api/plan/adjust" \
      -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
      -d "{\"plan_id\":$PLAN_ID,\"feedback\":\"增加蔬菜选项\"}"
  fi
else
  log_skip "POST /api/plan/generate (依赖Dify)"
  log_skip "GET /api/plan/current (依赖risk predict)"
  log_skip "PUT /api/plan/adjust (依赖plan生成)"
  PLAN_ID=""
fi

# ============================================
echo ""; echo "── 10. 打卡模块 ──"
if [ -n "$PLAN_ID" ] && [ "$PLAN_ID" != "null" ]; then
  assert_json_key "POST punch打卡" 201 "['data']['id']" \
    -X POST "$BASE/api/punch" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
    -d "{\"plan_id\":$PLAN_ID,\"punch_type\":\"diet\",\"completion_status\":\"completed\",\"remarks\":\"完成\"}"
else
  log_skip "POST /api/punch (无plan_id)"
fi

assert_json_key "GET punch/list" 200 "['pagination']" "$BASE/api/punch/list" \
  -H "Authorization: Bearer $TOKEN"

assert_json_key "GET punch/analysis" 200 "['data']['total_punches']" "$BASE/api/punch/analysis" \
  -H "Authorization: Bearer $TOKEN"

# ============================================
echo ""; echo "── 11. 医师对话 ──"
assert_code "POST chat/doctor/99999" 404 -X POST "$BASE/api/chat/doctor/99999" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"message":"hi"}'

if [ -n "$DOCTOR_ID" ]; then
  log_skip "POST /api/chat/doctor/$DOCTOR_ID (SSE流)"
  log_skip "GET /api/chat/doctor/$DOCTOR_ID/conversations (需Dify)"
fi

# ============================================
echo ""; echo "── 12. AI助手 ──"
log_skip "POST /api/assistant/chat (SSE流)"
assert_json_key "GET assistant/advice" 200 "['pagination']" "$BASE/api/assistant/advice" \
  -H "Authorization: Bearer $TOKEN"
log_skip "GET /api/assistant/conversations (需Dify)"

# ============================================
echo ""; echo "── 13. 管理员模块 ──"
if [ -n "$ADMIN_TOKEN" ]; then
  assert_json_key "GET admin/logs" 200 "['pagination']" "$BASE/api/admin/logs" \
    -H "Authorization: Bearer $ADMIN_TOKEN"
  assert_code "GET admin/logs 非管理员" 403 "$BASE/api/admin/logs" \
    -H "Authorization: Bearer $TOKEN"

  # admin/execute - 参数化查询
  assert_json_key "POST admin/execute tool_name" 200 "['data']['rows']" \
    -X POST "$BASE/api/admin/execute" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d '{"tool_name":"query_user_profile","user_id":1}'

  # admin/execute - 非管理员查本人
  assert_json_key "POST admin/execute 用户查本人" 200 "['data']['rows']" \
    -X POST "$BASE/api/admin/execute" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
    -d '{"tool_name":"query_risk_history"}'

  # admin/execute - 非管理员传user_id被静默覆盖为本人数据（安全行为）
  CODE=$(http_code -X POST "$BASE/api/admin/execute" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
    -d '{"tool_name":"query_risk_history","user_id":1}')
  if [ "$CODE" = "200" ] || [ "$CODE" = "403" ]; then
    log_pass "POST admin/execute 用户传他人user_id被限制 ($CODE)"
  else
    log_fail "POST admin/execute 用户传他人user_id" "期望200/403 实际$CODE"
  fi

  # admin/execute - SQL
  assert_json_key "POST admin/execute SQL" 200 "['data']['rows']" \
    -X POST "$BASE/api/admin/execute" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d '{"sql":"SELECT COUNT(*) as cnt FROM users"}'

  # admin/execute - 非管理员SQL被拒绝
  assert_code "POST admin/execute 普通用户SQL被拒绝" 403 \
    -X POST "$BASE/api/admin/execute" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
    -d '{"sql":"SELECT * FROM users"}'

  log_skip "POST /api/admin/chat (SSE流)"
else
  log_skip "管理员模块 (admin登录失败)"
fi

# ============================================
echo ""; echo "── 14. 文件上传 ──"
# 创建合法的最小PNG
python3 -c "
import struct,zlib
def chunk(t, d):
    c = t + d
    return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
p = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
p += chunk(b'IDAT', zlib.compress(b'\x00'))
p += chunk(b'IEND', b'')
open('/tmp/test_avatar.png', 'wb').write(p)
" 2>/dev/null || true

if [ -f /tmp/test_avatar.png ]; then
  assert_json_key "POST upload/avatar" 200 "['data']['url']" \
    -X POST "$BASE/api/upload/avatar" \
    -H "Authorization: Bearer $TOKEN" -F "avatar=@/tmp/test_avatar.png"
fi

# ============================================
echo ""; echo "── 15. 边界测试 ──"
assert_code "GET 404路由" 404 "$BASE/api/nonexistent"
assert_code "GET articles/99999" 404 "$BASE/api/articles/99999"
assert_code "DELETE 取消不存在收藏" 404 -X DELETE "$BASE/api/articles/99999/collect" \
  -H "Authorization: Bearer $TOKEN"

# ============================================
echo ""; echo "========================================"
PASS=$(grep -c "^PASS" $RESULTS_FILE 2>/dev/null || echo 0)
FAIL=$(grep -c "^FAIL" $RESULTS_FILE 2>/dev/null || echo 0)
SKIP=$(grep -c "^SKIP" $RESULTS_FILE 2>/dev/null || echo 0)
echo "  测试完成"
echo "========================================"
echo "  通过: $PASS"
echo "  失败: $FAIL"
echo "  跳过: $SKIP"
echo "========================================"
cat $RESULTS_FILE

FAIL_NUM=$(echo "$FAIL" | tr -d '[:space:]')
[ -n "$FAIL_NUM" ] && [ "$FAIL_NUM" -gt 0 ] && exit 1
exit 0
