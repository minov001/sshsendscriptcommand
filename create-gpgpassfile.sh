#!/bin/bash

RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
NoColor='\033[0m'

if [[ -n "$(which gpg2 2>/dev/null)" ]] && [[ -n "$(which zenity 2>/dev/null)" ]]; then
  pass=""
  gpgpass=""

  while [[ -z "$pass" ]]; do
    pass="$(zenity --forms --title="Пароль ssh/sudo" --text="Пароль ssh/sudo" --add-password="" 2>/dev/null)"
  done

  while [[ -z "$gpgpass" ]]; do
    gpgpass="$(zenity --forms --title="Пароль для шифрования" --text="Пароль для шифрования" --add-password="" 2>/dev/null)"
  done

  namegpgfile="$(date +"%Y%m%d-%H%M%S").gpg"
  echo "$pass" | gpg2 -c --pinentry-mode loopback --batch --yes --passphrase "$gpgpass" >"$namegpgfile"
  if [[ -f "$(pwd)/$namegpgfile" ]]; then
    echo "Выполнение завершено. В текущем каталоге создан файл $namegpgfile"
  fi
else
  echo -e "Проверка наличия исполняемых файлов не пройдена:
  gpg2: $(which gpg2 2>/dev/null) $([ -n "$(which gpg2 2>/dev/null)" ] && echo -e "${GREEN}Найден $NoColor" || echo -e "${RED}Не найден $NoColor")
  zenity: $(which zenity 2>/dev/null) $([ -n "$(which zenity 2>/dev/null)" ] && echo -e "${GREEN}Найден $NoColor" || echo -e "${RED}Не найден $NoColor")"
fi
