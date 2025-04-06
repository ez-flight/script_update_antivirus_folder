#!/bin/bash
set -euo pipefail

# Конфигурация
 base_url="http://your-server/updates/"
url_pattern="KES_11_\\d{8}\\.zip"
download_dir="/home/ez/downloads"
extract_dir="/srv/antivirus"
check_interval=3600
max_backups=5
min_free_space_gb=1
log_file="/var/log/updater.log"

# Настройки уведомлений
notification_enabled=true
telegram_token="YOUR_BOT_TOKEN"
telegram_chat_id="YOUR_CHAT_ID"

# --- Функции ---
get_free_space() {
    local path="$1"
    df -h "$path" | awk 'NR==2 {print $4}'
}

get_latest_archive() {
    log "INFO" "Поиск последней версии архива" >&2
    
    local archive_list=$(curl -s "$base_url" | grep -oP "$url_pattern" | sort -Vr | uniq)
    
    if [ -z "$archive_list" ]; then
        log "ERROR" "Архивы не найдены" >&2
        echo ""
        return 1
    fi
    
    local archive_name=$(echo "$archive_list" | head -1)
    log "INFO" "Найден архив: $archive_name" >&2
    echo "${base_url}${archive_name}"
}

main() {
    check_dependencies
    init
    send_notification "🔄 Мониторинг обновлений включен!"
   
    # Добавляем проверку прав
    if [ ! -w "$download_dir" ]; then
        log "ERROR" "Нет прав на запись в директорию: $download_dir"
        send_notification "⛔ Критическая ошибка: Нет прав на запись в $download_dir"
        exit 1
    fi
    while true; do
        if check_free_space; then
            local archive_url=$(get_latest_archive || true)
            
            if [[ ! "$archive_url" =~ ^http[s]?://.+\.zip$ ]]; then
                log "ERROR" "Некорректный URL: $archive_url"
                sleep "$check_interval"
                continue
            fi

            local file_name=$(basename "$archive_url")
            local full_path="${download_dir}/${file_name}"
            
            if [ ! -f "$full_path" ]; then
                # Уведомление о новом архиве
                send_notification "🔍 Обнаружен новый архив: $file_name"
                log "INFO" "Попытка загрузки: $archive_url"
                
                if wget -q --tries=5 --timeout=60 -O "$full_path" "$archive_url"; then
                    # Уведомление о скачивании
                    local file_size=$(du -h "$full_path" | cut -f1)
                    send_notification "📥 Загрузка завершена: ${file_name} (${file_size})"
                    log "INFO" "Загрузка завершена: $full_path ($file_size)"
                else
                    log "ERROR" "Ошибка загрузки"
                    continue
                fi
            else
                log "WARN" "Архив уже загружен: $file_name"
                sleep "$check_interval"
                continue
            fi

            if unzip -tq "$full_path"; then
                # Уведомление о распаковке
                local before_extract_space_dl=$(get_free_space "$download_dir")
                local before_extract_space_ex=$(get_free_space "$extract_dir")
                
                if unzip -oq "$full_path" -d "$extract_dir"; then
                    local after_extract_space_dl=$(get_free_space "$download_dir")
                    local after_extract_space_ex=$(get_free_space "$extract_dir")
                    local file_count=$(unzip -l "$full_path" | wc -l)
                    
                    send_notification "📦 Распаковка успешна:
├─ Файлов: ${file_count}
├─ Место до:
│  ├─ Загрузка: ${before_extract_space_dl}
│  └─ Распаковка: ${before_extract_space_ex}
└─ Место после:
   ├─ Загрузка: ${after_extract_space_dl}
   └─ Распаковка: ${after_extract_space_ex}"
                    
                    cleanup_old_files
                else
                    log "ERROR" "Ошибка распаковки"
                    rm -f "$full_path"
                fi
            else
                log "ERROR" "Поврежденный архив"
                rm -f "$full_path"
            fi
        fi
        sleep "$check_interval"
    done
}

check_dependencies() {
    for cmd in curl wget unzip; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Ошибка: Необходимо установить $cmd"
            exit 1
        fi
    done
}

init() {
    # Создаем директории с явными правами
    mkdir -p "$download_dir"
    chmod 775 "$download_dir"  # Добавляем права на запись
    chown ez:ez "$download_dir" 2>/dev/null || true
    
    mkdir -p "$extract_dir"
    chmod 775 "$extract_dir"
    chown ez:ez "$extract_dir" 2>/dev/null || true
    
    touch "$log_file"
    chmod 644 "$log_file"
    chown ez:ez "$log_file" 2>/dev/null || true
}

cleanup_old_files() {
    find "$download_dir" -maxdepth 1 -name "KES_11_*.zip" -printf '%T@ %p\n' | \
        sort -rn | \
        awk -v max=$max_backups 'NR > max {print $2}' | \
        xargs -r rm -f
}

log() {
    local status="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$status] $message" | tee -a "$log_file"
}

send_notification() {
    local message="$1"
    log "INFO" "Отправка уведомления: $message" >&2
    
    if [ "$notification_enabled" = true ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H 'Content-Type: application/json' \
            -d "{\"chat_id\": \"$telegram_chat_id\", \"text\": \"$message\"}" \
            "https://api.telegram.org/bot$telegram_token/sendMessage")
        
        http_code=$(echo "$response" | tail -n1)
        if [ "$http_code" -ne 200 ]; then
            log "ERROR" "Ошибка Telegram API: $http_code" >&2
        fi
    fi
}

check_free_space() {
    local free_gb=$(df -B1G --output=avail "$download_dir" | tail -1 | tr -d ' ')
    
    if [ "$free_gb" -lt "$min_free_space_gb" ]; then
        send_notification "⛔ Недостаточно места: ${free_gb}GB свободно"
        return 1
    fi
    return 0
}

trap "log 'WARN' 'Скрипт остановлен'; exit 0" SIGINT SIGTERM

# Запуск
main
