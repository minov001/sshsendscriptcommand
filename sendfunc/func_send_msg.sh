#!/bin/bash

#Условия для проверки
check_num='^[0-9]+$'
check_login_or_group='^[A-Za-zА-Яа-я0-9@._-]+$'
check_path='^[A-Za-zА-Яа-я0-9(),./@_[:space:]-]+$'

IFS=$'\n'

#Поиск всех активных пользователей
function search_active_users {
  echo -e "\nПоиск активных пользователей\n"
  unset activeusername
  unset rdpuser

  #Формирование списка активных пользователей из вывода who -u (уникальные записи)
  if [[ "$(who -u | grep -v pts | awk '{print $1}' | sort -u | grep -Ev '^$' | wc -l)" -gt "0" ]]; then
    readarray -d ';' -t activeusername < <(who -u | grep -v pts | awk '{print $1}' | sort -u | grep -Ev '^$' | tr '\n' ';')
  fi

  #Определение номера процесса xrdp-sesman
  sesman_pid=$(ps --no-header -o ppid,pid -C xrdp-sesman | awk '$1==1 {print $2}')

  #Если номер найден, то ищем номера подчиненных процессов
  if [[ "$sesman_pid" =~ $check_num ]]; then
    sesman_children=($(ps --no-header -o pid --ppid "$sesman_pid" | sed 's/[[:space:]]//g'))

    #Продолжаем, если найдены номера подчиненных процессов
    if [[ "${#sesman_children[@]}" -gt "0" ]]; then

      #Определяем пользователя подключившегося по rdp
      for ((num_sc = 0; num_sc < ${#sesman_children[@]}; num_sc++)); do
        rdpuser="$(ps --no-header -o user --ppid "${sesman_children[$num_sc]}" | sed -n '2p')"

        if [[ -n "$rdpuser" ]]; then
          #Если массив активных пользователей пуст, то добавляем пользователя в массив, если же массив не пуст, то выполняем проверку на наличие данного пользователя в массиве
          if [[ ${#activeusername[@]} -eq "0" ]]; then
            activeusername=("$rdpuser")
          elif [[ ${#activeusername[@]} -gt "0" ]]; then
            if [[ "$(sed 's/^ //' <<<"${activeusername[@]/%/$'\n'}" | grep "^$rdpuser$" | wc -l)" -eq "0" ]]; then
              activeusername=("${activeusername[@]}" "$rdpuser")
            fi
          fi
        fi
      done
    fi
  fi

  unset rdpuser

  echo -e "Найдено активных пользователей: ${#activeusername[@]}\n"
}

#Поиск значений переменных окружения пользователя
function search_env_value {
  if ! [[ "$(id -u)" -eq "0" ]]; then
    echo -e "\nТребуются права root для поиска значений переменных окружения\n"
    return 1
  fi

  #Поиск всех активных пользователей, если массив пуст
  if [[ "${#activeusername[@]}" -eq "0" ]]; then
    search_active_users
  fi

  #Продолжаем, если список не пуст
  if [[ "${#activeusername[@]}" -gt "0" ]]; then

    #Если список процессов пуст, то задать фиксированный список
    if [[ ${#processname[@]} -eq "0" ]]; then
      #Имя процессов, по которым можно определить DISPLAY, DBUS_SESSION_BUS_ADDRESS и XAUTHORITY. Необходимо в случаях, если команда who -u не выдаст нужные pid (например pid может быть неверным или пользователь подключен через xrdp, тогда его не будет в выводе команды who -u)
      processname=("astra-event-watcher" "fly-wm" "startplasma-wayland" "startplasma-x11" "xfce4-session" "openbox" "mate-session" "lxqt-session" "lxsession" "x-session-manager" "gnome-software" "cinnamon-session")
    fi

    unset pidsession
    unset templistpid

    #Определение PID процессов принадлежащих пользователю через who -u
    if [[ "$(who -u | grep -w "${activeusername[$num_au]}" | awk '{print $6}' | sort -u | grep -E '^[0-9]+$' | wc -l)" -gt "0" ]]; then
      readarray -d ';' -t pidsession < <(who -u | grep -w "${activeusername[$num_au]}" | awk '{print $6}' | sort -u | grep -E '^[0-9]+$' | tr '\n' ';')
    fi

    #Перебор массива с именами процессов
    for ((num_proc_name = 0; num_proc_name < ${#processname[@]}; num_proc_name++)); do
      #Определение PID указанных процессов принадлежащих пользователю
      templistpid=($(pgrep -f "${processname[$num_proc_name]}" -u "${activeusername[$num_au]}"))

      #Если PID найдены, то перебор массива
      for ((num_pid_proc = 0; num_pid_proc < ${#templistpid[@]}; num_pid_proc++)); do

        #Продолжаем, если значение является числом
        if [[ "${templistpid[$num_pid_proc]}" =~ $check_num ]]; then

          #Cверка уникальности PID и добавление значения к основному массиву
          if [[ "$(sed 's/^ //' <<<"${pidsession[@]/%/$'\n'}" | grep "^${templistpid[$num_pid_proc]}$" | wc -l)" -eq "0" ]]; then
            pidsession=("${pidsession[@]}" "${templistpid[$num_pid_proc]}")
          fi
        fi
      done
    done

    #Присвоить, если список переменных окружения не определен
    if [[ ${#list_search_env[@]} -eq "0" ]]; then
      list_search_env=('DBUS_SESSION_BUS_ADDRESS' 'XAUTHORITY')
    fi

    #Инициализация пустых массивов
    for ((numenv = 0; numenv < ${#list_search_env[@]}; numenv++)); do
      eval "env_${list_search_env[$numenv]}=()"
    done

    env_DISPLAY=()

    #Перебор массива значений PID.
    for ((numcicle = 0; numcicle < ${#pidsession[@]}; numcicle++)); do
      unset temp_num_disp

      #Получаем значение дисплея
      temp_num_disp="$(cat "/proc/${pidsession[$numcicle]}/environ" | tr '\0' '\n' | sed -nr "{ :l /^DISPLAY[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}")"

      #Продолжаем, если значение не пусто
      if [[ -n "$temp_num_disp" ]]; then

        if [[ "$(sed 's/^ //' <<<"${env_DISPLAY[@]/%/$'\n'}" | grep "^$temp_num_disp$" | wc -l)" -eq "0" ]]; then
          #Добавляем значение к массиву
          env_DISPLAY[${#env_DISPLAY[@]}]="$temp_num_disp"

          #Перебор указанного списка переменных окружения
          for ((numenv = 0; numenv < ${#list_search_env[@]}; numenv++)); do

            #Запись значения в массив
            eval "env_${list_search_env[$numenv]}[\${#env_${list_search_env[$numenv]}[@]}]=\"$(cat "/proc/${pidsession[$numcicle]}/environ" | tr '\0' '\n' | sed -nr "{ :l /^${list_search_env[$numenv]}[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}")\""
          done
        fi
      fi
    done

    unset pidsession
    unset templistpid

  #         echo -e "\nПользователь: ${activeusername[$num_au]}"
  #         echo -e "\nЗначений DISPLAY: ${#env_DISPLAY[@]}"
  #         echo "Значения DISPLAY:
  # $(echo "${env_DISPLAY[@]/%/$'\n'}" | sed 's/^ //')"
  #         echo -e "\nЗначений DBUS_SESSION_BUS_ADDRESS: ${#env_DBUS_SESSION_BUS_ADDRESS[@]}"
  #         echo "Значения DBUS_SESSION_BUS_ADDRESS:
  # $(echo "${env_DBUS_SESSION_BUS_ADDRESS[@]/%/$'\n'}" | sed 's/^ //')"
  #         echo -e "\nЗначений XAUTHORITY: ${#env_XAUTHORITY[@]}"
  #         echo "Значения XAUTHORITY:
  # $(echo "${env_XAUTHORITY[@]/%/$'\n'}" | sed 's/^ //')"
  fi
}

#Показать сообщение активным пользователям
function send_message_active_users {
  if ! [[ "$send_notifysend" =~ $check_num ]]; then
    echo -e "\nЗначение send_notifysend не является числом. Присвоено значение 0."
    let send_notifysend=0
  fi

  if ! [[ "$notifysend_expiretime" =~ $check_num ]]; then
    echo -e "\nЗначение notifysend_expiretime не является числом. Присвоено значение 10000."
    let notifysend_expiretime=10000
  fi

  if ! [[ "$send_yad" =~ $check_num ]]; then
    echo -e "\nЗначение send_yad не является числом. Присвоено значение 0."
    let send_yad=0
  fi

  if ! [[ "$send_flydialog" =~ $check_num ]]; then
    echo -e "\nЗначение send_flydialog не является числом. Присвоено значение 0."
    let send_flydialog=0
  fi

  if ! [[ "$send_zenity" =~ $check_num ]]; then
    echo -e "\nЗначение send_zenity не является числом. Присвоено значение 0."
    let send_zenity=0
  fi

  if ! [[ "$send_msg_use_root" =~ $check_num ]]; then
    echo -e "\nЗначение send_msg_use_root не является числом. Присвоено значение 0."
    let send_msg_use_root=0
  fi

  if [[ "$send_notifysend" -eq "1" ]] || [[ "$send_yad" -eq "1" ]] || [[ "$send_flydialog" -eq "1" ]] || [[ "$send_zenity" -eq "1" ]]; then

    if ! [[ "$(id -u)" -eq "0" ]]; then
      echo -e "\nТребуются права root для вывода сообщения\n"
      return 1
    fi

    #Поиск всех активных пользователей, если массив пуст
    if [[ "${#activeusername[@]}" -eq "0" ]]; then
      search_active_users
    else
      echo -e "\nИспользуется подготовленный список пользователей"
    fi

    #Продолжаем, если список не пуст
    if [[ "${#activeusername[@]}" -gt "0" ]]; then

      #Создаем каталог для файлов сообщений и выставляем права
      msgdir="/tmp/.sendmsg"
      mkdir -p "$msgdir"
      chmod 755 "$msgdir"

      #Инициализируем пустой массив
      msgfile=()

      #Сохранение содержимого msgtext в файлы, если тип отправки 'text'
      if [[ "$typesend" = "text" ]]; then

        #Продолжаем, если массив не пуст
        if [[ "${#msgtext[@]}" -gt "0" ]]; then

          #Перебор массива msgtext
          for ((num_msgtext = 0; num_msgtext < ${#msgtext[@]}; num_msgtext++)); do

            #Формуруем путь к файлу в котором будет сообщение
            msgfile[${#msgfile[@]}]="$msgdir/.msg-$(date +"%Y%m%d%H%M%S")-$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 3)"

            #Перенаправляем вывод в файл
            echo "${msgtext[$num_msgtext]}" >"${msgfile[${#msgfile[@]} - 1]}"

            #Выставляем права на файл
            chmod 644 "${msgfile[${#msgfile[@]} - 1]}"
          done
        else
          echo -e "\nМассив msgtext пуст. Нет текста для вывода"
          return 1
        fi
      fi

      #Если тип отправки file
      if [[ "$typesend" = "file" ]]; then

        #Продолжаем, если переменная dirfiles не пуста и каталог существует
        if [[ -n "$dirfiles" ]] && [[ -d "$dirfiles" ]]; then

          cd "$dirfiles"
          #Переходим в каталог и ищем файлы .smsg. Если файлы найдены, то продолжаем
          if [[ "$(ls -1 | grep '.smsg' | wc -l)" -gt "0" ]]; then

            #Перебор файлов .smsg
            for file_msg in $(ls -1 | grep '.smsg'); do

              #Формуруем путь к файлу в котором будет сообщение
              msgfile[${#msgfile[@]}]="$msgdir/.msg-$(date +"%Y%m%d%H%M%S")-$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 3)"

              #Копируем файл
              cp -f -v "$dirfiles/$file_msg" "${msgfile[${#msgfile[@]} - 1]}"

              #Назначаем права
              chmod 644 "${msgfile[${#msgfile[@]} - 1]}"
            done
            unset file_msg
          else
            echo -e "\nФайлы .smsg не найдены"
            return 1
          fi
        else
          echo -e "\nПеременная dirfiles пуста (не был выбран каталог для отправки) или каталог не существует"
          return 1
        fi
      fi

      #Продолжаем, если список не пуст
      if [[ "${#msgfile[@]}" -gt "0" ]]; then

        headertext_generate="0"

        #Перебор списка пользователей
        for ((num_au = 0; num_au < ${#activeusername[@]}; num_au++)); do

          #Запуск поиска необходимых переменных окружения
          search_env_value

          #Продолжаем, если список номеров дисплея не пуст
          if [[ "${#env_DISPLAY[@]}" -gt "0" ]]; then

            #Перебор массива номеров дисплея
            for ((numenv = 0; numenv < ${#env_DISPLAY[@]}; numenv++)); do

              #Если headertext пуст или включена генерация, то задать значение
              if [[ -z "$headertext" ]] || [[ "$headertext_generate" -eq "1" ]]; then
                headertext="Уведомление $(date +"%d.%m.%Y-%H:%M")"
                headertext_generate="1"
              fi

              echo ""
              echo "Найден пользователь ${activeusername[$num_au]} - ${env_DISPLAY[$numenv]}"

              #Если отправка через notify-send
              if [[ "$send_notifysend" -eq "1" ]]; then

                if [[ -n "$(which notify-send 2>/dev/null)" ]]; then

                  if [[ -n "${env_DISPLAY[$numenv]}" && -n "${env_DBUS_SESSION_BUS_ADDRESS[$numenv]}" && -n "${env_XAUTHORITY[$numenv]}" ]]; then

                    for ((num_msg = 0; num_msg < ${#msgfile[@]}; num_msg++)); do
                      cmd_run_send_msg="systemd-run $([[ "$send_msg_use_root" -eq "0" ]] && echo "--uid=\"${activeusername[$num_au]}\" ")/bin/bash -c \"XAUTHORITY='${env_XAUTHORITY[$numenv]}' DBUS_SESSION_BUS_ADDRESS='${env_DBUS_SESSION_BUS_ADDRESS[$numenv]}' DISPLAY='${env_DISPLAY[$numenv]}' notify-send -t $notifysend_expiretime '$(sed 's/\\/\\\\/g;s/"/\\"/g;s/`/\\`/g' <<<"$headertext" | sed "s/'/\'\\\\\\\'\'/g")' '$(cat ${msgfile[$num_msg]} | sed 's/\\/\\\\\\/g;s/&/\\\&/g;s/%/\\%/g;s/"/\\"/g;s/`/\\`/g;s/<//g' | sed "s/'/\'\\\\\\\'\'/g")'\""

                      eval "$cmd_run_send_msg"
                    done
                  fi
                else
                  echo -e "\nnotify-send не найден"
                fi
              fi

              #Если отправка через yad
              if [[ "$send_yad" -eq "1" ]]; then

                if [[ -n "$(which yad 2>/dev/null)" ]]; then

                  if [[ -n "${env_DISPLAY[$numenv]}" && -n "${env_XAUTHORITY[$numenv]}" ]]; then

                    for ((num_msg = 0; num_msg < ${#msgfile[@]}; num_msg++)); do
                      cmd_run_send_msg="systemd-run $([[ "$send_msg_use_root" -eq "0" ]] && echo "--uid=\"${activeusername[$num_au]}\" ")/bin/bash -c \"XAUTHORITY='${env_XAUTHORITY[$numenv]}' DISPLAY='${env_DISPLAY[$numenv]}' yad --no-escape --on-top --center --text-info --button=OK:0 --filename='${msgfile[$num_msg]}' --title='$(sed 's/\\/\\\\/g;s/"/\\"/g;s/`/\\`/g' <<<"$headertext" | sed "s/'/\'\\\\\\\'\'/g")' --wrap --width 350 --height 300 --show-uri --window-icon=''\""

                      eval "$cmd_run_send_msg"
                    done
                  fi
                else
                  echo -e "\nyad не найден"
                fi
              fi

              #Если отправка через fly-dialog
              if [[ "$send_flydialog" -eq "1" ]]; then

                if [[ -n "$(which fly-dialog 2>/dev/null)" ]]; then

                  if [[ -n "${env_DISPLAY[$numenv]}" && -n "${env_XAUTHORITY[$numenv]}" ]]; then

                    for ((num_msg = 0; num_msg < ${#msgfile[@]}; num_msg++)); do
                      cmd_run_send_msg="systemd-run $([[ "$send_msg_use_root" -eq "0" ]] && echo "--uid=\"${activeusername[$num_au]}\" ")/bin/bash -c \"XAUTHORITY='${env_XAUTHORITY[$numenv]}' DISPLAY='${env_DISPLAY[$numenv]}' fly-dialog --caption '$(sed 's/\\/\\\\/g;s/"/\\"/g;s/`/\\`/g' <<<"$headertext" | sed "s/'/\'\\\\\\\'\'/g")' --textbox '${msgfile[$num_msg]}'\""

                      eval "$cmd_run_send_msg"
                    done
                  fi
                else
                  echo -e "\nfly-dialog не найден"
                fi
              fi

              #Если отправка через zenity
              if [[ "$send_zenity" -eq "1" ]]; then

                if [[ -n "$(which zenity 2>/dev/null)" ]]; then

                  if [[ -n "${env_DISPLAY[$numenv]}" && -n "${env_XAUTHORITY[$numenv]}" ]]; then

                    for ((num_msg = 0; num_msg < ${#msgfile[@]}; num_msg++)); do
                      cmd_run_send_msg="systemd-run $([[ "$send_msg_use_root" -eq "0" ]] && echo "--uid=\"${activeusername[$num_au]}\" ")/bin/bash -c \"XAUTHORITY='${env_XAUTHORITY[$numenv]}' DISPLAY='${env_DISPLAY[$numenv]}' zenity --text-info --filename='${msgfile[$num_msg]}' --title='$(sed 's/\\/\\\\/g;s/"/\\"/g;s/`/\\`/g' <<<"$headertext" | sed "s/'/\'\\\\\\\'\'/g")'\""

                      eval "$cmd_run_send_msg"
                    done
                  fi
                else
                  echo -e "\nzenity не найден"
                fi
              fi
            done
          else
            echo -e "\nНе обнаружено пользовательских дисплеев у пользователя ${activeusername[$num_au]}"
          fi
        done
      fi
    else
      echo -e "\nСписок пользователей пуст. Нет активных пользователей или не заполнен массив пользователей (в случае показа сообщения определенным пользователям)"
    fi
  else
    echo -e "\nВсе методы вывода сообщения отключены"
    return 1
  fi
}
