#!/bin/bash

# Создаём тестовый файл с прокси прямо здесь
echo "145.241.117.33:8888" > proxies.txt
echo "20.164.75.153:8080" >> proxies.txt
echo "185.230.191.240:3128" >> proxies.txt

# Выводим содержимое для проверки
cat proxies.txt

echo "✅ Скрипт выполнен, файл proxies.txt создан"
