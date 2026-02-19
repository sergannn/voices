# API для распознавания аудио через Telegram

API endpoint, который принимает аудио файл и возвращает распознанный текст, используя встроенную функцию Telegram для распознавания речи.

## Как это работает

1. API принимает аудио файл
2. Отправляет его в Telegram как голосовое сообщение (в Saved Messages)
3. Использует `messages.TranscribeAudioRequest` для распознавания
4. Возвращает распознанный текст
5. Удаляет временное сообщение

## Установка

```bash
pip install fastapi uvicorn telethon
```

## Запуск API сервера

```bash
python transcribe_api.py
```

Или:

```bash
uvicorn transcribe_api:app --reload --port 8000
```

API будет доступен по адресу: `http://localhost:8000`

## Использование

### Через curl

```bash
curl -X POST "http://localhost:8000/transcribe" \
  -F "audio=@path/to/audio.ogg"
```

### Через Python

```python
import requests

with open('audio.ogg', 'rb') as f:
    files = {'audio': ('audio.ogg', f, 'audio/ogg')}
    response = requests.post('http://localhost:8000/transcribe', files=files)

result = response.json()
print(result['text'])  # Распознанный текст
```

### Через готовый скрипт

```bash
python test_transcribe_api.py audio.ogg
```

## Endpoints

### POST /transcribe

Распознает аудио файл.

**Параметры:**
- `audio` (file): Аудио файл (OGG, MP3, M4A, WAV и т.д.)

**Ответ:**
```json
{
  "success": true,
  "text": "распознанный текст",
  "transcription_id": "3201189630273730547",
  "pending": false
}
```

### GET /

Информация об API.

### GET /health

Проверка здоровья сервиса.

### GET /docs

Интерактивная документация (Swagger UI).

## Ограничения

- Требуется Telegram Premium для неограниченного использования
- Для не-премиум пользователей: ограничение по количеству транскрипций в неделю
- Работает только через Client API (авторизация как пользователь)
- Файл должен быть в формате, который Telegram может обработать как голосовое сообщение

## Примечания

- API автоматически удаляет временные сообщения после распознавания
- Если распознавание еще обрабатывается (`pending: true`), можно повторить запрос
- Поддерживаются различные форматы аудио (Telegram конвертирует их автоматически)

