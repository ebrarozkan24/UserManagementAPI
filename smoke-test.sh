#!/usr/bin/env bash
# Smoke test for the User Management API.
# Start the API first (dotnet run), then run:  bash smoke-test.sh
# Optional: BASE_URL=http://localhost:5080 TOKEN=techhive-secret-token bash smoke-test.sh

BASE_URL="${BASE_URL:-http://localhost:5080}"
TOKEN="${TOKEN:-techhive-secret-token}"

pass=0
fail=0

# check <description> <expected status> <curl args...>
check() {
  local desc="$1" expected="$2"
  shift 2
  local status
  status=$(curl -s -o /tmp/smoke_body.txt -w "%{http_code}" "$@")
  if [ "$status" = "$expected" ]; then
    echo "PASS  [$status] $desc"
    pass=$((pass + 1))
  else
    echo "FAIL  [$status, expected $expected] $desc"
    echo "      body: $(cat /tmp/smoke_body.txt)"
    fail=$((fail + 1))
  fi
}

AUTH=(-H "Authorization: Bearer $TOKEN")
JSON=(-H "Content-Type: application/json")

echo "== Public endpoints =="
check "GET /            (no token needed)" 200 "$BASE_URL/"
check "GET /health      (no token needed)" 200 "$BASE_URL/health"

echo "== Authentication middleware =="
check "GET /api/users without token -> 401"   401 "$BASE_URL/api/users"
check "GET /api/users with wrong token -> 401" 401 -H "Authorization: Bearer wrong" "$BASE_URL/api/users"
check "GET /api/users with non-bearer header -> 401" 401 -H "Authorization: Basic abc" "$BASE_URL/api/users"

echo "== Read =="
check "GET /api/users"            200 "${AUTH[@]}" "$BASE_URL/api/users"
check "GET /api/users/1"          200 "${AUTH[@]}" "$BASE_URL/api/users/1"
check "GET /api/users/999 -> 404" 404 "${AUTH[@]}" "$BASE_URL/api/users/999"
check "GET /api/users?department=IT" 200 "${AUTH[@]}" "$BASE_URL/api/users?department=IT"
check "GET /api/users?page=0 -> 400" 400 "${AUTH[@]}" "$BASE_URL/api/users?page=0"

echo "== Create =="
VALID='{"firstName":"Can","lastName":"Ozturk","email":"can.ozturk@techhive.com","department":"Finance","jobTitle":"Accountant"}'
check "POST valid user -> 201" 201 "${AUTH[@]}" "${JSON[@]}" -X POST -d "$VALID" "$BASE_URL/api/users"
NEW_ID=$(curl -s "${AUTH[@]}" "$BASE_URL/api/users" | grep -o '"id":[0-9]*,"firstName":"Can"' | grep -o '[0-9]*' | head -1)
check "POST duplicate email -> 409" 409 "${AUTH[@]}" "${JSON[@]}" -X POST -d "$VALID" "$BASE_URL/api/users"
check "POST invalid fields -> 400" 400 "${AUTH[@]}" "${JSON[@]}" -X POST \
  -d '{"firstName":"","lastName":"X","email":"not-an-email","department":"","jobTitle":""}' "$BASE_URL/api/users"
echo "      validation body: $(cat /tmp/smoke_body.txt)"
check "POST malformed JSON -> 400" 400 "${AUTH[@]}" "${JSON[@]}" -X POST -d '{bad json' "$BASE_URL/api/users"
check "POST without token -> 401" 401 "${JSON[@]}" -X POST -d "$VALID" "$BASE_URL/api/users"

echo "== Update (id=$NEW_ID) =="
UPDATED='{"firstName":"Can","lastName":"Ozturk","email":"can.ozturk@techhive.com","department":"Finance","jobTitle":"Senior Accountant"}'
check "PUT valid -> 200"          200 "${AUTH[@]}" "${JSON[@]}" -X PUT -d "$UPDATED" "$BASE_URL/api/users/$NEW_ID"
check "PUT non-existent -> 404"   404 "${AUTH[@]}" "${JSON[@]}" -X PUT -d "$UPDATED" "$BASE_URL/api/users/999"
check "PUT invalid -> 400"        400 "${AUTH[@]}" "${JSON[@]}" -X PUT -d '{"firstName":"A"}' "$BASE_URL/api/users/$NEW_ID"
check "PUT email of another user -> 409" 409 "${AUTH[@]}" "${JSON[@]}" -X PUT \
  -d '{"firstName":"Can","lastName":"Ozturk","email":"ayse.yilmaz@techhive.com","department":"Finance","jobTitle":"Accountant"}' \
  "$BASE_URL/api/users/$NEW_ID"

echo "== Delete =="
check "DELETE existing -> 204"      204 "${AUTH[@]}" -X DELETE "$BASE_URL/api/users/$NEW_ID"
check "DELETE again -> 404"         404 "${AUTH[@]}" -X DELETE "$BASE_URL/api/users/$NEW_ID"

echo "== Error-handling middleware =="
check "GET /api/test-error -> 500 JSON" 500 "${AUTH[@]}" "$BASE_URL/api/test-error"
echo "      error body: $(cat /tmp/smoke_body.txt)"

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
