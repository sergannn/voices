# Final Voicegram — расшифровка аудио через Telegram

Минимальный набор файлов для распознавания речи: загрузка аудио в API → отправка в Telegram как голосовое → возврат текста.

## Требования

- Python 3.9+
- **ffmpeg** (в PATH) — для конвертации не-OGG файлов
- Аккаунт Telegram (для API авторизации)

## Установка

```bash
cd final_voicegram
pip install -r requirements.txt
```

## Первый запуск (авторизация)

Один раз нужно войти в Telegram (код из приложения, при необходимости пароль 2FA):

```bash
python run_transcribe.py me 1
```

После этого в папке появится `session.session` — его не передавайте третьим лицам.

## Запуск API

```bash
python transcribe_api.py 8002
```

Сервер: `http://localhost:8002`  
Веб-интерфейс: `http://localhost:8002/static/index.html`  
Документация: `http://localhost:8002/docs`

## Пример запроса

```bash
curl -X POST http://localhost:8002/transcribe -F "audio=@speech.ogg"
```

Подробнее — в **TRANSCRIBE_API_README.md**.
