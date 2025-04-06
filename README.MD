```markdown

# Auto Update Service for Kaspersky Archives
Скрипт для автоматической проверки, загрузки и распаковки архивов обновлений Kaspersky 
(и любых других поставляемых в архивах) с удаленного сервера.
У замените пользователя ez своего или на root
## Ключевые функции
- 🕵️ Автоматический поиск новых архивов
- 📥 Загрузка архивов по расписанию
- 📦 Распаковка в указанную директорию
- 🔔 Уведомления в Telegram
- 🗑️ Управление старыми версиями архивов
- 📝 Логирование всех операций

## Требования
- ОС: Linux
- Пакеты:
  ```bash
  sudo apt install curl wget unzip
  ```
- Права:
  ```bash
  sudo mkdir -p /srv/antivirus
  sudo chown -R ez:ez /srv/antivirus /home/ez/downloads
  ```

## Установка
1. Скопируйте скрипт:
   ```bash
   sudo mkdir -p /opt/update-service
   sudo cp script.sh /opt/update-service/
   sudo chmod +x /opt/update-service/script.sh
   ```

2. Настройте параметры в `script.sh`:
   ```bash
   nano /opt/update-service/script.sh
   ```
   ```ini
   base_url="http://your-server/updates/"
   telegram_token="YOUR_BOT_TOKEN"
   telegram_chat_id="YOUR_CHAT_ID"
   ```

## Настройка сервиса
1. Создайте сервисный файл:
   ```bash
   sudo nano /etc/systemd/system/update-service.service
   ```
   ```ini
   [Unit]
   Description=Auto Update Service
   After=network.target

   [Service]
   Type=simple
   User=ez
   WorkingDirectory=/opt/update-service
   ExecStart=/bin/bash /opt/update-service/script.sh
   Restart=on-failure
   RestartSec=60s
   Environment="PATH=/usr/bin:/bin"

   [Install]
   WantedBy=multi-user.target
   ```

2. Запустите сервис:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now update-service.service
   ```

## Telegram-уведомления
1. Создайте бота через [@BotFather](https://t.me/BotFather)
2. Получите ID чата через [@getidsbot](https://t.me/getidsbot)
3. Вставьте полученные данные в скрипт:
   ```bash
   telegram_token="123456:ABC-DEF1234ghI6l-zyx57W2v1u123ew11"
   telegram_chat_id="YOUR_CHAT_ID"
   ```

## Логирование
Просмотр логов:
```bash
journalctl -u update-service.service -f
tail -f /var/log/updater.log
```

## Безопасность
- 🔒 Храните токен Telegram в защищенном месте
- 🔑 Настройте правильные права:
  ```bash
  sudo chmod 640 /opt/update-service/script.sh
  sudo chown root:ez /opt/update-service/script.sh
  ```

## Примеры уведомлений
1. Старт скрипта:
   ```
   🔄 Скрипт запущен! Мониторинг:  "http://your-server/updates/"
   ```
2. Новая версия:
   ```
   🔍 Обнаружен новый архив: KES_11_20250402.zip
   ```
3. Успешная распаковка:
   ```
   📦 Распаковка успешна:
   ├─ Файлов: 142
   ├─ Место до:
   │  ├─ Загрузка: 15G
   │  └─ Распаковка: 28G
   └─ Место после:
      ├─ Загрузка: 14G
      └─ Распаковка: 27G
   ```

## Возможные проблемы
1. **Отказ в доступе при записи**:
   ```bash
   sudo chown -R ez:ez /home/ez/downloads
   sudo setfacl -Rm u:ez:rwX /srv/antivirus
   ```

2. **Ошибки Telegram API**:
   ```bash
   curl -s "https://api.telegram.org/bot$TOKEN/getMe"
   ```

## Лицензия
MIT License © 2024 
```