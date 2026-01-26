#!/bin/bash
# Тестирование Firebase Authentication через curl

API_KEY="AIzaSyAOkpMUI_pTHtnMPByXWDYCFh3aaeaSaTY"
FIREBASE_AUTH_URL="https://identitytoolkit.googleapis.com/v1/accounts"

# Генерируем уникальный email
TIMESTAMP=$(date +%s%3N)
TEST_EMAIL="test_${TIMESTAMP}@example.com"
TEST_PASSWORD="test123456"

echo "============================================================"
echo "ТЕСТИРОВАНИЕ FIREBASE AUTHENTICATION ЧЕРЕЗ CURL"
echo "============================================================"
echo ""
echo "Тестовые данные:"
echo "  Email: $TEST_EMAIL"
echo "  Password: $TEST_PASSWORD"
echo ""

# Тест 1: Регистрация
echo "============================================================"
echo "1. ТЕСТ РЕГИСТРАЦИИ"
echo "============================================================"
echo ""

SIGNUP_RESPONSE=$(curl -s -X POST \
  "${FIREBASE_AUTH_URL}:signUp?key=${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${TEST_EMAIL}\",
    \"password\": \"${TEST_PASSWORD}\",
    \"returnSecureToken\": true
  }")

echo "$SIGNUP_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$SIGNUP_RESPONSE"
echo ""

# Извлекаем ID Token из ответа
ID_TOKEN=$(echo "$SIGNUP_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('idToken', ''))" 2>/dev/null)
USER_ID=$(echo "$SIGNUP_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('localId', ''))" 2>/dev/null)

if [ -n "$ID_TOKEN" ]; then
    echo "✓ Регистрация успешна!"
    echo "  User ID: $USER_ID"
    echo ""
    
    # Тест 2: Получение информации о пользователе
    echo "============================================================"
    echo "2. ПОЛУЧЕНИЕ ИНФОРМАЦИИ О ПОЛЬЗОВАТЕЛЕ"
    echo "============================================================"
    echo ""
    
    USER_INFO=$(curl -s -X POST \
      "${FIREBASE_AUTH_URL}:lookup?key=${API_KEY}" \
      -H "Content-Type: application/json" \
      -d "{
        \"idToken\": \"${ID_TOKEN}\"
      }")
    
    echo "$USER_INFO" | python3 -m json.tool 2>/dev/null || echo "$USER_INFO"
    echo ""
    
    # Тест 3: Выход (не требуется для REST API, но можно проверить вход)
    echo "============================================================"
    echo "3. ТЕСТ ВХОДА"
    echo "============================================================"
    echo ""
    
    SIGNIN_RESPONSE=$(curl -s -X POST \
      "${FIREBASE_AUTH_URL}:signInWithPassword?key=${API_KEY}" \
      -H "Content-Type: application/json" \
      -d "{
        \"email\": \"${TEST_EMAIL}\",
        \"password\": \"${TEST_PASSWORD}\",
        \"returnSecureToken\": true
      }")
    
    echo "$SIGNIN_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$SIGNIN_RESPONSE"
    echo ""
    
    SIGNIN_ID_TOKEN=$(echo "$SIGNIN_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('idToken', ''))" 2>/dev/null)
    
    if [ -n "$SIGNIN_ID_TOKEN" ]; then
        echo "✓ Вход успешен!"
        echo ""
    fi
    
    echo "============================================================"
    echo "ВСЕ ТЕСТЫ ЗАВЕРШЕНЫ"
    echo "============================================================"
    echo ""
    echo "Тестовый пользователь создан:"
    echo "  Email: $TEST_EMAIL"
    echo "  Password: $TEST_PASSWORD"
    echo ""
    echo "Удалить пользователя можно через Firebase Console:"
    echo "  https://console.firebase.google.com/project/zvuki-ede81/authentication/users"
    echo ""
else
    echo "✗ Ошибка регистрации"
    echo ""
    echo "Проверьте:"
    echo "  1. API ключ правильный"
    echo "  2. Firebase Authentication включен в консоли"
    echo "  3. Email/Password провайдер включен"
    echo ""
fi
