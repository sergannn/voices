#!/usr/bin/env python3
"""
Тестирование Firebase Authentication через REST API

Использование:
    python3 test_firebase_api.py
"""

import requests
import json
import time
from datetime import datetime

# Получите API_KEY из Firebase Console:
# Project Settings -> General -> Web API Key
# Или из firebase_options.dart (поле apiKey для web)

API_KEY = "AIzaSyAOkpMUI_pTHtnMPByXWDYCFh3aaeaSaTY"  # Web API Key из firebase_options.dart
FIREBASE_AUTH_URL = "https://identitytoolkit.googleapis.com/v1/accounts"

def test_signup(email, password):
    """Тест регистрации через Firebase REST API"""
    url = f"{FIREBASE_AUTH_URL}:signUp?key={API_KEY}"
    
    payload = {
        "email": email,
        "password": password,
        "returnSecureToken": True
    }
    
    print(f"\n{'='*60}")
    print("ТЕСТ РЕГИСТРАЦИИ")
    print(f"{'='*60}")
    print(f"Email: {email}")
    print(f"Password: {password}")
    print(f"\nЗапрос: POST {url}")
    
    try:
        response = requests.post(url, json=payload)
        result = response.json()
        
        if response.status_code == 200:
            print("\n✓ РЕГИСТРАЦИЯ УСПЕШНА!")
            print(f"  User ID: {result.get('localId')}")
            print(f"  Email: {result.get('email')}")
            print(f"  ID Token: {result.get('idToken', '')[:50]}...")
            print(f"  Refresh Token: {result.get('refreshToken', '')[:50]}...")
            return result
        else:
            print(f"\n✗ ОШИБКА РЕГИСТРАЦИИ:")
            print(f"  Status Code: {response.status_code}")
            print(f"  Error: {result.get('error', {}).get('message', 'Unknown error')}")
            return None
            
    except Exception as e:
        print(f"\n✗ ИСКЛЮЧЕНИЕ: {e}")
        return None

def test_signin(email, password):
    """Тест входа через Firebase REST API"""
    url = f"{FIREBASE_AUTH_URL}:signInWithPassword?key={API_KEY}"
    
    payload = {
        "email": email,
        "password": password,
        "returnSecureToken": True
    }
    
    print(f"\n{'='*60}")
    print("ТЕСТ ВХОДА")
    print(f"{'='*60}")
    print(f"Email: {email}")
    print(f"Password: {password}")
    print(f"\nЗапрос: POST {url}")
    
    try:
        response = requests.post(url, json=payload)
        result = response.json()
        
        if response.status_code == 200:
            print("\n✓ ВХОД УСПЕШЕН!")
            print(f"  User ID: {result.get('localId')}")
            print(f"  Email: {result.get('email')}")
            print(f"  ID Token: {result.get('idToken', '')[:50]}...")
            return result
        else:
            print(f"\n✗ ОШИБКА ВХОДА:")
            print(f"  Status Code: {response.status_code}")
            print(f"  Error: {result.get('error', {}).get('message', 'Unknown error')}")
            return None
            
    except Exception as e:
        print(f"\n✗ ИСКЛЮЧЕНИЕ: {e}")
        return None

def test_get_user_info(id_token):
    """Получить информацию о пользователе"""
    url = f"{FIREBASE_AUTH_URL}:lookup?key={API_KEY}"
    
    payload = {
        "idToken": id_token
    }
    
    print(f"\n{'='*60}")
    print("ПОЛУЧЕНИЕ ИНФОРМАЦИИ О ПОЛЬЗОВАТЕЛЕ")
    print(f"{'='*60}")
    
    try:
        response = requests.post(url, json=payload)
        result = response.json()
        
        if response.status_code == 200:
            users = result.get('users', [])
            if users:
                user = users[0]
                print("\n✓ ИНФОРМАЦИЯ ПОЛУЧЕНА:")
                print(f"  User ID: {user.get('localId')}")
                print(f"  Email: {user.get('email')}")
                print(f"  Email Verified: {user.get('emailVerified', False)}")
                print(f"  Created: {datetime.fromtimestamp(int(user.get('createdAt', 0)) / 1000)}")
                return user
        else:
            print(f"\n✗ ОШИБКА:")
            print(f"  {result.get('error', {}).get('message', 'Unknown error')}")
            return None
            
    except Exception as e:
        print(f"\n✗ ИСКЛЮЧЕНИЕ: {e}")
        return None

def main():
    print("="*60)
    print("ТЕСТИРОВАНИЕ FIREBASE AUTHENTICATION ЧЕРЕЗ REST API")
    print("="*60)
    
    if API_KEY == "YOUR_FIREBASE_API_KEY":
        print("\n⚠ ОШИБКА: Нужно указать API_KEY!")
        print("\nКак получить API ключ:")
        print("1. Откройте Firebase Console: https://console.firebase.google.com")
        print("2. Выберите ваш проект")
        print("3. Project Settings -> General")
        print("4. Найдите 'Web API Key' в секции 'Your apps'")
        print("5. Или посмотрите в firebase_options.dart (поле apiKey для web)")
        print("\nЗатем отредактируйте этот скрипт и укажите API_KEY")
        return
    
    # Генерируем уникальный email для теста
    timestamp = int(time.time() * 1000)
    test_email = f"test_{timestamp}@example.com"
    test_password = "test123456"
    
    # Тест 1: Регистрация
    signup_result = test_signup(test_email, test_password)
    
    if signup_result:
        id_token = signup_result.get('idToken')
        
        # Тест 2: Получение информации о пользователе
        if id_token:
            test_get_user_info(id_token)
        
        # Тест 3: Вход
        test_signin(test_email, test_password)
        
        print(f"\n{'='*60}")
        print("ВСЕ ТЕСТЫ ЗАВЕРШЕНЫ")
        print(f"{'='*60}")
        print(f"\nТестовый пользователь:")
        print(f"  Email: {test_email}")
        print(f"  Password: {test_password}")
        print(f"\nВы можете удалить его через Firebase Console:")
        print(f"  Authentication -> Users -> найти {test_email} -> Delete")
    else:
        print(f"\n{'='*60}")
        print("ТЕСТЫ НЕ ЗАВЕРШЕНЫ ИЗ-ЗА ОШИБКИ РЕГИСТРАЦИИ")
        print(f"{'='*60}")

if __name__ == "__main__":
    main()
