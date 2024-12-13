#!/bin/bash

#Условие для проверки
check_path='^[A-Za-zА-Яа-я0-9(),./@_[:space:]-]+$'

#Переменные цветов
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
NoColor='\033[0m'

#Проверка полного пути запускаемого скрипта на допустимые символы
if ! [[ "$(realpath "$0")" =~ $check_path ]]; then
  echo -e "\n${RED}Путь к запускаемому скрипту содержит запрещенные символы.

Текущий путь: $(realpath "$0") $NoColor"
  exit 1
else
  #Запись пути к каталогу в переменную (каталог с файлом скрипта)
  dir_runscript="$(dirname "$(realpath "$0")")"
fi

#Выставить рекурсивно права 700 на каталог скрипта
chmod -R 700 "$dir_runscript"

#Проверка существования, хеш-суммы и подключение файла с функциями
if [[ -f "$dir_runscript/func.sh" ]]; then

  if [[ "$(sha1sum "$dir_runscript/func.sh" | cut -d ' ' -f 1)" = "2a0afaa94249bd581a50067a07dd095066601f9f" ]]; then
    source func.sh
  else
    echo -e "\n${RED}Хеш-сумма файла func.sh не совпадает. Файл поврежден или не соответствует версии скрипта. $NoColor"
    exit 1
  fi
else
  echo -e "\n${RED}Не найден файл func.sh $NoColor"
  exit 1
fi

#Создание необходимых каталогов
mkdir -p "$dir_logs" "$dir_temp" "$dir_conf" "$dir_conf/fileshosts" "$dir_sendfunc" "$dir_runscript/files" "$dir_runscript/scripts"

#Массив с путями к файлам для проверки на существование
list_value_check=("$dir_runscript/remote-runprecommand.sh|file" "$dir_conf/sssc.conf|file" "$dir_conf/screenrc.conf|file" "$dir_runscript/remote-temprunscript-cron|file")

#Тип проверки значений
check_type="existence"

#Сохранять значения не прошедшие контроль в отдельный массив list_check_files_error для последующего использования (для включения присвоить значение 1)
save_error_listcheck="0"

#Проверка списка значений
check_list_values

#Если статус проверки не равен 0, то прервать выполнение скрипта
if [[ "$status_check" -ne "0" ]]; then
  exit 1
fi

#Массив с путями к файлам, их хеш-суммы и типом хеш-суммы
list_value_check=("$dir_runscript/remote-runprecommand.sh|b7fa53b6ee64080fc8c2d1bc598200b78051b5a8|sha1sum" "$dir_runscript/remote-temprunscript-cron|17da2665a57041bd2c3fd931748e023608d82521|sha1sum")

check_type="hashfile"

save_error_listcheck="0"

check_list_values

if [[ "$status_check" -ne "0" ]]; then
  exit 1
fi

#Список исполняемых файлов для проверки наличия в системе (имена с условием 'или' прописывается через вертикальную черту, например, 'tmux|screen')
list_value_check=('nmap' 'sshpass' 'gpg2' 'awk' 'sed' 'grep' 'tmux|screen' 'zenity' 'ssh' 'scp|rsync' 'ls' 'cut' 'rev' 'cat')

check_type="execfiles"

save_error_listcheck="0"

check_list_values

if [[ "$status_check" -ne "0" ]]; then
  echo -e "\nПроверка наличия исполняемых файлов не пройдена"
  infmsg="Выполнить проверку и установку необходимых пакетов? [y/n]: "
  errmsg="Установка пакетов пропущена. Выполните установку необходимых пакетов, содержащих указанные исполняемые файлы, самостоятельно."
  yes_or_no

  if [[ "$ynaction" = "yes" ]]; then
    #Массив имен пакетов (имена с условием 'или' прописывается через вертикальную черту, например, 'gnupg2|gnupg2-gostcrypto')
    list_names_pkg=('nmap' 'sshpass' 'gnupg2|gnupg2-gostcrypto' 'gawk' 'sed' 'grep' 'tmux' 'screen' 'zenity' 'openssh-client|openssh-clients' 'rsync')

    #Переменной select_package_management можно заранее присвоить имя используемой системы управления из доступных для использования
    #select_package_management=""

    #Объявив переменную select_first_value со значением 1, будет выбран первый найденный пакет для установки (По умолчанию при нахождении нескольких доступных для установки пакетов из списка с условием 'или', будет показан список для выбора одного пакета)
    #select_first_value=""

    #Переменная force_yesorno_install отвечает за принудительный ответ да или нет перед установкой пакетов (0 - ответить нет, 1 - ответить да. Если переменная не определена или имеет любое другое значение, то будет выдан запрос об установке)
    #force_yesorno_install=""

    #Поиск не установленных пакетов и установка в случае согласия пользователя
    install_pkg

    echo -e "${YELLOW}\nПерезапустите скрипт $NoColor"
    exit 1
  else
    exit 1
  fi
fi

#Проверка наличия секций настроек в конфигурационном файле
if [[ "$(cat "$dir_conf/sssc.conf" | grep '^\[.*\]$' | wc -l)" -gt "0" ]]; then

  #Проверка имени секций настроек на допустимые символы
  if [[ "$(grep -Ev '^[A-Za-zА-Яа-я0-9(),.@_[:space:]-]+$' <<<"$(cat "$dir_conf/sssc.conf" | grep '^\[.*\]$' | awk -F'[][]' '{print $2}' | sed '1s/^/---\n/' | sed '$a---')" | wc -l)" -gt "0" ]]; then
    echo -e "\n${RED}В файле sssc.conf присутствуют имена секций с запрещенными символами или пустым наименованием.$NoColor"
    exit 1
  fi

else
  echo -e "\n${RED}Не обнаружено секций с настройками в файле sssc.conf$NoColor"
  exit 1
fi

#Определение имени используемой секции настроек из параметра usesection
use_section_settings="$(cat "$dir_conf/sssc.conf" | head -1 | grep '^usesection=' | cut -d '=' -f 2)"

#Считывание в массив параметров запуска
value_arg_runscript=("$@")

#Если количество переданных параметров больше 0, то запускается формирование команды запуска функции.
if [[ "${#value_arg_runscript[@]}" -gt "0" ]]; then
  cmd_consolerun=''
  let num_transferred_values=0
  let num_transferred_param=0
  let use_us_param=0

  #Запуск функции help_run, обнуление переменных и завершение выполнения скрипта в случае ошибки
  function err_help_run {
    help_run

    unset use_section_settings
    unset value_arg_runscript
    unset cmd_consolerun
    unset num_transferred_param
    unset num_transferred_values
    unset use_us_param
    exit 1
  }

  #Перебор переданных параметров и значений
  for ((i = 0; i < ${#value_arg_runscript[@]}; i++)); do

    #Обнаружение значений
    if [[ -z "$(echo ${value_arg_runscript[$i]} | grep '^-')" ]]; then

      if [[ "$num_transferred_param" -eq "0" ]] && [[ "$num_transferred_values" -eq "0" ]]; then
        cmd_consolerun="\"${value_arg_runscript[$i]}\""
      else
        cmd_consolerun="$cmd_consolerun \"${value_arg_runscript[$i]}\""
      fi
      let num_transferred_values+=1
    else
      #Обнаружение параметра -us
      if [[ -n "$(echo ${value_arg_runscript[$i]} | grep '^-us$')" ]]; then

        #Если обнаружен параметр -us, то выполняем проверку имени секции настроек, присваиваем значение переменной и выполняем функцию проверки/считывания настроек. Также присваиваем use_us_param значение 1.
        if [[ "${value_arg_runscript[$i + 1]}" =~ $check_namesettings ]]; then
          use_section_settings="${value_arg_runscript[$i + 1]}"

          echo -e "\nВ команде указан параметр секции настроек. Запущена проверка и считывание настроек\n"

          check_or_select_use_section_settings
          let i+=1
          let use_us_param=1
        else
          let i+=1
          echo "Указанное имя секции в параметре -us пустое или не соответствует условию"
        fi
      #Обнаружение параметра -help
      elif [[ -n "$(echo ${value_arg_runscript[$i]} | grep '^-help$')" ]]; then
        #Если обнаружен параметр -help, то показываем справку и завершаем выполнение скрипта
        err_help_run

      #Обнаружение перечисленных в условии параметров
      elif [[ -n "$(echo ${value_arg_runscript[$i]} | grep -E '^-hf$|^-hn$|^-sp$|^-fes$|^-m$')" ]]; then

        if [[ "$num_transferred_param" -eq "0" ]] && [[ "$num_transferred_values" -eq "0" ]]; then
          cmd_consolerun="${value_arg_runscript[$i]}"
        else
          cmd_consolerun="$cmd_consolerun ${value_arg_runscript[$i]}"
        fi
        let num_transferred_param+=1
      else
        echo -e "\nВ строке запуска присутствуют недопустимые параметры\n"

        err_help_run
      fi
    fi
  done

  #Если количество значений и параметров больше нуля, то продолжаем
  if [[ "$num_transferred_param" -gt "0" ]] && [[ "$num_transferred_values" -gt "0" ]]; then

    #Если use_us_param не равен 1, то запускаем считывание настроек
    if [[ "$use_us_param" -ne "1" ]]; then
      check_or_select_use_section_settings
    fi

    eval "consolerun $cmd_consolerun"

    unset value_arg_runscript
    unset cmd_consolerun
    unset num_transferred_param
    unset num_transferred_values
    unset use_us_param
  else
    echo -e "\nКоличество переданных параметров ($num_transferred_param) или значений ($num_transferred_values) равно нулю.\n"

    err_help_run
  fi
else
  check_or_select_use_section_settings
fi

#Дополнительные действия, если выбран пользователь root
if [[ "$logname" = "root" ]]; then
  #Присваиваем типу повышения прав значение root
  sutype="root"
fi

#Вывод значений настроек
echo -e "\nКаталог скриптов на локальном ПК: ${GREEN}$dir_scripts $NoColor
Каталог с дополнительными файлами для выбора при отправке: ${GREEN}$dir_files_send $NoColor
Файл со списком версий выполненных скриптов на удаленном ПК: ${GREEN}$path_exec_script_version $NoColor
Тип повышения прав: ${GREEN}$sutype $NoColor
Тип многооконного терминала (Рекомендуется tmux): ${GREEN}$typeterminalmultiplexer $NoColor
Тип отправки файлов (Рекомендуется rsync): ${GREEN}$typesendfiles $NoColor
Пропуск запроса на внесение изменений в переменные отправляемого скрипта: ${GREEN}$skipchangescriptfile $NoColor
Логин: ${GREEN}$logname $NoColor
Количество потоков рассылки: ${GREEN}$multisend $NoColor
Таймаут на подключение к ПК по SSH: ${GREEN}$sshtimeout $NoColor
Номер SSH порта: ${GREEN}$numportssh $NoColor
Тип SSH подключения (Рекомендуется подключение по ключу): ${GREEN}$sshtypecon $NoColor
Путь до файла закрытого ключа: ${GREEN}$sshkeyfile $NoColor
GPG файл с паролем: ${GREEN}$gpgfilepass $NoColor
Каталог на удаленном компьютере для передачи файлов: ${GREEN}$remotedirrunscript $NoColor
Группа в правах на конечный каталог: ${GREEN}$remotedirgroup $NoColor
Количество попыток обнаружения устройства в сети после перезагрузки: ${GREEN}$reboot_max_try_wait_devaice $NoColor
Время (в секундах) каждой попытки обнаружения устройства: ${GREEN}$reboot_time_wait_devaice $NoColor\n"

#Список массивов
list_names_massive=("listIgnoreInaccurate" "listIgnoreAccurate")

#Количество столбцов для вывода значений
let num_column_values=3

#Максимальное количество значений для вывода
let max_num_values=100

#Вывод значений массива столбцами
splitting_list_massive

echo "Версия SSH: $(ssh -V 2>&1 | sed 's/OpenSSH_\([0-9]*\+\.\+[0-9]*\).*/\1/')"

#Если скрипт запущен из терминала с переданными параметрами, то запускается подготовка файлов, иначе запускается интерактивное выполнение
if [[ "$type_run_sssc" = "console" ]]; then
  initialsetup

  #Если отправка на все доступные устройства по файлу хостов, то запускается поиск устройств, иначе запускается разбивка списка устройств на количество потоков
  if [[ "$typesend" = "sshmultisend" ]]; then
    create_listip
  elif [[ "$typesend" = "sshonesend" ]]; then
    splitting_list_into_parts
  fi

  #Если список устройств не пуст, то запускаем отправку
  if [[ "${#list_ipall[@]}" -gt "0" ]]; then
    prerunsend
  else
    echo -e "${RED}Не обнаружено устройств в сети$NoColor"
  fi
else
  list_param_send_script=()

  while true; do
    echo ""

    #Запуск поиска доступных скриптов
    create_list_scripts

    #Если список скриптов не пуст, то запускаем выбор
    if [[ "${#list_scripts[@]}" -gt "0" ]]; then
      PS3="Введите номер: "
      COLUMNS=1

      #Показ информации о дополнительных командах, если есть выбранные для отправки скрипты
      if [[ "${#list_param_send_script[@]}" -gt "0" ]]; then
        echo -e "Выбрано скриптов для отправки: ${GREEN}${#list_param_send_script[@]} $NoColor
Для просмотра параметров отправки выбранных скриптов введите ${GREEN}999999 $NoColor
Для отчистки списка отправляемых скриптов введите ${GREEN}0 $NoColor

"
      fi

      select scripts in "${namescripts[@]}"; do

        #Если введенное значение является числом, то продолжаем
        if [[ "$REPLY" =~ $check_num ]]; then

          #Выполнить блок кода в зависимости от введенного значения
          if [[ "$REPLY" -eq "0" ]]; then

            infmsg="Вы хотите отчистить список выбранных для отправки скриптов? [y/n]: "
            errmsg="Возврат в меню выбора"
            yes_or_no

            if [[ "$ynaction" = "yes" ]]; then
              list_param_send_script=()
            fi
          elif [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "${#list_scripts[@]}" ]]; then
            echo -e "\nВыбранное действие: $scripts"
            infmsg="Вы хотите продолжить? [y/n]: "
            errmsg="Возврат в меню выбора"
            yes_or_no

            if [[ "$ynaction" = "yes" ]]; then
              let numscript=$REPLY-1

              presendscript
            fi
          elif [[ "$REPLY" -eq "999999" ]]; then
            echo -e "\nВыбрано скриптов для отправки: ${#list_param_send_script[@]}"

            if [[ "${#list_param_send_script[@]}" -gt "0" ]]; then

              for ((nlpss = 0; nlpss < ${#list_param_send_script[@]}; nlpss++)); do
                echo ""
                echo -e "Имя отправляемого скрипта № $(expr $nlpss + 1): ${YELLOW}$(echo "${list_param_send_script[$nlpss]}" | cut -d ':' -f 1) $NoColor"
                echo -e "Дополнительный каталог файлов для отправки: ${YELLOW}$(echo "${list_param_send_script[$nlpss]}" | cut -d ':' -f 2) $NoColor"
                echo -e "Тип выполнения скрипта: ${YELLOW}$(echo "${list_param_send_script[$nlpss]}" | cut -d ':' -f 3) $NoColor"
                echo -e "Перезагрузка устройства после выполнения: ${YELLOW} $([[ "$(echo "${list_param_send_script[$nlpss]}" | cut -d ':' -f 4)" -eq "1" ]] && echo "Выполняется" || echo "Не выполняется") $NoColor"
                echo -e "Проверка выполненной ранее версии скрипта: ${YELLOW} $([[ "$(echo "${list_param_send_script[$nlpss]}" | cut -d ':' -f 5)" -eq "1" ]] && echo "Выполняется" || echo "Не выполняется") $NoColor"
              done
              unset nlpss
            fi
          fi
        fi
        unset scripts
        break
      done
    fi
  done
fi
