#!/usr/bin/env python3
"""
API endpoint для распознавания аудио через Telegram API.

Использование:
    uvicorn transcribe_api:app --reload --port 8000

Или:
    python transcribe_api.py

Endpoint:
    POST /transcribe
    Body: multipart/form-data с файлом 'audio'
    Response: {"text": "распознанный текст", "transcription_id": "..."}
"""

import asyncio
import tempfile
import os
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from telethon import TelegramClient
from telethon import functions
import uvicorn
from pathlib import Path

# Импортируем функцию конвертации
from convert_to_telegram_voice import convert_to_telegram_voice

app = FastAPI(title="Telegram Voice Transcription API")

# Настройка CORS для веб-интерфейса
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене лучше указать конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Монтируем статические файлы для веб-интерфейса
web_dir = Path(__file__).parent / "web"
if web_dir.exists():
    app.mount("/static", StaticFiles(directory=str(web_dir)), name="static")

# Telegram API credentials
API_ID = '21433623'
API_HASH = '4862f5339c133e3d738d830c7f4250fc'

# Глобальный клиент (будет инициализирован при старте)
client = None

# Чат для отправки временных сообщений (можно изменить через переменную окружения)
TRANSCRIBE_CHAT = os.getenv('TRANSCRIBE_CHAT', 'me')  # По умолчанию: Saved Messages

# Сообщение для клиента, если Telegram не авторизован
AUTH_REQUIRED_MESSAGE = (
    "Требуется авторизация Telegram. На сервере выполните: "
    "cd /var/www/www-root/data/www/music/voices/server/final_voicegram && .venv/bin/python run_transcribe.py me 1"
)

# Очередь для обработки запросов
# Инициализируем сразу, чтобы не было проблем с None
queue_processor_running = False

async def ensure_telegram_client():
    """Ленивая инициализация Telegram клиента при первом использовании."""
    global client
    if client is None:
        try:
            client = TelegramClient('session', API_ID, API_HASH)
            # Подключаемся с таймаутом (увеличено для медленных сетей)
            await asyncio.wait_for(client.connect(), timeout=30.0)
            if await client.is_user_authorized():
                print("✓ Telegram клиент подключен и авторизован", flush=True)
            else:
                print("⚠ Telegram клиент не авторизован. Нужна авторизация (код из Telegram).", flush=True)
                print("   Запустите в терминале: python3 run_transcribe.py me 1 — введите код и при необходимости пароль 2FA.", flush=True)
                raise Exception("TELEGRAM_AUTH_REQUIRED")
        except asyncio.TimeoutError:
            print("⚠ Таймаут при подключении к Telegram.", flush=True)
            print("   Проверьте сеть/VPN. Если Telegram запрашивает код — авторизуйтесь: python3 run_transcribe.py me 1", flush=True)
            raise Exception("Таймаут при подключении к Telegram")
        except Exception as e:
            print(f"⚠ Ошибка при инициализации Telegram клиента: {e}", flush=True)
            print("   Если нужен код входа — авторизуйтесь: python3 run_transcribe.py me 1", flush=True)
            raise
    elif not client.is_connected():
        try:
            await asyncio.wait_for(client.connect(), timeout=30.0)
        except Exception as e:
            print(f"[Очередь] Переподключение к Telegram не удалось: {e}", flush=True)
            print("   Проверьте сеть/VPN. Если запрашивается код — авторизуйтесь: python3 run_transcribe.py me 1", flush=True)
            raise
    return client

# Обработчик очереди запросов
async def process_queue():
    """Обрабатывает запросы из очереди последовательно."""
    global queue_processor_running
    queue_processor_running = True
    print("Обработчик очереди запущен")
    
    while True:
        try:
            # Ждем запрос из очереди
            print("[Очередь] Ожидание запроса...")
            request_data = await request_queue.get()
            print(f"[Очередь] Получен запрос из очереди!")
            
            if request_data is None:  # Сигнал остановки
                break
            
            audio_file_path, converted_file_path, response_data, event = request_data
            print(f"[Очередь] Начало обработки: {audio_file_path}")
            
            try:
                # Инициализируем Telegram клиента
                try:
                    tg_client = await ensure_telegram_client()
                except Exception as e:
                    err_str = str(e)
                    print(f"[Очередь] Ошибка инициализации Telegram: {e}", flush=True)
                    print("   Если нужен код входа — в другом терминале: python3 run_transcribe.py me 1", flush=True)
                    response_data['success'] = False
                    if "TELEGRAM_AUTH_REQUIRED" in err_str:
                        response_data['error'] = "telegram_auth_required"
                        response_data['message'] = AUTH_REQUIRED_MESSAGE
                    else:
                        response_data['error'] = f"Ошибка подключения к Telegram: {err_str}"
                    event.set()
                    request_queue.task_done()
                    continue
                
                # Отправляем файл в Telegram (чат для отправки: TRANSCRIBE_CHAT)
                print(f"[Очередь] Отправка файла в Telegram (чат: {TRANSCRIBE_CHAT})...", flush=True)
                # Увеличиваем таймаут для больших файлов
                file_size_mb = os.path.getsize(converted_file_path) / (1024 * 1024) if os.path.exists(converted_file_path) else 0
                upload_timeout = max(120.0, 120.0 + (file_size_mb / 5) * 60)  # Минимум 2 минуты, +1 минута на каждые 5MB
                print(f"[Очередь] Размер файла: {file_size_mb:.2f} MB, таймаут загрузки: {upload_timeout:.0f} секунд")
                sent_message = await asyncio.wait_for(
                    tg_client.send_file(
                        TRANSCRIBE_CHAT,
                        converted_file_path,
                        voice_note=True,
                        caption="Transcription request"
                    ),
                    timeout=upload_timeout
                )
                
                message_id = sent_message.id
                print(f"[Очередь] Файл отправлен в Telegram, сообщение ID: {message_id}", flush=True)
                
                # Проверяем, что сообщение действительно голосовое
                if not hasattr(sent_message, 'voice') and not hasattr(sent_message, 'media'):
                    print(f"[Очередь] ⚠ Предупреждение: сообщение может быть не распознано как голосовое")
                else:
                    print(f"[Очередь] ✓ Сообщение отправлено как голосовое (voice={hasattr(sent_message, 'voice')}, media={hasattr(sent_message, 'media')})")
                
                # Увеличиваем задержку для обработки Telegram (важно для больших файлов)
                print(f"[Очередь] Ожидание обработки сообщения Telegram...")
                await asyncio.sleep(10)  # Увеличено до 10 секунд для надежности
                
                # Распознаем
                print(f"[Очередь] Запрос распознавания...")
                result = await asyncio.wait_for(
                    tg_client(functions.messages.TranscribeAudioRequest(
                        peer=TRANSCRIBE_CHAT,
                        msg_id=message_id
                    )),
                    timeout=60.0  # Увеличенный таймаут для первого запроса
                )
                
                # Ждем завершения распознавания (увеличенное время для больших файлов)
                max_wait_time = max(120, int(file_size_mb * 2))  # Минимум 2 минуты, +2 секунды на каждый MB
                wait_interval = 2
                waited = 0
                print(f"[Очередь] Максимальное время ожидания распознавания: {max_wait_time} секунд")
                
                while hasattr(result, 'pending') and result.pending and waited < max_wait_time:
                    print(f"[Очередь] Распознавание обрабатывается... ({waited}/{max_wait_time}с)")
                    await asyncio.sleep(wait_interval)
                    waited += wait_interval
                    
                    try:
                        result = await asyncio.wait_for(
                            tg_client(functions.messages.TranscribeAudioRequest(
                                peer=TRANSCRIBE_CHAT,
                                msg_id=message_id
                            )),
                            timeout=10.0
                        )
                    except asyncio.TimeoutError:
                        break
                
                # Удаляем временное сообщение
                """  
                try:
                    await tg_client.delete_messages(TRANSCRIBE_CHAT, [message_id])
                except:
                    pass
                """
                
                # Отправляем результат
                if hasattr(result, 'text') and result.text:
                    response_data['success'] = True
                    response_data['text'] = result.text
                    response_data['transcription_id'] = str(getattr(result, 'transcription_id', None))
                    response_data['pending'] = getattr(result, 'pending', False)
                else:
                    response_data['success'] = False
                    response_data['error'] = f"Не удалось получить текст. Результат: {result}"
                
            except Exception as e:
                err_str = str(e)
                print(f"[Очередь] Ошибка: {e}")
                import traceback
                traceback.print_exc()
                response_data['success'] = False
                # Ошибки Telegram "key is not registered" и т.п. — нужна авторизация
                if any(x in err_str.lower() for x in ("key is not registered", "not registered", "not authorized", "auth", "session")):
                    response_data['error'] = "telegram_auth_required"
                    response_data['message'] = AUTH_REQUIRED_MESSAGE
                else:
                    response_data['error'] = err_str
            finally:
                # Удаляем временные файлы
                try:
                    if audio_file_path != converted_file_path:  # Не удаляем, если это один файл
                        os.unlink(audio_file_path)
                except:
                    pass
                try:
                    os.unlink(converted_file_path)
                except:
                    pass
                
                # Уведомляем о завершении
                event.set()
            
            request_queue.task_done()
            
        except Exception as e:
            print(f"[Очередь] Критическая ошибка: {e}")
            import traceback
            traceback.print_exc()
            # Продолжаем работу, не останавливаем обработчик
            try:
                if 'response_data' in locals() and 'event' in locals():
                    response_data['success'] = False
                    response_data['error'] = f"Критическая ошибка: {str(e)}"
                    event.set()
                if 'request_queue' in locals():
                    request_queue.task_done()
            except:
                pass

# Очередь будет инициализирована при старте
request_queue = None

# Запускаем обработчик очереди при старте
@app.on_event("startup")
async def startup_queue_processor():
    """Запускает обработчик очереди."""
    import sys
    global request_queue, queue_processor_running
    request_queue = asyncio.Queue()
    print("Запуск обработчика очереди...", file=sys.stderr, flush=True)
    print("Запуск обработчика очереди...", flush=True)
    task = asyncio.create_task(process_queue())
    await asyncio.sleep(0.1)  # Даем время на запуск
    print("Обработчик очереди должен быть запущен", file=sys.stderr, flush=True)
    print("Обработчик очереди должен быть запущен", flush=True)


@app.post("/transcribe")
async def transcribe_audio(audio: UploadFile = File(...)):
    """
    Распознает аудио файл через Telegram API.
    Запросы ставятся в очередь для последовательной обработки.
    
    Args:
        audio: Аудио файл (OGG, MP3, M4A, WAV и т.д.)
    
    Returns:
        JSON с распознанным текстом и transcription_id
    """
    print(f"\n=== POST /transcribe получен ===", flush=True)
    print(f"Файл: {audio.filename}, тип: {audio.content_type}", flush=True)
    if request_queue:
        print(f"Запросов в очереди: {request_queue.qsize()}", flush=True)
    else:
        print("⚠ Очередь не инициализирована!", flush=True)
        raise HTTPException(status_code=503, detail="Очередь не инициализирована")
    
    # Сохраняем файл во временную директорию
    print("Начало сохранения файла...", flush=True)
    with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(audio.filename)[1]) as tmp_file:
        try:
            # Читаем содержимое файла
            print("Чтение файла...", flush=True)
            content = await audio.read()
            print(f"Файл прочитан, размер: {len(content)} байт", flush=True)
            tmp_file.write(content)
            tmp_file_path = tmp_file.name
            
            print(f"Получен файл: {audio.filename}, размер: {len(content)} байт", flush=True)
            
            # Проверяем, нужна ли конвертация (если уже OGG, можно пропустить)
            file_ext = os.path.splitext(audio.filename)[1].lower()
            if file_ext == '.ogg':
                print("Файл уже в формате OGG, пропускаем конвертацию", flush=True)
                converted_file = tmp_file_path
            else:
                # Конвертируем в формат Telegram voice message
                print("Конвертация в формат Telegram voice message...", flush=True)
                try:
                    # Создаем временный файл для результата конвертации
                    print("Создание временного файла для конвертации...", flush=True)
                    converted_tmp = tempfile.NamedTemporaryFile(delete=False, suffix='.ogg')
                    converted_tmp.close()
                    converted_output_path = converted_tmp.name
                    print(f"Временный файл создан: {converted_output_path}", flush=True)
                    
                    print("Вызов convert_to_telegram_voice...", flush=True)
                    # Определяем таймаут на основе размера файла (минимум 5 минут, +1 минута на каждые 10MB)
                    file_size_mb = os.path.getsize(tmp_file_path) / (1024 * 1024)
                    conversion_timeout = max(300.0, 300.0 + (file_size_mb / 10) * 60)  # Минимум 5 минут
                    print(f"Размер файла: {file_size_mb:.2f} MB, таймаут конвертации: {conversion_timeout:.0f} секунд", flush=True)
                    
                    # Запускаем синхронную конвертацию в executor с увеличенным таймаутом
                    loop = asyncio.get_event_loop()
                    try:
                        converted_files = await asyncio.wait_for(
                            loop.run_in_executor(
                                None,
                                lambda: convert_to_telegram_voice(
                                    tmp_file_path,
                                    output_path=converted_output_path,
                                    duration=None,
                                    bitrate="33k",
                                    auto_split=False
                                )
                            ),
                            timeout=conversion_timeout
                        )
                        print(f"Конвертация завершена, результат: {converted_files}", flush=True)
                    except asyncio.TimeoutError:
                        print(f"Таймаут при конвертации (таймаут: {conversion_timeout:.0f}с)!", flush=True)
                        raise HTTPException(status_code=504, detail=f"Таймаут при конвертации аудио (файл слишком большой, попробуйте разбить на части)")
                    
                    if not converted_files:
                        raise HTTPException(status_code=500, detail="Ошибка при конвертации аудио")
                    
                    converted_file = converted_files[0]
                    print(f"Файл сконвертирован: {converted_file}", flush=True)
                except HTTPException:
                    raise
                except Exception as e:
                    print(f"Ошибка при конвертации: {e}", flush=True)
                import traceback
                traceback.print_exc()
                raise HTTPException(status_code=500, detail=f"Ошибка при конвертации: {str(e)}")
            
            # Создаем объекты для передачи результата
            response_data = {}
            event = asyncio.Event()
            
            # Ставим запрос в очередь
            if request_queue is None:
                raise HTTPException(status_code=503, detail="Очередь не инициализирована. Подождите несколько секунд.")
            queue_size = request_queue.qsize()
            print(f"Запрос поставлен в очередь (позиция: {queue_size + 1})", flush=True)
            await request_queue.put((tmp_file_path, converted_file, response_data, event))
            print(f"Запрос добавлен в очередь, размер очереди: {request_queue.qsize()}", flush=True)
            
            # Ждем завершения обработки (увеличенный таймаут для больших файлов)
            # Базовый таймаут 10 минут + дополнительное время для больших файлов
            file_size_mb = os.path.getsize(tmp_file_path) / (1024 * 1024) if os.path.exists(tmp_file_path) else 0
            processing_timeout = max(600.0, 600.0 + (file_size_mb / 10) * 60)  # Минимум 10 минут
            print(f"Таймаут обработки: {processing_timeout:.0f} секунд", flush=True)
            try:
                await asyncio.wait_for(event.wait(), timeout=processing_timeout)
            except asyncio.TimeoutError:
                raise HTTPException(status_code=504, detail=f"Таймаут при обработке запроса (файл слишком большой или очередь перегружена)")
            
            # Возвращаем результат
            if response_data.get('success'):
                return JSONResponse({
                    "success": True,
                    "text": response_data.get('text'),
                    "transcription_id": response_data.get('transcription_id'),
                    "pending": response_data.get('pending', False),
                    "queue_position": 0  # Уже обработан
                })
            else:
                err = response_data.get('error', 'Неизвестная ошибка')
                # Требуется авторизация Telegram — 503 и инструкция для клиента
                if err == "telegram_auth_required":
                    return JSONResponse(
                        status_code=503,
                        content={
                            "success": False,
                            "error": err,
                            "message": response_data.get('message', AUTH_REQUIRED_MESSAGE),
                        },
                    )
                raise HTTPException(status_code=500, detail=err)
                
        except HTTPException:
            raise
        except Exception as e:
            print(f"Ошибка: {e}")
            import traceback
            traceback.print_exc()
            raise HTTPException(
                status_code=500,
                detail=f"Ошибка при обработке: {str(e)}"
            )


@app.get("/")
async def root():
    """Веб-интерфейс."""
    index_file = web_dir / "index.html"
    if index_file.exists():
        return FileResponse(
            str(index_file),
            media_type="text/html"
        )
    return JSONResponse({"error": "index.html not found"})

@app.get("/test")
async def test():
    """Тестовый endpoint."""
    return {"status": "ok", "message": "Server is working"}


@app.get("/health")
async def health():
    """Проверка здоровья сервиса."""
    try:
        connected = client is not None and client.is_connected() if client else False
    except:
        connected = False
    return {
        "status": "ok",
        "telegram_connected": connected,
        "queue_size": request_queue.qsize() if request_queue else 0,
        "queue_processor_running": queue_processor_running
    }


@app.get("/transcribe_recent")
async def transcribe_recent_voice_messages(limit: int = 20):
    """
    Транскрибирует последние голосовые сообщения из Saved Messages.
    
    Args:
        limit: Количество последних сообщений для проверки (по умолчанию 20)
    
    Returns:
        JSON со списком распознанных сообщений
    """
    try:
        tg_client = await ensure_telegram_client()
        
        results = []
        voice_count = 0
        
        async for message in tg_client.iter_messages(TRANSCRIBE_CHAT, limit=limit):
            # Проверяем, является ли сообщение голосовым
            is_voice = message.voice
            
            if is_voice:
                voice_count += 1
                # Получаем длительность из voice объекта
                duration = None
                try:
                    if hasattr(message, 'voice') and message.voice:
                        duration = getattr(message.voice, 'duration', None)
                    if not duration and hasattr(message, 'media') and message.media:
                        duration = getattr(message.media, 'duration', None)
                except:
                    pass
                
                message_info = {
                    "message_id": message.id,
                    "duration": duration,
                    "date": str(message.date),
                    "sender_id": message.sender_id,
                    "media_type": str(type(message.media)) if hasattr(message, 'media') and message.media else None
                }
                
                try:
                    result = await tg_client(functions.messages.TranscribeAudioRequest(
                        peer=TRANSCRIBE_CHAT,
                        msg_id=message.id
                    ))
                    
                    if hasattr(result, 'text') and result.text:
                        message_info['success'] = True
                        message_info['text'] = result.text
                        message_info['transcription_id'] = str(getattr(result, 'transcription_id', None))
                        message_info['pending'] = getattr(result, 'pending', False)
                    else:
                        message_info['success'] = False
                        message_info['error'] = "Не удалось получить текст"
                        message_info['result'] = str(result)
                        
                except Exception as e:
                    message_info['success'] = False
                    message_info['error'] = str(e)
                
                results.append(message_info)
        
        return JSONResponse({
            "success": True,
            "total_voice_messages": voice_count,
            "messages": results
        })
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка: {str(e)}")


if __name__ == "__main__":
    import sys
    import signal
    
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8002
    
    # Останавливаем старый процесс на этом порту, если есть
    try:
        import subprocess
        result = subprocess.run(['lsof', '-ti', f':{port}'], capture_output=True, text=True)
        if result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                subprocess.run(['kill', '-9', pid], capture_output=True)
            print(f"Остановлен старый процесс на порту {port}")
    except:
        pass
    
    print("Запуск сервера...")
    print(f"Веб-интерфейс: http://localhost:{port}")
    print(f"API документация: http://localhost:{port}/docs")
    print(f"API endpoint: http://localhost:{port}/transcribe")
    print(f"Тест: http://localhost:{port}/test")
    uvicorn.run(app, host="0.0.0.0", port=port)

