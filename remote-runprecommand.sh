#!/bin/bash

#Завершить выполнение скрипта в случае ошибки
set -e

#Отключить сохранение истории
export HISTFILE=/dev/null

#Если переменные не пусты и файл существует, то запускается выполнение
if [[ -n "$dirrunscript" ]] && [[ -n "$tfsc" ]] && [[ "$typers" = "autopassudo" || "$typers" = "cronscript" ]] && [[ -n "$sutype" ]] && [[ -f "$dirrunscript/$tfsc/$tfsc" ]]; then

  #Назначение прав на каталог и файл скрипта
  chmod 2700 "$dirrunscript/$tfsc"
  chmod 700 "$dirrunscript/$tfsc/$tfsc"

  #Зашифрованный через OpenSSL пароль хранится в переменной окружения текущей терминальной сессии.
  #К файлу, с которого считывается хэш сумма, доступ есть только у вас, поэтому использовать такой алгоритм безопасно.
  #Параметр количества итераций генерируется случайным образом при отправке.
  #Текущий файл remote-runprecommand.sh не передается на удаленный ПК, а кодируется в base64 и выполняется командой из терминальной сессии при выборе выполнения с автовводом sudo пароля или выполнения через cron.
  #На удаленный компьютер передаются только файлы основного отправляемого скрипта, шаблон файла cron задачи (если выбрано выполнение через cron) и дополнительные файлы (если выбрана отправка файлов).

  function remove_temp_files {
    echo -e "\nВыполнение скрипта закончено\n\nУдаление временных файлов\n"
    if [[ "$sutype" = "sudo" ]]; then
      openssl enc -base64 -d -aes-256-cbc -iter $oiter -pass pass:$(sha256sum "$dirrunscript/$tfsc/$tfsc" | cut -d ' ' -f 1) <<<"$lpas" 2>/dev/null | sudo -S --prompt="" rm -f -R -v "$dirrunscript/$tfsc"
    fi

    if ! [[ -d "$dirrunscript/$tfsc" ]]; then
      echo -e "\nВременные файлы удалены\n"
    else
      echo -e "\nНе удалось удалить временные файлы\n"
    fi
  }

  #Выполнение по типу автовведения пароля sudo
  function autopassudo {
    echo -e "\nВыполнение скрипта\n"
    if [[ "$sutype" = "sudo" ]]; then
      openssl enc -base64 -d -aes-256-cbc -iter $oiter -pass pass:$(sha256sum "$dirrunscript/$tfsc/$tfsc" | cut -d ' ' -f 1) <<<"$lpas" 2>/dev/null | sudo -S --prompt="" "$dirrunscript/$tfsc/$tfsc" && exec_err_status="0" || exec_err_status="1"

      if [[ "$exec_err_status" -eq "0" ]]; then

        if [[ "$version_exec_script" -gt "0" ]]; then
          chmod 700 "$dirrunscript/$tfsc/add_ver_to_file.sh"
          "$dirrunscript/$tfsc/add_ver_to_file.sh"
        fi

        remove_temp_files
        exit 0
      else
        remove_temp_files
        exit 1
      fi
    fi
  }

  #Выполнение через cron задачу
  function cronscript {
    echo ""

    set +e

    #Вычисление значений минуты, часа, дня, месяца и последнего дня месяца
    let dateminute=$(date +%M | sed "s/^0//")+2
    let datehours=$(date +%H | sed "s/^0//")
    let dateday=$(date +%d | sed "s/^0//")
    let datemes=$(date +%m | sed "s/^0//")
    let coldaymes=$(date -d "$(date +'%m/01')+1month -1day" +%d)

    set -e

    #Если значения не пусты, то продолжается выполнение
    if [[ -n "$dateminute" ]] && [[ -n "$datehours" ]] && [[ -n "$dateday" ]] && [[ -n "$datemes" ]] && [[ -n "$coldaymes" ]]; then

      set +e

      #Если значение минуты больше 59, то к значению часа добавляется 1, а значение минуты будет 1
      if [[ "$dateminute" -gt "59" ]]; then
        let dateminute=1
        let datehours=$datehours+1
      fi

      #Если значение часа больше 23, то значению часа присваивается 1, а значение дня повышается на 1
      if [[ "$datehours" -gt "23" ]]; then
        let datehours=0
        let dateday=$dateday+1
      fi

      #Если значение дня больше количества дней в месяце, то значению дня присваивается 1, а значение месяца повышается на 1
      if [[ "$dateday" -gt "$coldaymes" ]]; then
        let dateday=1
        let datemes=$datemes+1
      fi

      #Если значение месяца больше 12, то значению присваивается 1
      if [[ "$datemes" -gt "12" ]]; then
        let datemes=1
      fi

      set -e

      #Внесение значений в файл шаблона cron задачи
      sed -i "s!минуты-часы-день-месяц!$dateminute $datehours $dateday $datemes!" "$dirrunscript/$tfsc/remote-temprunscript-cron"
      sed -i "s!путь-к-файлу!$dirrunscript/$tfsc/$tfsc!" "$dirrunscript/$tfsc/remote-temprunscript-cron"
      sed -i "s!путь-к-каталогускрипта!$dirrunscript/$tfsc!g" "$dirrunscript/$tfsc/remote-temprunscript-cron"
      sed -i "s!путь-к-задачеcron!/etc/cron.d/temprunscript-$tfsc!" "$dirrunscript/$tfsc/remote-temprunscript-cron"

      #Копирование cron задачи в каталог задач cron
      if [[ "$sutype" = "sudo" ]]; then
        openssl enc -base64 -d -aes-256-cbc -iter $oiter -pass pass:$(sha256sum "$dirrunscript/$tfsc/$tfsc" | cut -d ' ' -f 1) <<<"$lpas" 2>/dev/null | sudo -S --prompt="" cp -f -v "$dirrunscript/$tfsc/remote-temprunscript-cron" "/etc/cron.d/temprunscript-$tfsc"
      elif [[ "$sutype" = "root" ]]; then
        cp -f -v "$dirrunscript/$tfsc/remote-temprunscript-cron" "/etc/cron.d/temprunscript-$tfsc"
      fi

      if [[ -f "/etc/cron.d/temprunscript-$tfsc" ]]; then
        echo -e "\nЗадача cron успешно создана\n"

        if [[ "$sutype" = "sudo" ]]; then
          openssl enc -base64 -d -aes-256-cbc -iter $oiter -pass pass:$(sha256sum "$dirrunscript/$tfsc/$tfsc" | cut -d ' ' -f 1) <<<"$lpas" 2>/dev/null | sudo -S --prompt="" chmod 600 "/etc/cron.d/temprunscript-$tfsc"
        elif [[ "$sutype" = "root" ]]; then
          chmod 600 "/etc/cron.d/temprunscript-$tfsc"
        fi

        exit 0
      else
        echo -e "\nНе удалось создать задачу cron\n"
        remove_temp_files
        exit 1
      fi

    else
      echo -e "\nНе удалось определить значения даты или времени\n"
      remove_temp_files
      exit 1
    fi
  }

  #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием
  if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
    debug=1
    set +x
  fi

  #Запуск назначенного типа выполения
  eval "$typers && exit 0 || exit 1"
  [[ $debug == 1 ]] && set -x && unset debug
else
  echo -e "\nФайл не найден или отсутствует доступ к каталогу на удаленном устройстве\n"
  exit 1
fi
