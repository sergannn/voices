#!/usr/bin/env python3
"""
Рабочий скрипт для поиска и распознавания голосовых сообщений через Telegram API.
"""

import asyncio
import sys
from telethon import TelegramClient
from telethon import functions

api_id = '21433623'
api_hash = '4862f5339c133e3d738d830c7f4250fc'

async def find_and_transcribe_voice_messages(chat_username_or_id='me', limit=50):
    """
    Находит голосовые сообщения в чате и распознает их через Telegram API.
    
    Args:
        chat_username_or_id: Username чата (например, '@username') или 'me' для личных сообщений
        limit: Количество последних сообщений для проверки
    """
    async with TelegramClient('session', api_id, api_hash) as client:
        print(f"Ищем голосовые сообщения в чате: {chat_username_or_id}")
        print(f"Проверяем последние {limit} сообщений...\n")
        
        voice_count = 0
        
        try:
            async for message in client.iter_messages(chat_username_or_id, limit=limit):
                # Проверяем, является ли сообщение голосовым
                if message.voice:
                    voice_count += 1
                    print(f"{'='*60}")
                    print(f"Голосовое сообщение #{voice_count}")
                    print(f"От: {message.sender_id}")
                    print(f"Message ID: {message.id}")
                    # Получаем длительность безопасным способом
                    duration = getattr(message.voice, 'duration', None) or getattr(message, 'duration', None) or 'неизвестно'
                    print(f"Длительность: {duration} секунд")
                    print(f"Дата: {message.date}")
                    
                    # ВСТРОЕННОЕ РАСПОЗНАВАНИЕ ЧЕРЕЗ TELEGRAM API!
                    try:
                        print("\nЗапрос распознавания через Telegram API...")
                        result = await client(functions.messages.TranscribeAudioRequest(
                            peer=chat_username_or_id,
                            msg_id=message.id
                        ))
                        
                        # Проверяем trial ограничения (для не-премиум пользователей)
                        if hasattr(result, 'trial_remains_num') and result.trial_remains_num is not None:
                            print(f"\n⚠ Trial режим:")
                            print(f"  Осталось транскрипций: {result.trial_remains_num}")
                            if hasattr(result, 'trial_remains_until_date') and result.trial_remains_until_date:
                                from datetime import datetime
                                reset_date = datetime.fromtimestamp(result.trial_remains_until_date)
                                print(f"  Сброс квоты: {reset_date}")
                        
                        # Проверяем статус распознавания
                        if hasattr(result, 'pending') and result.pending:
                            print("\n⚠ Распознавание еще обрабатывается...")
                            print(f"  Transcription ID: {result.transcription_id}")
                            if hasattr(result, 'text') and result.text:
                                print(f"  Частичный результат: {result.text}")
                            print("\n  Обновления будут приходить через updateTranscribedAudio")
                            print("  с тем же transcription_id")
                        else:
                            # Получен готовый результат
                            if hasattr(result, 'text') and result.text:
                                print(f"\n✓ Распознанный текст:")
                                print(f"  {result.text}")
                                print(f"  Transcription ID: {result.transcription_id}")
                            else:
                                print(f"\nРезультат: {result}")
                        
                    except Exception as e:
                        print(f"\n✗ Ошибка при распознавании: {e}")
                        print("Возможные причины:")
                        print("  - Превышен лимит trial транскрипций (для не-премиум)")
                        print("  - Сообщение слишком длинное (превышает trial_duration_max)")
                        print("  - Функция недоступна для этого чата/бота")
                        print("  - Сообщение слишком старое")
                        print("  - Другая ошибка API")
                    
                    print()  # Пустая строка между сообщениями
            
            if voice_count == 0:
                print(f"Голосовые сообщения не найдены в последних {limit} сообщениях.")
            else:
                print(f"{'='*60}")
                print(f"Всего найдено голосовых сообщений: {voice_count}")
                
        except Exception as e:
            print(f"Ошибка при получении сообщений: {e}")
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    # Можно указать чат как аргумент командной строки
    chat = sys.argv[1] if len(sys.argv) > 1 else 'me'
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 50
    
    print("="*60)
    print("Распознавание голосовых сообщений через Telegram API")
    print("="*60)
    print()
    
    asyncio.run(find_and_transcribe_voice_messages(chat, limit))

