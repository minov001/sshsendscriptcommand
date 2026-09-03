#!/bin/bash

check_path='^[A-Za-zА-Яа-я0-9(),./@_[:space:]-]+$'
check_num='^[0-9]+$'

#Проверка полного пути запускаемого скрипта на допустимые символы
if ! [[ "$(realpath "$0")" =~ $check_path ]]; then
  echo -e "\nПуть к запускаемому скрипту содержит запрещенные символы.

Текущий путь: $(realpath "$0")"
  exit 1
else
  #Запись пути к каталогу в переменную (каталог с файлом скрипта)
  dir_runscript="$(dirname "$(realpath "$0")")"
fi

cd "$dir_runscript"

#Создание необходимых каталогов
mkdir -p ./files/sendmessage
msg_file="/files/sendmessage/message1.smsg"
echo "" >".$msg_file"

if [[ -n "$(which kate)" ]]; then

  echo -e "\nВведите сообщение в открытом окне kate, сохраните и закройте окно"
  notify-send -t 0 'Ввод сообщения' 'Введите сообщение в открытом окне kate, сохраните и закройте окно'

  echo ""
  read -p "Нажмите Enter для открытия файла сообщения"
  echo ""

  (kate -n -b "${dir_runscript}${msg_file}" 2>/dev/null) &
  wait
  sleep 1
else
  echo -e "\nВведите сообщение в файл '${dir_runscript}${msg_file}'"
fi

echo -e "\nТекст сообщения
#----------
"

cat "${dir_runscript}${msg_file}"

echo -e "\n#----------"

#Функция ответа Да/Нет
function yesorno {
  while true; do
    read -p "$infmsg" ynaction
    case $ynaction in
    [Yy])
      ynaction="yes"
      return 0
      ;;
    [Nn])
      echo "$errmsg"
      break
      ;;
    esac
  done
}

infmsg="Продолжить? [y/n]: "
errmsg="Завершено"

yesorno

if [[ "$ynaction" = "yes" ]]; then
  bash ./run-sssc.sh -hf "test" -m -us "tests2" -sp "sendmessage:sendmessage:autopassudo:0:0"

  echo ""
  read -p "Нажмите Enter для завершения"
  echo ""
  echo -e "\nЗавершено"
fi
