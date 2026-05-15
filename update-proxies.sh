#!/bin/bash

# Цвета (отключаем для GitHub Actions, но оставим для красоты)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Файлы (в GitHub Actions используем относительные пути)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_FILE="$SCRIPT_DIR/proxies.txt"
SOURCES_FILE="$SCRIPT_DIR/sources.txt"
LOG_FILE="$SCRIPT_DIR/logs/updater.log"
TEMP_FILE="/tmp/new_proxies_$$.txt"
VALIDATED_FILE="/tmp/validated_$$.txt"

# Создаём папку для логов
mkdir -p "$SCRIPT_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "$1"
}

cleanup() {
    rm -f "$TEMP_FILE" "$VALIDATED_FILE"
}
trap cleanup EXIT

log "${BLUE}🔄 Начинаю обновление прокси-листа...${NC}"

# 1. Сбор прокси
log "${YELLOW}📥 Сбор прокси из источников...${NC}"
> "$TEMP_FILE"

while IFS= read -r url; do
    [[ -z "$url" || "$url" == \#* ]] && continue
    log "   Загрузка: $url"
    curl -s --max-time 30 "$url" 2>/dev/null | \
        grep -v '^#' | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$' | \
        sort -u >> "$TEMP_FILE"
    sleep 1
done < "$SOURCES_FILE"

TOTAL=$(wc -l < "$TEMP_FILE")
log "${GREEN}📦 Собрано прокси: $TOTAL${NC}"

# 2. Проверка прокси
CHECK_COUNT=100
log "${YELLOW}🔍 Проверяем $CHECK_COUNT прокси...${NC}"
> "$VALIDATED_FILE"

head -"$CHECK_COUNT" "$TEMP_FILE" 2>/dev/null | while read proxy; do
    if curl -s --proxy "http://$proxy" --connect-timeout 5 --max-time 10 \
        https://httpbin.org/ip 2>/dev/null | grep -q '"origin"'; then
        echo "$proxy" >> "$VALIDATED_FILE"
        echo -e "${GREEN}✅ $proxy${NC}"
    else
        echo -e "${RED}❌ $proxy${NC}"
    fi
done

VALID_COUNT=$(wc -l < "$VALIDATED_FILE" 2>/dev/null || echo 0)
log "${GREEN}✅ Найдено рабочих прокси: $VALID_COUNT${NC}"

# 3. Обновляем файл
if [ "$VALID_COUNT" -gt 0 ]; then
    cp "$VALIDATED_FILE" "$PROXY_FILE"
    log "${GREEN}💾 Файл обновлён: $PROXY_FILE (${VALID_COUNT} прокси)${NC}"

    # Показываем первые 5
    log "${BLUE}📋 Первые 5 прокси:${NC}"
    head -5 "$PROXY_FILE" | while read p; do
        log "   • $p"
    done
else
    log "${RED}⚠️ Не найдено рабочих прокси. Файл не обновлён.${NC}"
fi

log "${GREEN}✅ Обновление завершено!${NC}"
