#!/usr/bin/env python3
"""
Пример: отправка аудио файла на распознавание.
Сервер должен быть запущен: python transcribe_api.py 8002
"""

import sys
import requests

API_URL = "http://localhost:8002/transcribe"


def transcribe_audio_file(audio_file_path):
    with open(audio_file_path, "rb") as f:
        files = {"audio": (audio_file_path, f, "audio/ogg")}
        response = requests.post(API_URL, files=files, timeout=300)
    if response.status_code == 200:
        result = response.json()
        if result.get("success"):
            return result.get("text")
        return f"Ошибка: {result}"
    return f"HTTP {response.status_code}: {response.text}"


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Использование: python test_transcribe_api.py <путь_к_аудио>")
        sys.exit(1)
    text = transcribe_audio_file(sys.argv[1])
    print("Текст:", text)
