#!/bin/bash

script_current_version="2025013001"

#Каталог логов, каталог временных файлов, каталог конфигураций, каталог отправляемых функций
dir_logs="$dir_runscript/logs"
dir_temp="$dir_runscript/temp"
dir_conf="$dir_runscript/conf"
dir_sendfunc="$dir_runscript/sendfunc"

#Условия для проверки
check_num='^[0-9]+$'
check_login_or_group='^[A-Za-zА-Яа-я0-9@._-]+$'
check_hostname_or_ip='^[A-Za-zА-Яа-я0-9.-]+$'
check_path='^[A-Za-zА-Яа-я0-9(),./@_[:space:]-]+$'
check_namesettings='^[A-Za-zА-Яа-я0-9(),.@_[:space:]-]+$'

#Инициализация переменной типа запуска скрипта. Если скрипт запущен с параметрами и все проверки будут пройдены успешно, то данной переменной в дальнейшем присвоится значение console
type_run_sssc=""

IFS=$'\n'

#Переменные с цветами
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
NoColor='\033[0m'

#Функция с несколькими типами проверок: соответствие хеш-суммы; наличие в системе исполняемого файла; существование.
function check_list_values {
  #Массив в который будут сохранены значения с ошибкой при проверке, если включено сохранение
  list_check_files_error=()

  #Переменная со значением статуса проверки. По умолчанию присваивается значение 0. Оно будет изменено на 1, в случае любой ошибки
  status_check="0"

  #Если указан один из допустимых типов проверки, то продолжается выполнение
  if [[ "$check_type" = "hashfile" || "$check_type" = "execfiles" || "$check_type" = "existence" ]]; then

    #Если в массиве list_value_check есть значения, то продолжается выполнение
    if [[ "${#list_value_check[@]}" -gt "0" ]]; then

      #Цикл для перебора значений массива list_value_check
      for ((i = 0; i < ${#list_value_check[@]}; i++)); do

        #Проверка, что значение не пустое
        if [[ -n "${list_value_check[$i]}" ]]; then

          #Формируем новый массив из значения list_value_check[$i] с учетом разделителя '|'
          readarray -d '|' -t chekfiles < <(echo "${list_value_check[$i]}" | tr -d '\n')

          #Цикл для перебора значений массива chekfiles
          for ((j = 0; j < ${#chekfiles[@]}; j++)); do

            #Если проверяется существование исполняемого файла
            if [[ "$check_type" = "execfiles" ]]; then

              #Если исполняемый файл не найден и это последний круг цикла, то status_check присваивается значение 1 и выводится сообщение.
              #Если исполняемый файл обнаружен, то выход из цикла.
              if [[ -z "$(which "${chekfiles[j]}" 2>/dev/null)" ]]; then

                if [[ "$j" -eq "$(expr ${#chekfiles[@]} - 1)" ]]; then
                  echo "$(echo "${chekfiles[@]}" | sed 's/[[:space:]]/ или /g'): $(echo -e "${RED}Не найден$NoColor")"
                  status_check="1"

                  if [[ "$save_error_listcheck" -eq "1" ]]; then
                    create_list_check_files_error
                  fi
                fi
              else
                break
              fi

            #Если проверяется хеш-сумма файла
            elif [[ "$check_type" = "hashfile" ]]; then

              #Проверка значения пути к файлу на пустоту и допустимые символы
              if ! [[ "${chekfiles[0]}" =~ $check_path ]]; then
                echo "$(echo -e "${RED}В указанном элементе массива секция пути к файлу пуста или содержит недопустимые символы:$NoColor") ${list_value_check[$i]}"
                status_check="1"
                break
              fi

              #Проверка существует ли файл
              if [[ -f "${chekfiles[0]}" ]]; then

                #Проверка, существует ли второе значение в массиве (оно будет подставляться в проверку, как хеш-сумма)
                if [[ -n "${chekfiles[1]}" ]]; then

                  #Проверка, что третье значение массива (тип хеш-суммы) соответствует одному из условий
                  if [[ "${chekfiles[2]}" = "b2sum" || "${chekfiles[2]}" = "gostsum" || "${chekfiles[2]}" = "md5sum" || "${chekfiles[2]}" = "sha1sum" || "${chekfiles[2]}" = "sha224sum" || "${chekfiles[2]}" = "sha256sum" || "${chekfiles[2]}" = "sha384sum" || "${chekfiles[2]}" = "sha512sum" ]]; then

                    #Если хеш-сумма файла не совпадает, то выдается сообщение, status_check присваивается значение 1 и прерывается цикл
                    if [[ "$(${chekfiles[2]} "${chekfiles[0]}" | cut -d ' ' -f 1)" != "${chekfiles[1]}" ]]; then
                      echo "${chekfiles[0]} - $(echo -e "${RED}Хеш-сумма не совпадает.$NoColor")"
                      status_check="1"

                      if [[ "$save_error_listcheck" -eq "1" ]]; then
                        create_list_check_files_error
                      fi
                      break
                    else
                      break
                    fi

                  else

                    echo "${chekfiles[0]} - $(echo -e "${RED}Тип проверяемой хеш-суммы файла не соответствует допустимым значениям.$NoColor")"
                    status_check="1"

                    if [[ "$save_error_listcheck" -eq "1" ]]; then
                      create_list_check_files_error
                    fi
                    break
                  fi

                else
                  echo "${chekfiles[0]} - $(echo -e "${RED}У файла не задано проверяемое значение хеш-суммы.$NoColor")"
                  status_check="1"

                  if [[ "$save_error_listcheck" -eq "1" ]]; then
                    create_list_check_files_error
                  fi
                  break
                fi

              else
                echo "${chekfiles[0]} - $(echo -e "${RED}Файл не существует.$NoColor")"
                status_check="1"

                if [[ "$save_error_listcheck" -eq "1" ]]; then
                  create_list_check_files_error
                fi
                break
              fi

              #Если проверяется существование файла или каталога
            elif [[ "$check_type" = "existence" ]]; then

              #Проверка значения пути на пустоту и допустимые символы
              if ! [[ "${chekfiles[0]}" =~ $check_path ]]; then
                echo "$(echo -e "${RED}В указанном элементе массива секция пути пуста или содержит недопустимые символы:$NoColor") ${list_value_check[$i]}"
                status_check="1"
                break
              fi

              if [[ "${chekfiles[1]}" = "file" ]]; then

                if ! [[ -f "${chekfiles[0]}" ]]; then
                  echo "${chekfiles[0]} - $(echo -e "${RED}Файл не найден.$NoColor")"
                  status_check="1"

                  if [[ "$save_error_listcheck" -eq "1" ]]; then
                    create_list_check_files_error
                  fi
                  break
                else
                  break
                fi
              elif [[ "${chekfiles[1]}" = "catalog" ]]; then

                if ! [[ -d "${chekfiles[0]}" ]]; then
                  echo "${chekfiles[0]} - $(echo -e "${RED}Каталог не найден.$NoColor")"
                  status_check="1"

                  if [[ "$save_error_listcheck" -eq "1" ]]; then
                    create_list_check_files_error
                  fi
                  break
                else
                  break
                fi
              else
                echo "${chekfiles[0]} - $(echo -e "${RED}тип проверяемого значения не указан или не соответствует допустимым значениям.$NoColor")"
                status_check="1"

                if [[ "$save_error_listcheck" -eq "1" ]]; then
                  create_list_check_files_error
                fi
                break
              fi
            fi
          done
        else
          echo -e "${RED}Значение массива list_value_check номер $(expr $i + 1) пустое.$NoColor"
          status_check="1"
        fi
      done
    else
      echo -e "${RED}Нет значений для проверки.$NoColor"
      status_check="1"
    fi
  else
    echo -e "${RED}Тип проверки не указан или указан неверно.$NoColor"
    status_check="1"
  fi

  if [[ "$save_error_listcheck" -ne "1" ]]; then
    unset list_check_files_error
  fi

  unset save_error_listcheck
  unset check_type
  unset list_value_check
  unset chekfiles
}

#Создание списка с ошибкой проверки
function create_list_check_files_error {
  if [[ "$check_type" = "execfiles" ]]; then
    list_check_files_error[${#list_check_files_error[@]}]="${chekfiles[@]}"
  else
    list_check_files_error[${#list_check_files_error[@]}]="${chekfiles[0]}"
  fi
}

#Функция ответа Да/Нет
function yes_or_no {
  while true; do
    echo ""

    unset ynaction
    read -p "$infmsg" ynaction

    case "$ynaction" in
    [Yy])
      ynaction="yes"
      unset infmsg
      unset errmsg
      return 0
      ;;
    [Nn])
      echo -e "\n${YELLOW}$errmsg $NoColor\n"
      unset infmsg
      unset errmsg
      break
      ;;
    esac
  done
}

#Установка пакетов
function install_pkg {

  function unset_install_pkg_param {
    unset list_names_pkg
    unset list_package_management
    unset list_package_management_installed
    unset list_pkg_inst
    unset listpkgcontrol
    unset pkg_management_status
    unset pkg_noinst_and_notinrepo
    unset ynaction
    unset force_yesorno_install
    unset select_package_management
    unset num_value_massive
    unset repoupdatestatus
  }

  #Список поддерживаемых систем управления пакетами
  list_package_management=("apt" "apt-get" "dnf")

  #Если select_package_management пуст, то определяется список доступных систем управления пакетами
  if [[ -z "$select_package_management" ]]; then

    #Пустой массив в который будут записаны системы управления пакетами имеющиеся на устройстве
    list_package_management_installed=()

    echo -e "\nПроверка наличия систем управления пакетами"

    #Перебор списка list_package_management для нахождения имеющихся на устройстве систем управления пакетами
    for ((num_value_massive = 0; num_value_massive < ${#list_package_management[@]}; num_value_massive++)); do

      #Запись в переменную результата проверки существования исполняемого файла
      pkg_management_status="$(which "${list_package_management[$num_value_massive]}" 2>/dev/null)"

      echo -e "${list_package_management[$num_value_massive]}: $pkg_management_status $([[ -n "$pkg_management_status" ]] && echo -e "${GREEN}Найден $NoColor" || echo -e "${RED}Не найден $NoColor")"

      #Если исполняемый файл найден, то он добавляется в массив list_package_management_installed
      if [[ -n "$pkg_management_status" ]]; then

        list_package_management_installed[${#list_package_management_installed[@]}]="${list_package_management[$num_value_massive]}"

      fi
    done

    #Если в системе обнаружены поддерживаемые системы управления пакетами, то продолжается выполнение, иначе будет выдано сообщение и скрипт прервет работу
    if [[ "${#list_package_management_installed[@]}" -gt "0" ]]; then

      #Если найдена одна система управления пакетамии, то она автоматически будет выбрана, если найдено больше одной, то будет выбор какую необходимо использовать
      if [[ "${#list_package_management_installed[@]}" -eq "1" ]]; then
        select_package_management="${list_package_management_installed[0]}"
      elif [[ "${#list_package_management_installed[@]}" -gt "1" ]]; then
        echo -e "\nНайдено несколько поддерживаемых систем управления пакетами. Выберите какую необходимо использовать."

        while true; do
          PS3="Введите номер: "
          COLUMNS=1

          select listpkgcontrol in "${list_package_management_installed[@]}"; do

            if [[ "$REPLY" =~ $check_num ]]; then

              if [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "${#list_package_management_installed[@]}" ]]; then
                select_package_management="$listpkgcontrol"
                unset REPLY
                break 2
              fi
            fi
            break
          done
        done
      fi
    else
      echo -e "${RED}Не обнаружено подходящих систем управления для установки пакетов. Проверьте/Установите следующие пакеты самостоятельно: ${list_names_pkg[@]}
Наименования некоторых пакетов могут отличаться в разных системах$NoColor"
      unset_install_pkg_param
      exit 1
    fi
  else
    if [[ "$(grep -Eix "$select_package_management" <<<"$(echo "${list_package_management[@]/%/$'\n'}" | sed 's/^ //' | grep -v '^$')" | wc -l)" -gt "0" ]]; then

      if [[ -z "$(which "$select_package_management" 2>/dev/null)" ]]; then
        echo "$(echo -e "${RED}Указанная система управления пакетами не обнаружена:$NoColor") $select_package_management"
        unset_install_pkg_param
        exit 1
      fi
    else
      echo -e "${RED}Указанная система управления пакетами не поддерживается$NoColor"
      unset_install_pkg_param
      exit 1
    fi
  fi

  #Обновление кэша репозиториев
  repoupdatestatus="0"

  if [[ "$select_package_management" = "apt" ]]; then
    (sudo --prompt="Введите пароль для обновления кэша репозиториев: " apt update) && repoupdatestatus="1" || repoupdatestatus="0"
  fi

  if [[ "$select_package_management" = "apt-get" ]]; then
    (sudo --prompt="Введите пароль для обновления кэша репозиториев: " apt-get update) && repoupdatestatus="1" || repoupdatestatus="0"
  fi

  if [[ "$select_package_management" = "dnf" ]]; then
    (sudo --prompt="Введите пароль для обновления кэша репозиториев: " dnf makecache) && repoupdatestatus="1" || repoupdatestatus="0"
  fi

  #Если кэш репозиториев обновить не удалось, то завершаем выполнение
  if [[ "$repoupdatestatus" -eq "0" ]]; then
    echo -e "\n${YELLOW}Не удалось обновить кэш репозиториев$NoColor"
    unset_install_pkg_param
    exit 1
  elif [[ "$repoupdatestatus" -eq "1" ]]; then
    echo -e "\n${GREEN}Кэш репозиториев обновлен$NoColor\n"
  fi

  echo -e "Запуск проверки пакетов\n"

  #Запуск функции поиска не установленных пакетов, а также проверка есть ли неустановленный пакет в репозитории
  check_pkginst_status

  echo -e "Количество пакетов в списке: ${GREEN}${#list_names_pkg[@]} $NoColor
Количество установленных пакетов: ${GREEN}$(expr ${#list_names_pkg[@]} - ${#pkg_noinst_and_notinrepo[@]} - ${#list_pkg_inst[@]}) $NoColor
Количество не установленных и не найденных в репозитории пакетов: ${RED}${#pkg_noinst_and_notinrepo[@]} $NoColor
Количество не установленных, но найденных в репозитории пакетов: ${YELLOW}${#list_pkg_inst[@]} $NoColor\n"

  #Если есть пакеты, которые не установлены и не найдены в репозитории, то выдаст уведомление
  if [[ "${#pkg_noinst_and_notinrepo[@]}" -gt "0" ]]; then
    echo -e "${YELLOW}Указанные пакеты не установлены и не найдены в репозитории (установите их самостоятельно или подключите репозиторий с указанными пакетаими и перезапустите скрипт): ${pkg_noinst_and_notinrepo[@]} $NoColor"
  fi

  #Если найдены неустановленные пакеты, которые есть в репозитории, то продолжается выполнение
  if [[ "${#list_pkg_inst[@]}" -gt "0" ]]; then
    echo -e "\n${YELLOW}Будут установлены следующие пакеты: ${list_pkg_inst[@]} $NoColor"

    if [[ "$force_yesorno_install" =~ $check_num ]]; then
      if [[ "$force_yesorno_install" -eq "1" ]]; then
        ynaction="yes"
        echo -e "\nАвтоматическое продолжение установки согласно значению переменной force_yesorno_install\n"
      elif [[ "$force_yesorno_install" -ne "1" ]]; then
        ynaction="no"
        echo -e "\nАвтоматическое отклонение установки согласно значению переменной force_yesorno_install\n"
      fi
    else
      infmsg="Выполнить установку необходимых пакетов? [y/n]: "
      errmsg="Установка пакетов пропущена. Выполните установку необходимых пакетов самостоятельно."
      yes_or_no
    fi

    #Установка пакетов, если было дано согласие
    if [[ "$ynaction" = "yes" ]]; then

      if [[ "$select_package_management" = "apt" ]]; then
        sudo --prompt="Введите пароль для установки пакетов: " apt install ${list_pkg_inst[@]}
      fi

      if [[ "$select_package_management" = "apt-get" ]]; then
        sudo --prompt="Введите пароль для установки пакетов: " apt-get install ${list_pkg_inst[@]}
      fi

      if [[ "$select_package_management" = "dnf" ]]; then
        sudo --prompt="Введите пароль для установки пакетов: " dnf install ${list_pkg_inst[@]}
      fi

      echo -e "Запуск проверки пакетов\n"

      check_pkginst_status

      echo -e "Количество пакетов в списке: ${GREEN}${#list_names_pkg[@]} $NoColor
Количество установленных пакетов: ${GREEN}$(expr ${#list_names_pkg[@]} - ${#pkg_noinst_and_notinrepo[@]} - ${#list_pkg_inst[@]}) $NoColor
Количество не установленных и не найденных в репозитории пакетов: ${RED}${#pkg_noinst_and_notinrepo[@]} $NoColor
Количество не установленных, но найденных в репозитории пакетов: ${YELLOW}${#list_pkg_inst[@]} $NoColor\n"
    fi

    #Если в конце выполнения остаются неустановленные пакеты, то будет выведено сообщение и скрипт завершится
    if [[ "${#list_pkg_inst[@]}" -gt "0" ]] || [[ "${#pkg_noinst_and_notinrepo[@]}" -gt "0" ]]; then
      echo -e "${RED}Следующие пакеты не установлены: ${pkg_noinst_and_notinrepo[@]} ${list_pkg_inst[@]}
(Наименования некоторых пакетов могут отличаться в разных системах)$NoColor"
      unset_install_pkg_param
      exit 1
    fi
  fi

  unset_install_pkg_param
}

#Проверка статуса установки пакетов и поиск в репозитории не установленных пакетов
function check_pkginst_status {
  unset list_pkg_inst
  unset pkg_noinst_and_notinrepo
  unset temp_list_pkgnames
  unset list_pkg_insttemp
  unset existence_pkg_in_repo

  #Если в массиве list_names_pkg есть значения, то продолжается выполнение
  if [[ "${#list_names_pkg[@]}" -gt "0" ]]; then

    #Массив в который будут записаны имена не установленных, но найденных в репозитории пакетов
    list_pkg_inst=()

    #Массив в который будут записаны имена не установленных и не найденных в репозитории пакетов
    pkg_noinst_and_notinrepo=()

    #Перебор массива list_names_pkg
    for ((j = 0; j < ${#list_names_pkg[@]}; j++)); do
      #Временный массив в который будут записаны имена не установленных, но найденных в репозитории пакетов для пакетов с условием 'или' (openssh-client|openssh-clients). Если в массиве по итогу обработки будет более одного значения, то необходимо будет выбрать 1 пакет для добавления в список установки
      list_pkg_insttemp=()

      #Запись значения массива list_names_pkg с разбивкой по вертикальной черте в массив temp_list_pkgnames. Данный механизм нужен для работы условия 'или' при проверке пакетов
      readarray -d '|' -t temp_list_pkgnames < <(echo "${list_names_pkg[$j]}" | tr -d '\n')

      #Перебор массива temp_list_pkgnames
      for ((i = 0; i < ${#temp_list_pkgnames[@]}; i++)); do
        #Выполняется проверка, если есть подходящая система управления пакетами и пока pkgstatus пуст
        unset pkgstatus

        #Проверка статуса установки пакта, если выбран apt
        if [[ "$select_package_management" = "apt" ]] && [[ -z "$pkgstatus" ]]; then
          pkgstatus="$(sudo --prompt="Введите пароль для проверки наличия пакета в системе: " apt list --installed "${temp_list_pkgnames[$i]}" 2>/dev/null | grep "^${temp_list_pkgnames[$i]}" | cut -d '/' -f1)"
        fi

        #Проверка статуса установки пакта, если выбран dnf
        if [[ "$select_package_management" = "dnf" ]] && [[ -z "$pkgstatus" ]]; then
          pkgstatus="$(sudo --prompt="Введите пароль для проверки наличия пакета в системе: " dnf list installed "${temp_list_pkgnames[$i]}" 2>/dev/null | grep "^${temp_list_pkgnames[$i]}" | awk '{print $1}')"
        fi

        #Проверка статуса установки пакта через dpkg (при наличии его в системе)
        if [[ -n "$(which dpkg 2>/dev/null)" ]] && [[ -z "$pkgstatus" ]]; then
          pkgstatus="$(sudo --prompt="Введите пароль для проверки наличия пакета в системе: " dpkg -l | grep ^ii | awk '{ print $2}' | grep "^${temp_list_pkgnames[$i]}$")"
        fi

        #Проверка статуса установки пакта через rpm (при наличии его в системе)
        if [[ -n "$(which rpm 2>/dev/null)" ]] && [[ -z "$pkgstatus" ]]; then
          pkgstatus="$(sudo --prompt="Введите пароль для проверки установки пакета: " rpm -qi ${temp_list_pkgnames[$i]} 2>/dev/null | grep 'Name' | grep "${temp_list_pkgnames[$i]}")"
        fi

        #Если pkgstatus пуст, то поиск пакета в репозитории, иначе зануление массива list_pkg_insttemp и переход к проверке следующего пакета
        if [[ -z "$pkgstatus" ]]; then
          existence_pkg_in_repo=""

          #Проверка в репозитории через apt-cache, если выбрана система управления пакетами apt/apt-get
          if [[ "$select_package_management" = "apt" || "$select_package_management" = "apt-get" ]]; then

            if [[ -n "$(which apt-cache 2>/dev/null)" ]]; then
              existence_pkg_in_repo="$(sudo --prompt="Введите пароль для проверки существования пакета в репозитории: " apt-cache showpkg "${temp_list_pkgnames[$i]}" 2>/dev/null | head -1 | awk '{print $2}')"
            fi
          fi

          #Проверка в репозитории, если выбрана система управления пакетами dnf
          if [[ "$select_package_management" = "dnf" ]]; then
            existence_pkg_in_repo="$(sudo --prompt="Введите пароль для проверки существования пакета в репозитории: " dnf list "${temp_list_pkgnames[$i]}" 2>/dev/null | grep "^${temp_list_pkgnames[$i]}" | awk '{print $1}')"
          fi

          #Если пакет не установлен, но найден в репозитории, то он добавляется в массив list_pkg_inst и происходит выход из цикла (при проверке пакетов без условий 'или').

          #Если пакет не установлен, но найден в репозитории, то он добавляется в массив list_pkg_insttemp (при проверке пакетов с условием 'или').

          #(Если пакет не установлен, не найден в репозитории и цикл temp_list_pkgnames состоит из одного круга) или (Если пакет не установлен, не найден в репозитории, массив list_pkg_insttemp пуст и это последний круг цикла temp_list_pkgnames), то значение из массива list_names_pkg добавляется в массив pkg_noinst_and_notinrepo и происходит выход из цикла.

          if [[ -z "$pkgstatus" ]] && [[ -n "$existence_pkg_in_repo" ]]; then

            if [[ "${#temp_list_pkgnames[@]}" -eq "1" ]]; then
              list_pkg_inst[${#list_pkg_inst[@]}]="${temp_list_pkgnames[$i]}"
              break
            elif [[ "${#temp_list_pkgnames[@]}" -gt "1" ]]; then
              list_pkg_insttemp[${#list_pkg_insttemp[@]}]="${temp_list_pkgnames[$i]}"
            fi
          fi

          if [[ -z "$pkgstatus" && -z "$existence_pkg_in_repo" && "${#temp_list_pkgnames[@]}" -eq "1" ]] || [[ -z "$pkgstatus" && -z "$existence_pkg_in_repo" && "${#list_pkg_insttemp[@]}" -eq "0" && "$i" -eq "$(expr ${#temp_list_pkgnames[@]} - 1)" ]]; then
            pkg_noinst_and_notinrepo[${#pkg_noinst_and_notinrepo[@]}]="${list_names_pkg[$j]}"
            break
          fi
        else
          unset list_pkg_insttemp
          break
        fi
      done

      unset existence_pkg_in_repo
      unset temp_list_pkgnames
      unset pkgstatus

      #Если в массиве list_pkg_insttemp после проверки более одного значения, то необходимо будет выбрать 1 пакет для добавления в список установки (объявив переменную select_first_value со значением 1 до вызова функции, выбора не будет, а будет выбрано первое значение в массиве).
      #При одном значении в массиве list_pkg_insttemp, в массив list_pkg_inst будет добавлено единственное имеющееся значение. Если массив list_pkg_insttemp пуст, то данный блок пропускается
      if [[ "${#list_pkg_insttemp[@]}" -gt "0" ]]; then

        if [[ "${#list_pkg_insttemp[@]}" -eq "1" ]] || [[ "$select_first_value" -eq "1" ]]; then
          list_pkg_inst[${#list_pkg_inst[@]}]="${list_pkg_insttemp[0]}"
        elif [[ "${#list_pkg_insttemp[@]}" -gt "1" ]]; then
          echo -e "\n${YELLOW}Обнаружено несколько неустановленнных пакетов из списка (${list_names_pkg[$j]}) присутствующих в репозитории.
Выберите 1 пакет для добавления в список установки.$NoColor\n"

          while true; do
            PS3="Введите номер: "
            COLUMNS=1

            select listlist_pkg_insttemp in "${list_pkg_insttemp[@]}"; do

              if [[ "$REPLY" =~ $check_num ]]; then

                if [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "${#list_pkg_insttemp[@]}" ]]; then
                  list_pkg_inst[${#list_pkg_inst[@]}]="$listlist_pkg_insttemp"
                  unset listlist_pkg_insttemp
                  unset REPLY
                  break 2
                fi
              fi
              break
            done
          done
        fi
        unset list_pkg_insttemp
      fi
    done
  else
    echo -e "${RED}Нет значений для проверки/установки пакетов$NoColor"
    exit 1
  fi
}

#Информационное сообщение с параметрами запуска
function help_run {
  echo -e "Параметры запуска:
${GREEN}-help$NoColor) Вызов справки

${GREEN}-fes$NoColor) Принудительно запустить выполнение каждого скрипта, если отправляется более одного скрипта. (${YELLOW}По умолачанию, если выполнение скрипта закончилось с кодом ошибки, выполнение последующих в списке скриптов для устройства не запускается$NoColor)

${GREEN}-m$NoColor) Запуск выполнения через мультиплексор определенный в параметре конфигурации ${YELLOW}typeterminalmultiplexer$NoColor (применимо к многопоточной отправке) (${YELLOW}По умолчанию выполнение каждого потока запускается в фоновом режиме с выводом выполнения в текущее окно.$NoColor)

${GREEN}-hf значение$NoColor) Имя используемого файла хостов из каталога ${GREEN}conf/fileshosts/$NoColor. Значение с пробелом необходимо заключить в двойные кавычки (${YELLOW}Для выполнения команды обязательно должен быть указан один из параметров: -hf или -hn. При указании обоих параметров приоритет имеет -hn, т.е. значение -hf будет обнулено$NoColor)

${GREEN}-hn значение$NoColor) Имя или ip адрес устройства. Параметр может повторяться для указания дополнительных значений (${YELLOW}Для выполнения команды обязательно должен быть указан один из параметров: -hf или -hn. При указании обоих параметров приоритет имеет -hn, т.е. значение -hf будет обнулено$NoColor)

${GREEN}-sp \"Значение\"$NoColor) - Параметр может повторяться для указания дополнительных значений. Значение имеет следующий вид \"${GREEN}имя каталога скрипта для отправки$NoColor:${GREEN}имя каталога дополнительных файлов для отправки$NoColor:${GREEN}тип выполнения скрипта$NoColor:${GREEN}признак перезагрузки после выполнения скрипта$NoColor:${GREEN}признак проверки версии скрипта$NoColor\" (например: ${GREEN}\"sendmessage:sendmessage:autopassudo:0:0\"$NoColor). Описание параметров в порядке использования:

• Секция № 1 - Имя каталога отправляемого скрипта в каталоге ./scripts (или определенный вами каталог в секции настроек файла sssc.conf). Обязательный параметр.

• Секция № 2 - Имя каталога в ./files (или определенный вами каталог в секции настроек файла sssc.conf) для отправки на удаленный компьютер (Необязательный параметр).

• Секция № 3 - Тип выполнения скрипта (Обязательный параметр). Допустимые значения:
${YELLOW}autopassudo$NoColor - Выполнение с автовводом пароля sudo
${YELLOW}nopassudo$NoColor - Выполнение с ручным вводом пароля sudo
${YELLOW}nosudo$NoColor - Выполнение без прав sudo
${YELLOW}cronscript$NoColor - Выполнение в фоновом режиме через задачу cron на удаленном ПК

• Секция № 4 - Признак перезагрузки после выполнения скрипта (Необязательный параметр). Определяет необходимость ожидания перезагрузки (параметр учитывается, если в списке для выполнения, после указанного скрипта, будут еще скрипты). Команда перезагрузки должна находиться в вашем скрипте (рекомендуется отложенная перезагрузка через shutdown -r +1, т.к. если вы перезагрузите моментально, например через reboot, ssh сессия завершится принудительно и будет возвращен код ошибки, а также не удалятся отправленные файлы). Допустимые значения:
${YELLOW}0$NoColor - ожидание перезагрузки не выполняется
${YELLOW}1$NoColor - дождаться перезагрузки системы

• Секция № 5 - Признак проверки версии скрипта (0 - отключить, 1 - включить). При подключении к удаленному ПК будет выполнено сравнение отправляемой версии скрипта с выполненной ранее. В случае несовпадения версий запустится выполнение скрипта. Версия будет записана в указанный файл при успешном выполнении. Если в настройках не задан путь к файлу path_exec_script_version или в отправляемом скрипте отсутствует переменная с версией scriptversion, то значение данной секции будет 0.

${GREEN}-us значение$NoColor) Имя секции настроек, которую необходимо использовать (Небязательный параметр. Если необходимо, чтобы запрос с выбором секции не показывался при запуске скрипта, например, при запуске скрипта с параметрами из cron задания или терминала, то необходимо задать имя используемой секции в файле настроек или задать его через этот параметр)"
}

#Функция вызываемая при запуске скрипта с параметрами. Проверка параметров и значений определенным условиям
function consolerun {
  unset select_file_hosts
  force_exec_script="0"
  console_or_multiplexer="0"
  list_param_send_script=()
  let num_check_script=0
  list_ipall=()

  function unset_param {
    unset namesendscript
    unset select_dirfiles
    unset type_run_remote_script
    unset reboot_system_script_finish
    unset list_param_send_script
    unset num_check_script
    unset select_file_hosts
    unset list_ipall
    unset force_exec_script
    unset check_version_exec_script
  }

  #Перебор переданных значений
  while [[ -n "$1" ]]; do
    case "$1" in
    -fes)
      force_exec_script="1"
      ;;
    -m)
      console_or_multiplexer="1"
      ;;
    -hf)
      cd "$dir_runscript/conf/fileshosts"
      checkhostfile=$(find ./ -maxdepth 1 -type f | sed -e "s/^..//" | grep "^$2$" | grep -Ev '^$')
      cd "$dir_runscript"

      if [[ -z "$checkhostfile" ]]; then
        echo -e "\nФайл $2 не найден в каталоге ./conf/fileshosts"

        unset_param
        exit 1
      else
        select_file_hosts=("conf/fileshosts/$2")
      fi
      shift
      ;;
    -hn)
      if ! [[ "$2" =~ $check_hostname_or_ip ]]; then
        echo "Значение параметра -hn пустое или не соответствует условию проверки"
      else
        list_ipall[${#list_ipall[@]}]="$2"
      fi
      shift
      ;;
    -sp)
      let num_check_script+=1
      echo -e "\nПроверка параметров скрипта № $num_check_script"

      #Если количество разделителей 4, т.е. 5 секций, то продолжается выполнение
      if [[ "$(echo "$2" | grep -o ':' | wc -l)" -eq "4" ]]; then

        unset namesendscript
        unset select_dirfiles
        unset type_run_remote_script
        unset reboot_system_script_finish
        unset check_version_exec_script

        namesendscript="$(echo "$2" | cut -d ':' -f 1)"
        select_dirfiles="$(echo "$2" | cut -d ':' -f 2)"
        type_run_remote_script="$(echo "$2" | cut -d ':' -f 3)"
        reboot_system_script_finish="$(echo "$2" | cut -d ':' -f 4)"
        check_version_exec_script="$(echo "$2" | cut -d ':' -f 5)"

        #Проверка значения имени каталога скрипта
        if [[ -n "$namesendscript" ]]; then
          cd "$dir_scripts"
          if [[ "$(ls -1 -d */ | sed -e 's/.$//g' | grep "^$namesendscript$" | wc -l)" -gt "0" ]]; then
            if ! [[ -f "$dir_scripts/$namesendscript/sendcommand" ]]; then
              echo -e "\nФайл ${YELLOW}$dir_scripts/$namesendscript/sendcommand$NoColor не найден"

              unset_param
              exit 1
            fi
          else
            echo -e "\nКаталог ${YELLOW}$namesendscript$NoColor не найден в каталоге ${YELLOW}$dir_scripts$NoColor"

            unset_param
            exit 1
          fi
        else
          echo -e "\nПустое значение имени скрипта"

          unset_param
          exit 1
        fi

        #Проверка значения каталога дополнительных файлов для отправки
        if [[ -n "$select_dirfiles" ]]; then
          cd "$dir_files_send"

          if [[ "$(ls -1 -d */ | sed -e 's/.$//g' | grep "^$select_dirfiles$" | wc -l)" -eq "0" ]]; then
            echo -e "\nКаталог ${YELLOW}$select_dirfiles$NoColor не найден в каталоге ${YELLOW}$dir_files_send$NoColor"

            unset_param
            exit 1
          fi
        fi

        cd "$dir_runscript"

        #Проверка значения типа выполнения скрипта
        if ! [[ "$type_run_remote_script" = "autopassudo" || "$type_run_remote_script" = "cronscript" || "$type_run_remote_script" = "nopassudo" || "$type_run_remote_script" = "nosudo" ]]; then
          echo -e "\n$type_run_remote_script - указан неверный тип выполнения скрипта (Допустимые значения: autopassudo, cronscript, nopassudo, nosudo)"

          unset_param
          exit 1
        fi

        #Проверка значения признака перезагрузки reboot_system_script_finish
        if [[ "$reboot_system_script_finish" =~ $check_num ]]; then

          if ! [[ "$reboot_system_script_finish" -eq "0" || "$reboot_system_script_finish" -eq "1" ]]; then

            echo -e "\nУказано недопустимое значение признака перезагрузки. Допустимые значения: 0 или 1"

            unset_param
            exit 1
          fi
        else
          reboot_system_script_finish="0"
        fi

        #Проверка значения признака проверки версии check_version_exec_script, проверка на пустоту path_exec_script_version, проверка переменной с версией скрипта scriptversion
        if [[ "$check_version_exec_script" =~ $check_num ]] && [[ -n "$path_exec_script_version" ]] && [[ "$(sed -nr "{ :l /scriptversion[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$dir_scripts/$namesendscript/sendcommand")" =~ $check_num && "$(sed -nr "{ :l /scriptversion[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$dir_scripts/$namesendscript/sendcommand")" -ne "0" ]]; then

          if ! [[ "$check_version_exec_script" -eq "0" || "$check_version_exec_script" -eq "1" ]]; then

            echo -e "\nУказано недопустимое значение признака проверки версии. Допустимые значения: 0 или 1"

            unset_param
            exit 1
          fi
        else
          check_version_exec_script="0"
        fi

        #Добавляем новые данные в массив
        list_param_send_script[${#list_param_send_script[@]}]="$namesendscript:$select_dirfiles:$type_run_remote_script:$reboot_system_script_finish:$check_version_exec_script"

      else
        echo -e "\nКоличество разделителей ':' в параметрах скрипта № $num_check_script не равно 4"

        unset_param
        exit 1
      fi
      shift
      ;;
    *)
      help_run
      exit
      ;;
    esac
    shift
  done

  #Если список адресов не пуст, то обнуляем переменную select_file_hosts и задаем тип отправки sshonesend
  if [[ "${#list_ipall[@]}" -gt "0" ]]; then
    unset select_file_hosts
    typesend="sshonesend"
  fi

  #Если список адресов пуст и выбран файл хостов, то задаем тип отправки sshmultisend
  if [[ "${#list_ipall[@]}" -eq "0" ]] && [[ -n "$select_file_hosts" ]]; then
    typesend="sshmultisend"
  fi

  #Если выбран файл хостов или список адресов не пуст и количество отправляемых скриптов больше нуля, то задаем тип запуска скрипта console
  if [[ -n "$select_file_hosts" || "${#list_ipall[@]}" -gt "0" ]] && [[ "${#list_param_send_script[@]}" -gt "0" ]]; then
    type_run_sssc="console"

    if [[ "$force_exec_script" -eq "1" ]]; then

      #Если использовался параметр -fes и количество скриптов больше 1, то показываем уведомление, иначе присваиваем force_exec_script значение 0
      if [[ "${#list_param_send_script[@]}" -gt "1" ]]; then
        echo -e "\nОбнаружен переданный параметр -fes.
Включен принудительный запуск выполнения каждого скрипта\n"
      else
        echo -e "\nОтправляется 1 скрипт. Переданный параметр -fes игнорируется\n"
        force_exec_script="0"
      fi
    fi

    unset namesendscript
    unset select_dirfiles
    unset type_run_remote_script
    unset reboot_system_script_finish
  else
    help_run

    unset_param
    exit 1
  fi
}

#Проверка или выбор имени секции настроек, а также запуск считывания параметров
function check_or_select_use_section_settings {
  let check_usesettings_status=0

  #Проверка параметра с наименованием секции настроек. Если пуст, не соответствует условию или указанная секция не найдена в файле настроек, то выполнится поиск всех доступных секций настроек
  if ! [[ "$use_section_settings" =~ $check_namesettings ]]; then
    echo -e "\n${RED}Имя секции в параметре usesection файла sssc.conf (или заданная в параметре скрипта при запуске) пустое или содержит запрещенные символы.$NoColor"
    let check_usesettings_status=1
  elif [[ -z "$(cat "$dir_conf/sssc.conf" | tail -n +2 | grep '^\[.*\]$' | awk -F'[][]' '{print $2}' | grep -w "^$use_section_settings$")" ]]; then
    echo -e "\n${RED}Секция настроек $use_section_settings из параметра usesection (или заданная в параметре скрипта при запуске) не найдена в файле sssc.conf $NoColor"
    let check_usesettings_status=1
  fi

  if [[ "$check_usesettings_status" -eq "1" ]]; then
    readarray -d ';' -t list_namesection_settings < <(cat "$dir_conf/sssc.conf" | tail -n +2 | grep '^\[.*\]$' | awk -F'[][]' '{print $2}' | sort -u | tr '\n' ';' | sed -e 's/.$//g')

    echo -e "\nОбнаружено секций: ${#list_namesection_settings[@]}"

    if [[ "${#list_namesection_settings[@]}" -gt "0" ]]; then
      PS3="Введите номер: "
      COLUMNS=1
      echo -e "\nВыберите секцию настроек для использования"
      select usesection in "${list_namesection_settings[@]}"; do

        if [[ "$REPLY" =~ $check_num ]]; then

          #Присваиваем use_section_settings выбранную секцию
          if [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "${#list_namesection_settings[@]}" ]]; then
            use_section_settings="$usesection"
            unset list_namesection_settings
            unset check_usesettings_status
            break
          fi
        fi
      done
    else
      exit 1
    fi
  fi

  echo -e "\nИспользуемая секция настроек: ${GREEN}$use_section_settings $NoColor"

  #Запуск функции считывания и проверки необходимых настроек
  check_settings
}

#Ввод текстового значения через zenity
function input_text_zenity {
  zenity --title="$title_msg" --entry --text="$text_msg" 2>/dev/null
}

#Подфункция для выбора через select (для уменьшения команды eval)
function subfunc_select_use_value {
  if [[ "$REPLY" =~ $check_num ]]; then
    if [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "${#templist_selectvalue[@]}" ]]; then
      let status_exec_select=1
    fi
  fi
}

#Выбор значения через select
function select_use_value {
  #Вызываем select через eval для подстановки имени переменной. Напрямую нельзя выполнить select $name_variable. Когда status_exec_select будет равен 1, то прерываем select
  eval "let status_exec_select=0
select $name_variable in \"\${templist_selectvalue[@]}\"; do
subfunc_select_use_value
[[ \"\$status_exec_select\" -eq \"1\" ]] && break
done
unset status_exec_select"
}

#Выбор значения через zenity
function select_use_value_zenity {
  zenity --list --title="$title_msg" --text="$text_msg" --column="0" "${templist_selectvalue[@]}" --width=250 --height=200 --hide-header 2>/dev/null
}

#Считывание и проверка настроек
function check_settings {
  #Определение имени секции, которая следует за выбранной. В случае если выбрана последняя секция, то имя будет тоже
  nextsection="$(cat "$dir_conf/sssc.conf" | tail -n +2 | grep '^\[.*\]$' | awk -F'[][]' '{print $2}' | sed -n "/$use_section_settings/,+1 p" | tail -1)"

  #Если номер дисплея отсутствует, то exec_no_display=1, иначе определяется значение
  if [[ -z "$DISPLAY" ]]; then
    let exec_no_display=1
    echo -e "\nНомер дисплея не обнаружен. Для запросов будет использоваться dialog вместо zenity (select для выбора из списка)."
  else
    exec_no_display="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^exec_no_display[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

    #Если exec_no_display не является числом, то присваивается значение по умолчанию 0
    if ! [[ "$exec_no_display" =~ $check_num ]]; then
      let exec_no_display=0
      echo -e "${YELLOW}Значение exec_no_display пустое или не является числом. Выставлено значение по умолчанию: $exec_no_display $NoColor"
    fi
  fi

  no_check_update_script="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^no_check_update_script[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  #Если no_check_update_script не является числом, то присваивается значение по умолчанию 0
  if ! [[ "$no_check_update_script" =~ $check_num ]]; then
    no_check_update_script="0"
    echo -e "${YELLOW}Значение no_check_update_script пустое или не является числом. Выставлено значение по умолчанию: $no_check_update_script $NoColor"
  fi

  dir_scripts="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^dirscripts[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  if ! [[ "$dir_scripts" =~ $check_path ]]; then
    dir_scripts="$dir_runscript/scripts"
    echo ""
    echo -e "${YELLOW}Значение параметра dirscripts пустое или содержит недопустимые символы. Используется путь по умолчанию:$NoColor ./scripts"
    mkdir -p "$dir_scripts"
  else
    if ! [[ -d "$dir_scripts" ]]; then
      dir_scripts="$dir_runscript/scripts"
      echo ""
      echo -e "${YELLOW}Указанный в параметре dirscripts каталог не существует. Используется путь по умолчанию:$NoColor ./scripts"
      mkdir -p "$dir_scripts"
    fi
  fi

  dir_files_send="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^dirfiles[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  if ! [[ "$dir_files_send" =~ $check_path ]]; then
    dir_files_send="$dir_runscript/files"
    echo ""
    echo -e "${YELLOW}Значение параметра dirfiles пустое или содержит недопустимые символы. Используется путь по умолчанию:$NoColor ./files"
    mkdir -p "$dir_files_send"
  else
    if ! [[ -d "$dir_files_send" ]]; then
      dir_files_send="$dir_runscript/files"
      echo ""
      echo -e "${YELLOW}Указанный в параметре dirfiles каталог не существует. Используется путь по умолчанию:$NoColor ./files"
      mkdir -p "$dir_files_send"
    fi
  fi

  path_exec_script_version="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^path_exec_script_version[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  if [[ -n "$path_exec_script_version" ]]; then

    if ! [[ "$path_exec_script_version" =~ $check_path ]]; then
      path_exec_script_version=""

      echo -e "\n${YELLOW}Значение параметра path_exec_script_version содержит недопустимые символы. Значение занулено. Возможность проверки выполненной версии скрипта отключена.$NoColor"
    fi
  fi

  multisend="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^multisend[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  sshtimeout="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^sshConnectTimeout[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  numportssh="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^numportssh[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  reboot_max_try_wait_devaice="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^reboot_max_try_wait_devaice[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  reboot_time_wait_devaice="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^reboot_time_wait_devaice[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  sshtypecon="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^sshtypecon[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  remotedirrunscript="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^remotedirrunscript[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  remotedirgroup="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^remotedirgroup[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  logname="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^loginname[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  if [[ "$(grep -Eo '^[A-Za-zА-Яа-я0-9.-]+$' <<<"$(printf "%s" $(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^listIgnoreInaccurate[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr ';' '\n' | grep -Ev '^$' | sort -u))" | wc -l)" -eq "1" ]]; then
    readarray -d ';' -t listIgnoreInaccurate < <(printf "%s" $(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^listIgnoreInaccurate[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr ';' '\n' | grep -Ev '^$' | sort -u | tr '\n' ';' | sed -e 's/.$//g'))
  else
    echo -e "\n${YELLOW}Пропуск чтения значений параметра listIgnoreInaccurate из выбранной секции настроек файла sssc.conf. Параметр пуст или содержит запрещенные символы в значениях.$NoColor"
  fi

  if [[ "$(grep -Eo '^[A-Za-zА-Яа-я0-9.-]+$' <<<"$(printf "%s" $(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^listIgnoreAccurate[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr ';' '\n' | grep -Ev '^$' | sort -u))" | wc -l)" -eq "1" ]]; then
    readarray -d ';' -t listIgnoreAccurate < <(printf "%s" $(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^listIgnoreAccurate[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr ';' '\n' | grep -Ev '^$' | sort -u | tr '\n' ';' | sed -e 's/.$//g'))
  else
    echo -e "\n${YELLOW}Пропуск чтения значений параметра listIgnoreAccurate из выбранной секции настроек файла sssc.conf. Параметр пуст или содержит запрещенные символы в значениях.$NoColor"
  fi

  skipchangescriptfile="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^skipchangescriptfile[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  sutype="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^sutype[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  typeterminalmultiplexer="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^typeterminalmultiplexer[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  typesendfiles="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^typesendfiles[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

  title_msg="Логин ssh"
  text_msg="Введите логин для ssh:"

  #Если логин не задан в файле настроек и пока переменная пустая, то выведется окно с запросом ввода
  while ! [[ "$logname" =~ $check_login_or_group ]]; do
    echo -e "\n${RED}Логин пуст или содержит недопустимые символы. Введите новое значение. $NoColor"

    if [[ "$exec_no_display" -eq "1" ]]; then
      logname="$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --title "$title_msg" --inputbox "$text_msg" 18 70)"
    else
      logname="$(input_text_zenity)"
    fi
  done

  title_msg="Тип ssh подключения"
  text_msg="Выберите тип ssh подключения:"
  name_variable='sshtypecon'
  templist_selectvalue=("pas" "key")

  #Если параметр типа ssh подключения не соответствует условию, то выдается список с выбором типа подключения
  while [[ "$sshtypecon" != "pas" && "$sshtypecon" != "key" ]]; do

    if [[ "$exec_no_display" -eq "1" ]]; then
      echo -e "\n$text_msg"
      select_use_value
    else
      sshtypecon="$(select_use_value_zenity)"
    fi
  done

  #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
  if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
    debug=1
    set +x
  fi

  #Параметры в условии ниже обязательны для любого пользователя и root с типом подключения pas. Если пользователь root подключается по ключу, то считывание и проверка параметров в этом условии пропускается.
  if [[ "$logname" = "root" && "$sshtypecon" = "pas" ]] || [[ "$logname" != "root" ]]; then

    gpgfilepass="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^gpgfilepass[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

    gpgpass="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^gpgpass[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n' | base64 -w0)"

    if ! [[ "$gpgfilepass" =~ $check_path && -f "$gpgfilepass" ]]; then

      gpgfilepass=""
      #Если путь до gpg файла содержит запрещенные символы, пуст или файл не существует, то выведется окно для выбора файла
      while ! [[ "$gpgfilepass" =~ $check_path ]]; do
        echo -e "\n${RED}Путь до gpg файла пуст, содержит запрещенные символы, либо файл не существует. $NoColor"

        if [[ "$exec_no_display" -eq "1" ]]; then
          gpgfilepass="$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --title "Выберите gpg файл с паролем" --fselect "/" 10 60)"
        else
          gpgfilepass="$(zenity --file-selection --title="Выберите gpg файл с паролем" 2>/dev/null)"
        fi
      done
    fi

    #Назначение прав 400 на gpg файл
    chmod 400 "$gpgfilepass" 2>/dev/null

    #Если пароль от gpg файла не задан в файле настроек и пока переменная пустая, то выведется окно с запросом ввода. Пароль кодируется в base64
    while [[ -z "$gpgpass" ]]; do
      if [[ "$exec_no_display" -eq "1" ]]; then
        gpgpass="$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --passwordbox "Введите пароль для дешифровки gpg файла" 10 30 | tr -d '\n' | base64 -w0)"
      else
        gpgpass="$(zenity --forms --title="Пароль для дешифровки gpg файла" --text="Пароль для дешифровки gpg файла" --add-password="" 2>/dev/null | tr -d '\n' | base64 -w0)"
      fi
    done

    #Выполняется попытка расшифровки и кодирования в base64. Если полученное значение будет пустым, то скрипт остановится
    if [[ -z "$(cat "$gpgfilepass" 2>/dev/null | gpg2 --decrypt -q --pinentry-mode loopback --batch --yes --passphrase "$(echo "$gpgpass" | base64 -d)" 2>/dev/null | base64 -w0 2>/dev/null)" ]]; then
      echo -e "\n${RED}Не удалось расшифровать gpg файл. Проверьте указан ли правильный файл и пароль расшифровки $NoColor"
      exit 1
    fi

  fi

  #Если выбрано ssh соединение по ключу, то считывается параметр пути к файлу ключа. Если параметр пуст или не соответствует условию, то выдается окно для выбора файла закрытого ключа ssh.
  if [[ "$sshtypecon" = "key" ]]; then
    sshkeyfile="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^sshkeyfile[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}")"

    if ! [[ "$sshkeyfile" =~ $check_path && -f "$sshkeyfile" ]]; then

      sshkeyfile=""
      while ! [[ "$sshkeyfile" =~ $check_path ]]; do
        echo -e "\n${RED}Путь к файлу закрытого ключа ssh пуст, содержит запрещенные символы, либо файл не существует. $NoColor"

        if [[ "$exec_no_display" -eq "1" ]]; then
          sshkeyfile="$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --title "Выберите файл закрытого ключа ssh" --fselect "/" 10 60)"
        else
          sshkeyfile="$(zenity --file-selection --title="Выберите файл закрытого ключа ssh" 2>/dev/null)"
        fi
      done
    fi

    #Назначение прав 400 на закрытый ключ ssh
    chmod 400 "$sshkeyfile" 2>/dev/null

  fi
  [[ $debug == 1 ]] && set -x && unset debug

  title_msg="Путь к каталогу передачи на удаленном компьютере"
  text_msg="Укажите путь к каталогу передачи на удаленном компьютере (каталог будет создан, если его нет):"

  #Если параметр пути к каталогу на удаленном компьютере пуст или не соответствует условию, то выдается окно с запросом
  while ! [[ "$remotedirrunscript" =~ $check_path ]]; do
    echo -e "\n${RED}Путь к каталогу не соответствует условию. Введите новое значение. $NoColor"

    if [[ "$exec_no_display" -eq "1" ]]; then
      remotedirrunscript="$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --title "$title_msg" --inputbox "$text_msg" 18 70)"
    else
      remotedirrunscript="$(input_text_zenity)"
    fi
  done

  title_msg="Имя группы для назначения прав на каталог"
  text_msg="Укажите имя группы для назначения прав на каталог (если указанный каталог не существовал):"

  #Если параметр имени группы пуст или не соответствует условию, то выдается окно с запросом
  while ! [[ "$remotedirgroup" =~ $check_login_or_group ]]; do
    echo -e "\n${RED}Имя группы не соответствует условию. Введите новое значение. $NoColor"

    if [[ "$exec_no_display" -eq "1" ]]; then
      remotedirgroup="$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --title "$title_msg" --inputbox "$text_msg" 18 70)"
    else
      remotedirgroup="$(input_text_zenity)"
    fi
  done

  #Если skipchangescriptfile не является числом, то будет запрос с выбором
  if ! [[ "$skipchangescriptfile" =~ $check_num ]] || [[ "$skipchangescriptfile" -lt "0" ]] || [[ "$skipchangescriptfile" -gt "1" ]]; then
    skipchangescriptfile=""

    title_msg="Внесение изменений в переменные отправляемого скрипта"
    text_msg="Пропускать внесение изменений в переменные отправляемого скрипта? (0 - нет, 1 - да):"
    name_variable='skipchangescriptfile'
    templist_selectvalue=("0" "1")

    while [[ -z "$skipchangescriptfile" ]]; do

      if [[ "$exec_no_display" -eq "1" ]]; then
        echo -e "\n$text_msg"
        select_use_value
      else
        skipchangescriptfile="$(select_use_value_zenity)"
      fi
    done
  fi

  #Если логин не root, то проверяется тип повышения прав
  if [[ "$logname" != "root" ]]; then

    #Если sutype не равен sudo, то меняем его
    if [[ "$sutype" != "sudo" ]]; then
      sutype="sudo"
    fi
  fi

  #Если typeterminalmultiplexer не равен screen или tmux, то значение обнуляется.
  if [[ "$typeterminalmultiplexer" != "tmux" && "$typeterminalmultiplexer" != "screen" ]]; then
    typeterminalmultiplexer=""
  fi

  #Если typeterminalmultiplexer равен screen или tmux, то проводится проверка существует ли необходимый исполняемый файл в системе. Если необходимого файла нет, то значение обнуляется
  if [[ "$typeterminalmultiplexer" = "tmux" || "$typeterminalmultiplexer" = "screen" ]]; then

    if [[ -z "$(which "$typeterminalmultiplexer" 2>/dev/null)" ]]; then
      echo -e "\n${RED}Не найден исполняемый файл $typeterminalmultiplexer. Выберите другой тип $NoColor"
      typeterminalmultiplexer=""
    fi
  fi

  title_msg="Тип многооконного терминала"
  text_msg="Выберите тип многооконного терминала:"
  name_variable='typeterminalmultiplexer'
  templist_selectvalue=("tmux" "screen")

  #Выбор значения пока переменная будет пуста
  while [[ -z "$typeterminalmultiplexer" ]]; do

    if [[ "$exec_no_display" -eq "1" ]]; then
      echo -e "\n$text_msg"
      select_use_value
    else
      typeterminalmultiplexer="$(select_use_value_zenity)"
    fi

    if [[ -z "$(which "$typeterminalmultiplexer" 2>/dev/null)" ]]; then
      echo -e "\n${RED}Не найден исполняемый файл $typeterminalmultiplexer. Выберите другой тип $NoColor"
      typeterminalmultiplexer=""
    fi
  done

  #Если typesendfiles не равен scp или rsync, то значение обнуляется.
  if [[ "$typesendfiles" != "scp" && "$typesendfiles" != "rsync" ]]; then
    typesendfiles=""
  fi

  #Если typesendfiles равен scp или rsync, то проводится проверка существует ли необходимый исполняемый файл в системе. Если необходимого файла нет, то значение обнуляется
  if [[ "$typesendfiles" = "scp" || "$typesendfiles" = "rsync" ]]; then

    if [[ -z "$(which "$typesendfiles" 2>/dev/null)" ]]; then
      echo -e "\n${RED}Не найден исполняемый файл $typesendfiles. Выберите другой тип $NoColor"
      typesendfiles=""
    fi
  fi

  title_msg="Метод отправки файлов"
  text_msg="Выберите метод отправки файлов:"
  name_variable='typesendfiles'
  templist_selectvalue=("scp" "rsync")

  while [[ -z "$typesendfiles" ]]; do
    if [[ "$exec_no_display" -eq "1" ]]; then
      echo -e "\n$text_msg"
      select_use_value
    else
      typesendfiles="$(select_use_value_zenity)"
    fi

    if [[ -z "$(which "$typesendfiles" 2>/dev/null)" ]]; then
      echo -e "\n${RED}Не найден исполняемый файл $typesendfiles. Выберите другой тип $NoColor"
      typesendfiles=""
    fi
  done

  #Если параметры ниже не являются числом или они меньше или равны 0, то выставляются фиксированные значения по умолчанию
  if ! [[ "$multisend" =~ $check_num ]] || [[ "$multisend" -le "0" ]]; then
    multisend="1"
    echo -e "${YELLOW}Значение multisend пустое или не является числом. Выставлено значение по умолчанию: $multisend $NoColor"
  fi

  if ! [[ "$sshtimeout" =~ $check_num ]] || [[ "$sshtimeout" -le "0" ]]; then
    sshtimeout="5"
    echo -e "${YELLOW}Значение sshtimeout пустое или не является числом. Выставлено значение по умолчанию: $sshtimeout $NoColor"
  fi

  if ! [[ "$numportssh" =~ $check_num ]] || [[ "$numportssh" -le "0" ]]; then
    numportssh="22"
    echo -e "${YELLOW}Значение numportssh пустое или не является числом. Выставлено значение по умолчанию: $numportssh $NoColor"
  fi

  if ! [[ "$reboot_max_try_wait_devaice" =~ $check_num ]] || [[ "$reboot_max_try_wait_devaice" -le "0" ]]; then
    reboot_max_try_wait_devaice="50"
    echo -e "${YELLOW}Значение reboot_max_try_wait_devaice пустое или не является числом. Выставлено значение по умолчанию: $reboot_max_try_wait_devaice $NoColor"
  fi

  if ! [[ "$reboot_time_wait_devaice" =~ $check_num ]] || [[ "$reboot_time_wait_devaice" -le "0" ]]; then
    reboot_time_wait_devaice="10"
    echo -e "${YELLOW}Значение reboot_time_wait_devaice пустое или не является числом. Выставлено значение по умолчанию: $reboot_time_wait_devaice $NoColor"
  fi

  unset title_msg
  unset text_msg
  unset name_variable
  unset templist_selectvalue
}

#Вывод значений массива столбцами
function splitting_list_massive {
  #Если в массиве list_names_massive есть значения, то продолжается выполнение
  if [[ "${#list_names_massive[@]}" -gt "0" ]]; then

    #Проверка переменной количества значений в строке
    if ! [[ "$num_column_values" =~ $check_num ]] || [[ "$num_column_values" -eq "0" ]]; then
      let num_column_values=3
    fi

    #Проверка переменной максимально выводимого количества значений
    if ! [[ "$max_num_values" =~ $check_num ]]; then
      let max_num_values=100
    fi

    for ((num_value_massive = 0; num_value_massive < ${#list_names_massive[@]}; num_value_massive++)); do

      #Переносим элементы заданного массива в новый массив для удобного обращения к элементам далее
      readarray -d $'\n' -t listvaluemassive < <(eval "echo \"\${${list_names_massive[$num_value_massive]}[@]/%/$'\\n'}\" | sed 's/^ //' | grep -v '^$'")

      #Если массив не пуст, то продолжается выполнение
      if [[ "${#listvaluemassive[@]}" -gt "0" ]]; then

        #Если заданное значение num_column_values превышает количество значений в массиве, то num_column_values будет равен количеству элементов массива
        if [[ "$num_column_values" -gt "${#listvaluemassive[@]}" ]]; then
          let num_column_values=${#listvaluemassive[@]}
        fi

        #Вычисление количества необходимых строк
        let colstring="(${#listvaluemassive[@]}/$num_column_values)"

        #Вычисление остатка от деления
        let modulecolstring="${#listvaluemassive[@]}%$num_column_values"

        let excessvalue=0

        echo "Значения массива ${list_names_massive[$num_value_massive]} (количество: ${#listvaluemassive[@]}):"
        for ((i = 0; i < $colstring; i++)); do
          let j=$num_column_values*$i
          if [[ "$j" -lt "$max_num_values" ]]; then
            echo -e "${YELLOW}${listvaluemassive[@]:$j:$num_column_values} $NoColor" | column -t
          else
            echo -e "${YELLOW}Значение слишком много. Показаны первые $max_num_values значений $NoColor"
            let excessvalue=1
            break
          fi
        done

        if [[ "$excessvalue" -eq "0" ]]; then
          if [[ "$modulecolstring" -ne "0" ]]; then
            let j=$num_column_values*$colstring
            if [[ "$j" -lt "$max_num_values" ]]; then
              echo -e "${YELLOW}${listvaluemassive[@]:$j:$num_column_values} $NoColor" | column -t
            else
              echo -e "${YELLOW}Значение слишком много. Показаны первые $max_num_values значений $NoColor"
            fi
          fi
        fi
        echo""
      else
        echo "Массив ${list_names_massive[$num_value_massive]} не содержит значений"
      fi
    done
  else
    echo "Массив list_names_massive пуст"
  fi
  unset listvaluemassive
  unset list_names_massive
  unset num_column_values
  unset max_num_values
  unset num_value_massive
  unset colstring
  unset modulecolstring
  unset excessvalue
}

#Генерация списка скриптов для отправки и списка их имен для показа в скрипте
function create_list_scripts {
  unset list_scripts

  #Формируем список скриптов
  readarray -d ';' -t list_scripts < <(find "$dir_scripts/" -type f | grep -Eo '^[A-Za-zА-Яа-я0-9(),./@_[:space:]-]+$' | grep '/sendcommand$' | sort -u | tr '\n' ';' | sed -e 's/.$//g')

  echo "Обнаружено файлов скриптов: ${#list_scripts[@]}"
  echo ""

  #Если скрипты найдены, то формируется массив имен для списка выбора, иначе завершение работы скрипта
  if [[ "${#list_scripts[@]}" -gt "0" ]]; then
    namescripts=()

    for ((i = 0; i < ${#list_scripts[@]}; i++)); do
      namescripts[${#namescripts[@]}]="$(sed -nr "{ :l /namescript[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "${list_scripts[$i]}" | sed 's/^"\(.*\)"$/\1/')"
    done
  else
    exit 1
  fi
}

function presendscript {
  unset namesendscript
  unset select_dirfiles
  unset type_run_remote_script
  unset reboot_system_script_finish
  unset check_version_exec_script

  #Имя каталога выбранного скрипта
  namesendscript="$(basename "$(dirname "${list_scripts[$numscript]}")")"

  unset list_scripts
  unset namescripts
  unset list_source_func

  #Блок кода для запуска без параметров
  if [[ "$type_run_sssc" != "console" ]]; then
    unset err_status_sendfunc

    #Если в скрипте обнаружен list_source_func и он не пуст, то проверка на существование указанных файлов в каталоге sendfunc
    if [[ "$(cat "$dir_scripts/$namesendscript/sendcommand" | grep -E '^list_source_func=\((.*)\)' | head -1 | wc -l)" -eq "1" ]]; then
      eval "$(cat "$dir_scripts/$namesendscript/sendcommand" | grep -E '^list_source_func=\((.*)\)' | head -1)"

      for ((num_list_func = 0; num_list_func < ${#list_source_func[@]}; num_list_func++)); do
        ! [[ -f "$dir_sendfunc/${list_source_func[$num_list_func]}" ]] && err_status_sendfunc="1" && echo "Указанный в массиве list_source_func скрипта '$dir_scripts/$namesendscript/sendcommand' файл '${list_source_func[$num_list_func]}' не найден в каталоге '$dir_sendfunc'"
      done
    fi

    #Продолжаем, если err_status_sendfunc не равен 1
    if [[ "$err_status_sendfunc" -ne "1" ]]; then

      infmsg="Вы хотите выбрать каталог с файлами для отправки? [y/n]: "
      errmsg="Выбор каталога с файлами для отправки пропущен"
      yes_or_no

      if [[ "$ynaction" = "yes" ]]; then
        #Выбор каталога с файлами для отправки в случае согласия
        select_send_dirfiles

        unset list_dirfiles
      fi

      #Выбор типа выполнения скрипта
      select_type_run_remote_script

      unset value_trrs
      unset value_type_run_remote_script

      echo -e "\n${YELLOW}Примечание: Вводимое ниже значение определяет необходимость ожидания перезагрузки (параметр учитывается, если в списке для выполнения, после указанного скрипта, будут еще скрипты). Команда перезагрузки должна находиться в вашем скрипте (рекомендуется отложенная перезагрузка через shutdown -r +1, т.к. если вы перезагрузите моментально, например через reboot, ssh сессия завершится принудительно и будет возвращен код ошибки, а также не удалятся отправленные файлы)$NoColor"

      infmsg="Ожидать перезагрузку системы после выполнения? [y/n]: "
      errmsg="Ожидания презагрузки не требуется"
      yes_or_no

      if [[ "$ynaction" = "yes" ]]; then
        reboot_system_script_finish="1"
      else
        reboot_system_script_finish="0"
      fi

      check_version_exec_script="0"

      #Проверка на пустоту path_exec_script_version, проверка переменной с версией скрипта scriptversion
      if [[ -n "$path_exec_script_version" ]] && [[ "$(sed -nr "{ :l /scriptversion[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$dir_scripts/$namesendscript/sendcommand")" =~ $check_num && "$(sed -nr "{ :l /scriptversion[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$dir_scripts/$namesendscript/sendcommand")" -ne "0" ]]; then

        #Если путь к файлу не пуст и в файле скрипта есть версия не равная 0, то задать вопрос о сравнении отправляемой и выполненной на удаленном ПК версии
        echo -e "\n${YELLOW}Примечание: Вводимое ниже значение определяет необходимость проверки отправляемой версии скрипта с выполненной на удаленном ПК (0 - отключить, 1 - включить). В случае несовпадения версий запустится выполнение скрипта. Версия будет записана в указанный файл при успешном выполнении.$NoColor"

        infmsg="Выполнить проверку версий для выбранного скрипта? [y/n]: "
        errmsg="Проверка версий будет пропущена"
        yes_or_no

        if [[ "$ynaction" = "yes" ]]; then
          check_version_exec_script="1"
        fi
      fi

      #Добавляем выбранные ранее параметры скрипта в массив list_param_send_script
      list_param_send_script[${#list_param_send_script[@]}]="$namesendscript:$select_dirfiles:$type_run_remote_script:$reboot_system_script_finish:$check_version_exec_script"

      infmsg="Вы хотите выбрать дополнительный скрипт для отправки? [y/n]: "
      errmsg="Запущена подготовка файлов для передачи"
      yes_or_no

      #Если нет, то продолжаем. Если да, то возврат к списку скриптов
      if [[ "$ynaction" != "yes" ]]; then

        force_exec_script="0"

        #Если выбрано более одного скрипта, то задать вопрос о принудительном запуске каждого скрипта
        if [[ "${#list_param_send_script[@]}" -gt "1" ]]; then
          echo "Выбрано скриптов для отправки: ${#list_param_send_script[@]}"

          infmsg="Включить принудительный запуск выполнения каждого скрипта? (По умолачанию, если выполнение скрипта закончилось с кодом ошибки, выполнение последующих в списке скриптов для устройства не запускается) [y/n]: "

          errmsg="Запущена подготовка файлов для передачи"
          yes_or_no

          if [[ "$ynaction" = "yes" ]]; then
            force_exec_script="1"
          fi
        fi

        #Подготовка файлов и переменных
        initialsetup

        #Продолжаем, если err_status_sendfunc не равен 1
        if [[ "$err_status_sendfunc" -ne "1" ]]; then

          #Выбор метода формирования списка устройств и формирование списка
          select_type_find_hosts

          #Если список устройств не пуст, то запуск отправки
          if [[ "${#list_ipall[@]}" -gt "0" ]]; then
            console_or_multiplexer="1"
            prerunsend
          fi
        fi
      fi
    fi
  fi
}

#Функция выбора каталога с файлами для отправки. Если каталогов нет, то выбор пропускается.
function select_send_dirfiles {
  cd "$dir_files_send"

  #Формирование списка
  readarray -d ';' -t list_dirfiles < <(find ./ -maxdepth 1 -type d | sed -e "s/^..//" | grep -Eo '^[A-Za-zА-Яа-я0-9(),./@_[:space:]-]+$' | grep -Ev '^$' | sort -u | tr '\n' ';' | sed -e 's/.$//g')

  cd "$dir_runscript"

  echo -e "\nОбнаружено каталогов: ${#list_dirfiles[@]}"
  echo ""

  #Если список не пуст, показать выбор
  if [[ "${#list_dirfiles[@]}" -gt "0" ]]; then

    while true; do
      PS3="Введите номер: "
      COLUMNS=1

      select select_dirfiles in "${list_dirfiles[@]}"; do

        if [[ "$REPLY" =~ $check_num ]]; then

          if [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "${#list_dirfiles[@]}" ]]; then
            echo ""
            echo "Выбран каталог: $select_dirfiles"
            infmsg="Вы хотите продолжить? [y/n]: "
            errmsg="Возврат к выбору"
            yes_or_no

            if [[ "$ynaction" = "yes" ]]; then
              echo ""
              break 2
            fi
          fi
        fi
        break
      done
    done
  fi
}

#Выбор типа выполнения отправляемого скрипта
function select_type_run_remote_script {
  unset type_run_remote_script
  unset value_type_run_remote_script

  #Особый список для выбора, если выбран пользователь root
  if [[ "$logname" = "root" ]]; then
    value_type_run_remote_script=("Обычное выполнение (выбран пользователь root)" "Выполнение в фоновом режиме через задачу cron на удаленном ПК")
  else
    value_type_run_remote_script=("Выполнение с автовводом пароля sudo" "Выполнение с ручным вводом пароля sudo" "Выполнение без прав sudo" "Выполнение в фоновом режиме через задачу cron на удаленном ПК")
  fi

  while true; do
    PS3="Введите номер: "
    COLUMNS=1

    #Выбор типа выполнения отправляемого скрипта
    select value_trrs in "${value_type_run_remote_script[@]}"; do

      if [[ "$REPLY" =~ $check_num ]]; then

        #Если логин root
        if [[ "$logname" = "root" ]]; then

          if [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "2" ]]; then
            let num=1

            if [[ $REPLY = "$num" ]]; then
              type_run_remote_script="nosudo"
            fi

            let num=$num+1

            if [[ $REPLY = "$num" ]]; then
              type_run_remote_script="cronscript"
            fi

            echo "Выбран тип: $type_run_remote_script"
            infmsg="Вы хотите продолжить? [y/n]: "
            errmsg="Возврат к выбору"
            yes_or_no

            if [[ "$ynaction" = "yes" ]]; then
              break 2
            fi
          fi
          #Если логин не root
        else
          if [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "4" ]]; then
            let num=1

            if [[ $REPLY = "$num" ]]; then
              type_run_remote_script="autopassudo"
            fi

            let num=$num+1

            if [[ $REPLY = "$num" ]]; then
              type_run_remote_script="nopassudo"
            fi

            let num=$num+1

            if [[ $REPLY = "$num" ]]; then
              type_run_remote_script="nosudo"
            fi

            let num=$num+1

            if [[ $REPLY = "$num" ]]; then
              type_run_remote_script="cronscript"
            fi

            echo "Выбран тип: $type_run_remote_script"
            infmsg="Вы хотите продолжить? [y/n]: "
            errmsg="Возврат к выбору"
            yes_or_no

            if [[ "$ynaction" = "yes" ]]; then
              break 2
            fi
          fi
        fi
      fi
      break
    done
  done
}

#Инициализация необходимых переменных и подготовка файлов
function initialsetup {

  value_date="$(date +"%Y%m%d-%H%M%S")"
  temp_dir_send_script="$dir_temp/sssc-$value_date-$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 3)"
  unset err_status_sendfunc

  #Показать информацию, если выбрано более одного скрипта
  if [[ "${#list_param_send_script[@]}" -gt "1" ]]; then
    echo -e "\nВыбрано скриптов для отправки: ${GREEN}${#list_param_send_script[@]} $NoColor"
    echo "Принудительный запуск выполнения каждого скрипта: $([[ "$force_exec_script" -eq "1" ]] && echo -e "${GREEN}Включено$NoColor" || echo -e "${GREEN}Не включено$NoColor")"
  fi

  #Подготовка выбранных скриптов к отправке
  for ((nlpss = 0; nlpss < ${#list_param_send_script[@]}; nlpss++)); do

    unset namesendscript
    unset select_dirfiles
    unset type_run_remote_script
    unset reboot_system_script_finish
    unset check_version_exec_script
    unset local_version_exec_script
    unset list_source_func
    unset epas
    unset rc
    unset tfs
    unset oiter

    #Присваиваем переменным значения из секций параметров скрипта
    namesendscript="$(echo "${list_param_send_script[$nlpss]}" | cut -d ':' -f 1)"
    select_dirfiles="$(echo "${list_param_send_script[$nlpss]}" | cut -d ':' -f 2)"
    type_run_remote_script="$(echo "${list_param_send_script[$nlpss]}" | cut -d ':' -f 3)"
    reboot_system_script_finish="$(echo "${list_param_send_script[$nlpss]}" | cut -d ':' -f 4)"
    check_version_exec_script="$(echo "${list_param_send_script[$nlpss]}" | cut -d ':' -f 5)"

    #Если это последний в списке скрипт, то отключаем ожидание перезагрузки после выполнения
    if [[ "$nlpss" -eq "$(expr ${#list_param_send_script[@]} - 1)" ]]; then
      reboot_system_script_finish="0"
    fi

    #Если выполняется проверка версии скрипта, то считываем версию отправляемого скрипта
    if [[ "$check_version_exec_script" -eq "1" ]]; then
      local_version_exec_script="$(sed -nr "{ :l /scriptversion[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$dir_scripts/$namesendscript/sendcommand")"
    else
      local_version_exec_script="0"
    fi

    #Дополнительные действия, если выбран пользователь root и тип запуска console (т.е. с параметрами запуска)
    if [[ "$logname" = "root" ]] && [[ "$type_run_sssc" = "console" ]]; then

      #Проверка, что указанный тип выполнения в скрипте соответствует nosudo или cronscript. Если не соответствует, то присваиваем тип nosudo
      if [[ "$type_run_remote_script" != "nosudo" && "$type_run_remote_script" != "cronscript" ]]; then
        echo "Вы выбрали пользователя root для выполнения скрипта на удаленном устройстве.
Выбранный вариант выполнения скрипта '$type_run_remote_script' переопределен на 'nosudo' (При выполнении от root доступны типы выполнения: nosudo и cronscript)"

        type_run_remote_script="nosudo"
      fi
    fi

    #Вывод параметров подготавливаемого скрипта
    echo -e "\nПодготовка к отправке скрипта № $(expr $nlpss + 1): ${YELLOW}$namesendscript $NoColor"
    echo -e "Дополнительный каталог файлов для отправки: ${YELLOW} $select_dirfiles $NoColor"
    echo -e "Тип выполнения скрипта: ${YELLOW} $type_run_remote_script $NoColor"
    echo -e "Ожидание перезагрузки устройства после выполнения: ${YELLOW} $([[ "$reboot_system_script_finish" -eq "1" ]] && echo "Выполняется" || echo "Не выполняется") $NoColor"
    echo -e "Проверка выполненной ранее версии скрипта: ${YELLOW} $([[ "$check_version_exec_script" -eq "1" ]] && echo "Выполняется (Версия № $local_version_exec_script)" || echo "Не выполняется") $NoColor\n"

    #Имя скрипта для отправки
    tempnamescript="$value_date-$nlpss-$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 10)"

    #Временный каталог в который будет скопировано все необходимое и он будет отправлен на удаленный компьютер
    tfs="$temp_dir_send_script/$tempnamescript"

    mkdir -p "$dir_temp/" "$tfs/" "$dir_logs/"

    #Если выбрано выполнение скрипта через cron, то копируется файл шаблона
    if [[ "$type_run_remote_script" = "cronscript" ]]; then
      cp "$dir_runscript/remote-temprunscript-cron" "$tfs/"
    fi

    #Копируем файл скрипта
    cp "$dir_scripts/$namesendscript/sendcommand" "$tfs/$tempnamescript"

    if [[ "$local_version_exec_script" -gt "0" ]]; then
      echo "#!/bin/bash
export HISTFILE=/dev/null
sudo -k 2>/dev/null
shopt -s dotglob
namesendscript=\"$namesendscript\"
path_exec_script_version=\"$path_exec_script_version\"
[[ \"\$(cat \"\$path_exec_script_version\" | grep \"^\$namesendscript\" | wc -l)\" -gt \"0\" ]] && sed -i \"0,/\$namesendscript=.*/s%\$namesendscript=.*%\$namesendscript=$local_version_exec_script%\" \"\$path_exec_script_version\" || echo \"\$namesendscript=$local_version_exec_script\" >> \"\$path_exec_script_version\"" >"$tfs/add_ver_to_file.sh"

      chmod +x "$tfs/add_ver_to_file.sh"
    fi

    #Если в скрипте присутствует list_source_func, то копируем указанные в этом массиве файлы
    if [[ "$(cat "$tfs/$tempnamescript" | grep -E '^list_source_func=\((.*)\)' | head -1 | wc -l)" -eq "1" ]]; then
      eval "$(cat "$tfs/$tempnamescript" | grep -E '^list_source_func=\((.*)\)' | head -1)"

      for ((num_list_func = 0; num_list_func < ${#list_source_func[@]}; num_list_func++)); do

        if [[ -f "$dir_sendfunc/${list_source_func[$num_list_func]}" ]]; then
          cp "$dir_sendfunc/${list_source_func[$num_list_func]}" "$tfs/${list_source_func[$num_list_func]}"
        else
          err_status_sendfunc="1"

          echo ""
          echo "Указанный в массиве list_source_func файл '${list_source_func[$num_list_func]}' не найден в каталоге '$dir_sendfunc'"
          echo ""

          rm -f -R -v "$temp_dir_send_script"

          unset namesendscript
          unset select_dirfiles
          unset type_run_remote_script
          unset reboot_system_script_finish
          unset check_version_exec_script
          unset local_version_exec_script
          unset list_source_func
          unset epas
          unset rc
          unset list_param_send_script
          unset value_date
          unset temp_dir_send_script
          unset tempnamescript
          unset tfs
          unset oiter

          break 2
        fi
      done
    fi

    #Удаляем комментарии и пустые строки в скопированном файле
    sed -i -r '2,${/(^[[:space:]]*#|^$)/d}' "$tfs/$tempnamescript"

    #Если выбран каталог с файлами для отправки, то на него создается симлинк в отправляемом каталоге и добавляется переменная в скрипт
    if [[ -n "$select_dirfiles" ]]; then
      sed -i "2s%^%dirfiles=\"\$(dirname \"\$(realpath \$0)\")/$select_dirfiles\"\n%" "$tfs/$tempnamescript"
      ln -s "$dir_files_send/$select_dirfiles" "$tfs/$select_dirfiles"
    fi

    #Если тип выполнения скрипта autopassudo (автовведение sudo пароля), то добавляем в отправляемый скрипт переопределение дескриптора ввода (stdin) на /dev/tty во вторую строку. Изменение дескриптора ввода необходимо для возвращения интерактивности скрипту, т.к. повышение прав через sudo -S автоматически переназначает дескриптор ввода на pipe
    if [[ "$type_run_remote_script" = "autopassudo" ]]; then
      sed -i "2s%^%exec 0</dev/tty\n%" "$tfs/$tempnamescript"
    fi

    #Если рядом со скриптом есть файл script.conf и показ запроса не отключен, то задается вопрос нужно ли внести изменения в переменные отправляемого скрипта
    if [[ -f "$dir_scripts/$namesendscript/script.conf" ]]; then

      if [[ "$skipchangescriptfile" -eq "0" ]]; then
        #Выбор, хотите ли вы внести изменения в переменные отправляемого скрипта
        infmsg="Вы хотите внести изменения в переменные копии файла отправляемого скрипта? [y/n]: "
        errmsg="Пропуск. Внесение изменений не требуется"
        yes_or_no

        if [[ "$ynaction" = "yes" ]]; then
          #Внесение изменений в переменные отправляемого скрипта
          changescriptfile
        fi
      fi
    fi

    #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
    if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
      debug=1
      set +x
    fi

    #Если тип выполнения autopassudo или cronscript
    if [[ "$type_run_remote_script" = "autopassudo" || "$type_run_remote_script" = "cronscript" ]]; then

      #Генерируем число интераций для openssl
      oiter="$(tr -dc '1-9' </dev/urandom | head -c 1)$(tr -dc '0-9' </dev/urandom | head -c 5)"

      #Если логин не root, то шифруем пароль и присваиваем его переменной
      if [[ "$logname" != "root" ]]; then
        #Шифрование пароля через OpenSSL и преобразование в base64
        epas="$(echo "export lpas='$(cat "$gpgfilepass" | gpg2 --decrypt -q --pinentry-mode loopback --batch --yes --passphrase "$(echo "$gpgpass" | base64 -d)" | openssl enc -base64 -aes-256-cbc -iter $oiter -pass pass:$(sha256sum "$tfs/$tempnamescript" | cut -d ' ' -f 1))'" | base64 -w0)"
      else
        epas=""
      fi

      #Формируем команду экспорта переменных и преобразовываем в base64
      rc="$(echo "export oiter='$oiter' tfsc='$tempnamescript' typers='$type_run_remote_script' dirrunscript='$remotedirrunscript' version_exec_script='$local_version_exec_script' sutype='$sutype'" | base64 -w0)"
    #Если используется другой тип выполнения
    else
      epas=""
      rc=""
    fi
    [[ $debug == 1 ]] && set -x && unset debug

    #Перезаписываем текущий элемент массива новыми данными
    list_param_send_script[$nlpss]="$namesendscript;$tempnamescript;$type_run_remote_script;$reboot_system_script_finish;$epas;$rc;$local_version_exec_script"
  done

  unset namesendscript
  unset select_dirfiles
  unset type_run_remote_script
  unset reboot_system_script_finish
  unset check_version_exec_script
  unset local_version_exec_script
  unset list_source_func
  unset epas
  unset rc
  unset tfs
  unset oiter
}

#Внесение изменений в переменные отправляемого скрипта
function changescriptfile {
  unset repeatcyclemain
  unset repeatcycle
  unset listparamchange
  unset tempparamtype
  unset nextnamevalue
  unset tempparamdesc
  unset tpnvalue
  unset templist_selectvalue
  unset cmdtempvalue
  unset tempvalue

  PS3="Введите номер: "
  COLUMNS=1

  #Составление списка переменных для изменения из файла script.conf
  readarray -d ';' -t listparamchange < <(cat "$dir_scripts/$namesendscript/script.conf" | sed -r '1,${/(^[[:space:]]*#|^$)/d}' | awk -F'[][]' '{print $2}' | grep -Ev '^$' | tr '\n' ';' | sed -e 's/.$//g')

  #Если значений в массиве listparamchange больше нуля, то продолжается выполнение
  if [[ "${#listparamchange[@]}" -gt "0" ]]; then
    let repeatcyclemain=1
    let numlastvalue=${#listparamchange[@]}-1

    while [[ "$repeatcyclemain" -eq "1" ]]; do

      #Перебор списка переменных
      for ((i = 0; i < ${#listparamchange[@]}; i++)); do

        unset nextnamevalue

        #Продолжаем, если значение не пустое
        if [[ -n "${listparamchange[i]}" ]]; then

          #Продолжаем, если указанная переменная найдена в скрипте
          if [[ -n "$(cat "$tfs/$tempnamescript" | grep "${listparamchange[i]}=")" ]]; then

            #Присваиваем имя следующей переменной для использования в фильтре далее
            if [[ "$i" -eq "$numlastvalue" ]]; then
              nextnamevalue="${listparamchange[i]}"
            else
              nextnamevalue="${listparamchange[i + 1]}"
            fi

            unset tempparamtype

            #Определяем тип переменной
            tempparamtype="$(sed -nr "/^\[${listparamchange[i]}\]/,/^\[$nextnamevalue\]/p" "$dir_scripts/$namesendscript/script.conf" | sed -nr "{ :l /^typevalue[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

            #Продолжаем, если указан допустимый тип
            if [[ "$tempparamtype" = "number" ]] || [[ "$tempparamtype" = "text" ]] || [[ "$tempparamtype" = "list" ]] || [[ "$tempparamtype" = "massive" ]] || [[ "$tempparamtype" = "truefalse" ]]; then

              unset tempparamdesc

              #Считываем описание переменной
              tempparamdesc="$(sed -nr "/^\[${listparamchange[i]}\]/,/^\[$nextnamevalue\]/p" "$dir_scripts/$namesendscript/script.conf" | sed -nr "{ :l /^descvalue[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

              #Продолжаем, если описание не пусто
              if [[ -n "$tempparamdesc" ]]; then
                unset tpnvalue

                #Получаем текущее значение переменной в скрипте
                tpnvalue="$(sed -nr "{ :l /${listparamchange[i]}[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$tfs/$tempnamescript")"

                echo -e "\nТип переменной: $tempparamtype"
                echo "Описание: $tempparamdesc"
                echo "Текущее значение: $tpnvalue"

                #Выбор, хотите ли вы внести изменения в найденную переменную
                infmsg="Вы хотите внести изменение в переменную ${listparamchange[i]}? [y/n]: "
                errmsg="Изменение переменной ${listparamchange[i]} пропущено"
                yes_or_no

                #Если ответ да, то запускаем ввод/выбор значения в зависимости от типа переменной
                if [[ "$ynaction" = "yes" ]]; then
                  let repeatcycle=1

                  while [[ "$repeatcycle" -eq "1" ]]; do
                    tempvalue=""

                    #Если тип ввода 'число'
                    if [[ "$tempparamtype" = "number" ]]; then

                      title_msg="Ввод значения"
                      text_msg="Введите числовое значение"

                      #Вывод запроса пока переменная пуста
                      while [[ -z "$tempvalue" ]]; do

                        if [[ "$exec_no_display" -eq "1" ]]; then
                          tempvalue="$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --title "$title_msg" --inputbox "$text_msg" 18 70)"
                        else
                          tempvalue="$(input_text_zenity)"
                        fi

                        #Если введенное значение не является числом, то зануляем переменную
                        if ! [[ "$tempvalue" =~ $check_num ]]; then
                          tempvalue=""
                        fi
                      done
                    fi

                    #Если тип ввода 'текст'
                    if [[ "$tempparamtype" = "text" ]]; then

                      title_msg="Ввод значения"
                      text_msg="Введите текстовое значение"

                      if [[ "$exec_no_display" -eq "1" ]]; then
                        tempvalue="'$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --title "$title_msg" --inputbox "$text_msg" 18 70 | sed 's/\\/\\\\/g;s/&/\\\&/g;s/%/\\%/g;s/"/\\"/g;s/`/\\`/g' | sed "s/'/\'\\\\\\\'\'/g")'"
                      else
                        tempvalue="'$(input_text_zenity | sed 's/\\/\\\\/g;s/&/\\\&/g;s/%/\\%/g;s/"/\\"/g;s/`/\\`/g' | sed "s/'/\'\\\\\\\'\'/g")'"
                      fi
                    fi

                    #Если тип ввода 'Список'
                    if [[ "$tempparamtype" = "list" ]]; then

                      unset templist_selectvalue

                      #Формируем список значений для выбора
                      readarray -d ';' -t templist_selectvalue < <(sed -nr "/^\[${listparamchange[i]}\]/,/^\[$nextnamevalue\]/p" "$dir_scripts/$namesendscript/script.conf" | sed -nr "{ :l /^listvalue[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr ';' '\n' | grep -Ev '^$' | sort -u | tr '\n' ';' | sed -e 's/.$//g')

                      #Продолжаем, если список не пуст
                      if [[ "${#templist_selectvalue[@]}" -gt "0" ]]; then

                        title_msg="Выбор значения"
                        text_msg="Выберите значение из списка:"
                        name_variable='tempvalue'

                        #Вывод запроса пока переменная пуста
                        while [[ -z "$tempvalue" ]]; do

                          if [[ "$exec_no_display" -eq "1" ]]; then
                            echo -e "\n$text_msg"
                            select_use_value
                            tempvalue="$(sed 's/\\/\\\\/g;s/&/\\\&/g;s/%/\\%/g;s/"/\\"/g;s/`/\\`/g;s/\$/\\$/g' <<<"$tempvalue" | sed "s/'/\'\\\\\\\'\'/g")"
                          else
                            tempvalue="$(select_use_value_zenity | sed 's/\\/\\\\/g;s/&/\\\&/g;s/%/\\%/g;s/"/\\"/g;s/`/\\`/g;s/\$/\\$/g' | sed "s/'/\'\\\\\\\'\'/g")"
                          fi
                        done

                        #Добавляем одинарные кавычки
                        tempvalue="'$tempvalue'"
                      else
                        echo -e "${RED}Переменная ${listparamchange[i]} имеет тип list, но listvalue не заполнен в секции ${listparamchange[i]} файла script.conf. Изменение пропущено, заполните listvalue для выбора значения $NoColor"
                        break
                      fi

                    fi

                    #Если тип ввода 'массив'
                    if [[ "$tempparamtype" = "massive" ]]; then
                      tempvalue=""

                      title_msg="Ввод значения массива"
                      text_msg="Введите значение массива:"

                      #Запускаем бесконечный цикл
                      while true; do
                        #Добавляем значения в массив

                        if [[ "$exec_no_display" -eq "1" ]]; then
                          if [[ -z "${tempvalue:0:10}" ]]; then
                            tempvalue="'$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --title "$title_msg" --inputbox "$text_msg" 18 70 | sed 's/\\/\\\\/g;s/&/\\\&/g;s/%/\\%/g;s/"/\\"/g;s/`/\\`/g;s/`/\`/g;s/)/\\)/g;s/(/\\(/g' | sed "s/'/\'\\\\\\\'\'/g")'"
                          else
                            tempvalue="${tempvalue} '$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --title "$title_msg" --inputbox "$text_msg" 18 70 | sed 's/\\/\\\\/g;s/&/\\\&/g;s/%/\\%/g;s/"/\\"/g;s/`/\`/g;s/)/\\)/g;s/(/\\(/g' | sed "s/'/\'\\\\\\\'\'/g")'"
                          fi
                        else
                          if [[ -z "${tempvalue:0:10}" ]]; then
                            tempvalue="'$(input_text_zenity | sed 's/\\/\\\\/g;s/&/\\\&/g;s/%/\\%/g;s/"/\\"/g;s/`/\\`/g;s/`/\`/g;s/)/\\)/g;s/(/\\(/g' | sed "s/'/\'\\\\\\\'\'/g")'"
                          else
                            tempvalue="${tempvalue} '$(input_text_zenity | sed 's/\\/\\\\/g;s/&/\\\&/g;s/%/\\%/g;s/"/\\"/g;s/`/\`/g;s/)/\\)/g;s/(/\\(/g' | sed "s/'/\'\\\\\\\'\'/g")'"
                          fi
                        fi

                        echo ""
                        infmsg="Ввести еще одно значение? [y/n]: "
                        errmsg="Добавление значений массива в файл скрипта"
                        yes_or_no

                        #Если ответ 'нет', то помещаем значение в скобки и выходим из цикла
                        if [[ "$ynaction" != "yes" ]]; then
                          tempvalue="($tempvalue)"
                          break
                        fi
                      done
                    fi

                    #Если тип ввода 'выбор 0/1'
                    if [[ "$tempparamtype" = "truefalse" ]]; then

                      title_msg="Выбор значения"
                      text_msg="Выберите значение:"
                      name_variable='tempvalue'
                      templist_selectvalue=("0" "1")

                      #Пока значение пустое, выводим запрос
                      while [[ -z "$tempvalue" ]]; do
                        if [[ "$exec_no_display" -eq "1" ]]; then
                          echo -e "\n$text_msg"
                          select_use_value
                        else
                          tempvalue="$(select_use_value_zenity)"
                        fi
                      done
                    fi

                    #Внесение изменений в первую найденную переменную
                    sed -i "0,/${listparamchange[i]}=.*/s%${listparamchange[i]}=.*%${listparamchange[i]}=$tempvalue%" "$tfs/$tempnamescript"
                    sleep 0.350s

                    echo ""
                    echo "Новое значение переменной ${listparamchange[i]} в файле: $(sed -nr "{ :l /${listparamchange[i]}[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$tfs/$tempnamescript")"
                    infmsg="Продолжить с новым значением или изменить его? [y/n]: "
                    errmsg="Повторное изменение значения переменной ${listparamchange[i]}"
                    yes_or_no

                    if [[ "$ynaction" = "yes" ]]; then
                      echo "Выполнение продолжено с новым значением"
                      let repeatcycle=0
                    fi
                  done
                fi
              else
                echo -e "${RED}Не заполнено описание переменной ${listparamchange[i]} $NoColor"
              fi
            else
              echo -e "${RED}Некорректный тип переменной ${listparamchange[i]} в файле script.conf. Допустимые значения:
number - любое число
text - текстовое поле
list - выбор из заданного списка значений
massive - при выборе данного типа будет запрос значений для массива
truefalse - выбор из значений 0/1
$NoColor"
            fi
          else
            echo -e "${RED}Переменная ${listparamchange[i]} не найдена в файле скрипта$NoColor"
          fi
        fi
      done
      echo -e "${YELLOW}\n-----Содержимое отправляемого файла-----\n$NoColor"
      cat "$tfs/$tempnamescript"
      echo -e "${YELLOW}\n-----Конец содержимого отправляемого файла-----\n$NoColor"

      infmsg="Завершить внесение изменений в отправляемый скрипт? (проверьте корректность внесенных изменений в файл) [y/n]: "
      errmsg="Запущено повторное изменение переменных"
      yes_or_no

      if [[ "$ynaction" = "yes" ]]; then
        echo -e "${YELLOW}Внесение изменений в отправляемый скрипт завершено$NoColor"
        unset repeatcyclemain
        unset repeatcycle
        unset listparamchange
        unset tempparamtype
        unset nextnamevalue
        unset tempparamdesc
        unset tpnvalue
        unset cmdtempvalue
        unset tempvalue
        unset title_msg
        unset text_msg
        unset name_variable
        unset templist_selectvalue
      fi
    done
  else
    echo -e "${RED}В файле script.conf не найдены имена переменных для изменения$NoColor"
  fi
}

#Выбор типа поиска хостов
function select_type_find_hosts {
  while true; do
    PS3="Введите номер: "
    COLUMNS=1

    echo ""
    select type_find_hosts in "Ввести имена/ip адреса устройств (каждое значение в отдельном запросе)" "Выбрать из списка доступных в сети устройств (будет просканирована сеть по выбранному вами далее файлу хостов)" "Отправить на все доступные в сети устройства (к данному пункту применяются списки исключения) (будет просканирована сеть по выбранному вами далее файлу хостов)" "Вернуться в меню выбора скриптов (Список выбранных скриптов и сопутствующих переменных обнулится. Временные файлы будут удалены)"; do
      list_ipall=()

      echo ""

      if [[ "$REPLY" =~ $check_num ]]; then

        #Блок для выполнения, если выбрано введение значений
        if [[ "$REPLY" -eq "1" ]]; then
          #Ввод и выбор устройств имеют тип sshonesend (не применяются списки исключения).
          #Рассылка на все устройства в сети имеет тип sshmultisend (применяются списки исключения).
          typesend="sshonesend"

          title_msg="Ввод хоста"
          text_msg="Введите имя или ip адрес хоста:"

          while true; do
            hostnamevalue=""

            while ! [[ "$hostnamevalue" =~ $check_hostname_or_ip ]]; do
              echo -e "${YELLOW}Значение может содержать следующие символы: A-Z a-z А-Я а-я 0-9 . - $NoColor"

              if [[ "$exec_no_display" -eq "1" ]]; then
                hostnamevalue="$(dialog --output-fd 1 --keep-tite --no-cancel --no-shadow --title "$title_msg" --inputbox "$text_msg" 18 70)"
              else
                hostnamevalue="$(input_text_zenity)"
              fi
            done

            infmsg="Введено значение $hostnamevalue. Продолжить? [y/n]: "
            errmsg="Введите значение заново"
            yes_or_no

            #Если выбрано продолжить, то запускается добавление введенного устройства к массиву, иначе имя/ip адрес устройства будет запрошен заново
            if [[ "$ynaction" = "yes" ]]; then

              list_ipall[${#list_ipall[@]}]="$hostnamevalue"

              infmsg="Вы хотите ввести еще одно значение? [y/n]: "
              errmsg="Добавление дополнительного значения пропущено"
              yes_or_no

              if [[ "$ynaction" != "yes" ]]; then
                list_ipall=($(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$' | sort -u))
                echo -e "\nСписок введенных адресов (количество: ${#list_ipall[@]}):
$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')"

                infmsg="Вы хотите продолжить с данным списком адресов или ввести значения заново? [y/n]: "
                errmsg="Список обнулен. Введите значения заново"
                yes_or_no

                if [[ "$ynaction" = "yes" ]]; then
                  break
                else
                  list_ipall=()
                fi
              fi
            fi
          done

          unset hostnamevalue
          unset title_msg
          unset text_msg

          splitting_list_into_parts
          break 2
        fi

        #Блок для выполнения, если выбор из списка доступных в сети устройств
        if [[ "$REPLY" -eq "2" ]]; then
          typesend="sshonesend"

          #Выбор файла хостов
          create_list_files_hosts

          #Если файл хостов выбран, то запуск формирования списка доступных в сети устройств
          if [[ -n "$select_file_hosts" ]]; then
            create_listip

            if [[ "${#list_ipall[@]}" -gt "0" ]]; then

              #Если список не пуст, то записываем значения массива во временный массив
              listselecthost=("${list_ipall[@]}")

              #Обнуляем массив list_ipall, т.к. далее в него будут записаны выбранные значения
              list_ipall=()

              while true; do
                PS3="Введите номер: "
                COLUMNS=1

                echo -e "Устройств в списке: ${#listselecthost[@]}\n"

                select selecthost in "${listselecthost[@]}"; do

                  if [[ "$REPLY" =~ $check_num ]]; then

                    if [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "${#listselecthost[@]}" ]]; then

                      #Добавляем к массиву ip адрес из выбранного значения
                      list_ipall[${#list_ipall[@]}]="$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' <<<"$selecthost")"

                      #Если найдено более одного значения, то будет вопрос о выборе еще одного значения.
                      #Если же найдено только одно значение, то будет запуск отправки.
                      if [[ "${#listselecthost[@]}" -gt "1" ]]; then
                        infmsg="Вы хотите выбрать еще одно значение? [y/n]: "
                        errmsg="Выбор дополнительного значения пропущен"
                        yes_or_no

                        if [[ "$ynaction" = "yes" ]]; then
                          break
                        else
                          list_ipall=($(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$' | sort -u))
                          echo -e "\nСписок выбранных адресов (количество: ${#list_ipall[@]}):
$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')"

                          infmsg="Вы хотите продолжить с данным списком адресов или выбрать значения заново? [y/n]: "
                          errmsg="Возврат в меню выбора"
                          yes_or_no

                          if [[ "$ynaction" = "yes" ]]; then
                            unset listselecthost
                            unset selecthost
                            splitting_list_into_parts
                            break 4
                          else
                            break 3
                          fi
                        fi
                      else
                        unset listselecthost
                        unset selecthost
                        splitting_list_into_parts
                        break 4
                      fi
                    fi
                  fi
                  break
                done
              done
            else
              echo -e "\nНе обнаружено устройств в сети по выбранному списку хостов\n"
              break
            fi
          fi
        fi

        #Если выбрана отправка на все доступные в сети устройства
        if [[ "$REPLY" -eq "3" ]]; then
          typesend="sshmultisend"
          create_list_files_hosts

          if [[ -n "$select_file_hosts" ]]; then
            create_listip
            if [[ "${#list_ipall[@]}" -gt "0" ]]; then
              break 2
            else
              echo -e "\nНе обнаружено устройств в сети по выбранному списку хостов\n"
              break
            fi
          fi
        fi

        #Блок выхода в меню скриптов с удалением временных файлов и переменных
        if [[ "$REPLY" -eq "4" ]]; then
          delsendfiles
          unset_send_values
          break 2
        fi
      fi
      break
    done
  done
}

#Генерация и выбор списка файлов хостов
function create_list_files_hosts {
  unset select_file_hosts
  unset list_file_hosts

  #Формирование списка файлов хостов
  readarray -d ';' -t list_file_hosts < <(find ./conf/fileshosts -type f | sed -e "s/^..//" | grep -Eo '^[A-Za-zА-Яа-я0-9(),./@_[:space:]-]+$' | grep -Ev '^$' | sort -u | tr '\n' ';' | sed -e 's/.$//g')
  echo "Обнаружено файлов хостов: ${#list_file_hosts[@]}"
  echo ""

  #Продолжаем ,если список не пуст
  if [[ "${#list_file_hosts[@]}" -gt "0" ]]; then

    while true; do
      PS3="Введите номер: "
      COLUMNS=1

      #Выбор файла хостов
      select select_file_hosts in "${list_file_hosts[@]}"; do

        echo ""
        if [[ "$REPLY" =~ $check_num ]]; then

          if [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "${#list_file_hosts[@]}" ]]; then
            echo "Выбран файл: $dir_runscript/$select_file_hosts"
            echo ""
            unset list_file_hosts
            break 2
          fi
        fi
        break
      done
    done
  else
    echo -e "\n${RED}Не обнаружены файлы хостов $NoColor\n"
  fi
}

#Генерация списка ip адресов для отправки
function create_listip {
  #Считывание в массив строк из выбранного файла хостов
  readarray -d ';' -t subnetaddres < <(printf "%s" $(cat "$dir_runscript/$select_file_hosts" | grep -iv '#' | grep -Ev '^$' | sort | tr '\n' ';' | sed -e 's/.$//g'))

  echo -e "Количество записей для поиска устройств в сети: ${#subnetaddres[@]}\n"

  #Если массив не пуст, то выполнение продолжается
  if [[ "${#subnetaddres[@]}" -gt "0" ]]; then

    #Если отправка на все устройства в сети, то показать количество записей в списках исключений
    if [[ "$typesend" = "sshmultisend" ]]; then
      echo "Количество записей исключения устройств по частичному совпадению: ${#listIgnoreInaccurate[@]}"
      echo "Количество записей исключения устройств по точному совпадению: ${#listIgnoreAccurate[@]}"
    fi

    echo -e "\nПоиск устройств в сети\n"

    #Формирование массива с найденными в сети устройствами
    readarray -d ';' -t list_ipall < <(nmap -sP -iL "$dir_runscript/$select_file_hosts" 2>/dev/null | grep -E '^Nmap scan' | sed "s/Nmap scan report for //g" | sort -u | tr '\n' ';' | sed -e 's/.$//g')

    #Блок кода только для отправки на все устройства
    if [[ "$typesend" = "sshmultisend" ]]; then

      let col_value_ignore=0

      if [[ "${#list_ipall[@]}" -gt "0" ]]; then
        #Если записей для пропуска по частичному совпадению больше 0, то выполняем фильтрацию. За 1 цикл одновременно ищется 15 элементов из списка исключения.
        if [[ "${#listIgnoreInaccurate[@]}" -gt "0" ]]; then

          echo -e "Запущена проверка и фильтрация значений по частичному совпадению\n"

          if [[ "${#listIgnoreInaccurate[@]}" -lt "15" ]]; then
            let intervalvalue=${#listIgnoreInaccurate[@]}
          else
            let intervalvalue=15
          fi

          #Вычисление количества необходимых циклов
          let colcycle="(${#listIgnoreInaccurate[@]}/$intervalvalue)"

          #Вычисление остатка от деления
          let modulecolcycle="${#listIgnoreInaccurate[@]}%$intervalvalue"

          for ((i = 0; i < $colcycle; i++)); do
            if [[ "${#list_ipall[@]}" -gt "0" ]]; then
              let startvalue=$intervalvalue*$i

              unset col_ignore

              col_ignore="$(grep -Ei "$(tr '\n ' '|' <<<"${listIgnoreInaccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')" | wc -l)"

              #Если найдены значения из списка исключения в списке хостов, то фильтруем и перезаписываем переменную
              if [[ "$col_ignore" -gt "0" ]]; then
                list_ipall=($(grep -Eiv "$(tr '\n ' '|' <<<"${listIgnoreInaccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')"))
                let col_value_ignore+=$col_ignore
              fi
            else
              break
            fi
          done

          if [[ "${#list_ipall[@]}" -gt "0" ]]; then
            #Если остаток от деления не равен нулю, то оставшиеся значения проверяем в последнем условии
            if [[ "$modulecolcycle" -ne "0" ]]; then
              let startvalue=$intervalvalue*$colcycle

              unset col_ignore

              col_ignore="$(grep -Ei "$(tr '\n ' '|' <<<"${listIgnoreInaccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')" | wc -l)"

              #Если найдены значения из списка исключения в списке хостов, то фильтруем и перезаписываем переменную
              if [[ "$col_ignore" -gt "0" ]]; then
                list_ipall=($(grep -Eiv "$(tr '\n ' '|' <<<"${listIgnoreInaccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')"))
                let col_value_ignore+=$col_ignore
              fi
            fi
          fi
        fi
      fi

      #Если список адресов не пуст
      if [[ "${#list_ipall[@]}" -gt "0" ]]; then
        #Если записей для пропуска по точному совпадению больше 0, то выполняем фильтрацию. За 1 цикл одновременно ищется 15 элементов из списка исключения.
        if [[ "${#listIgnoreAccurate[@]}" -gt "0" ]]; then

          echo -e "Запущена проверка и фильтрация значений по точному совпадению\n"

          if [[ "${#listIgnoreAccurate[@]}" -lt "15" ]]; then
            let intervalvalue=${#listIgnoreAccurate[@]}
          else
            let intervalvalue=15
          fi

          #Вычисление количества необходимых циклов
          let colcycle="(${#listIgnoreAccurate[@]}/$intervalvalue)"

          #Вычисление остатка от деления
          let modulecolcycle="${#listIgnoreAccurate[@]}%$intervalvalue"

          for ((i = 0; i < $colcycle; i++)); do
            if [[ "${#list_ipall[@]}" -gt "0" ]]; then
              let startvalue=$intervalvalue*$i

              unset col_ignore

              col_ignore="$(grep -Eiw "$(tr '\n ' '|' <<<"${listIgnoreAccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')" | wc -l)"

              #Если найдены значения из списка исключения в списке хостов, то фильтруем и перезаписываем переменную
              if [[ "$col_ignore" -gt "0" ]]; then
                list_ipall=($(grep -Eivw "$(tr '\n ' '|' <<<"${listIgnoreAccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')"))
                let col_value_ignore+=$col_ignore
              fi
            else
              break
            fi
          done

          if [[ "${#list_ipall[@]}" -gt "0" ]]; then
            #Если остаток от деления не равен нулю, то оставшиеся значения проверяем в последнем условии
            if [[ "$modulecolcycle" -ne "0" ]]; then
              let startvalue=$intervalvalue*$colcycle

              unset col_ignore

              col_ignore="$(grep -Eiw "$(tr '\n ' '|' <<<"${listIgnoreAccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')" | wc -l)"

              #Если найдены значения из списка исключения в списке хостов, то фильтруем и перезаписываем переменную
              if [[ "$col_ignore" -gt "0" ]]; then
                list_ipall=($(grep -Eivw "$(tr '\n ' '|' <<<"${listIgnoreAccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')"))
                let col_value_ignore+=$col_ignore
              fi
            fi
          fi
        fi
      fi

      echo -e "\nКоличество исключенных устройств: $col_value_ignore\n"

      #Если список устройств не пуст, то фильтруем значения оставляя только ip адрес устройства
      if [[ "${#list_ipall[@]}" -gt "0" ]]; then
        #Формируем массив ip адресов
        list_ipall=($(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' <<<"$(sed 's/^ //' <<<"${list_ipall[@]/%/$'\n'}" | grep -v '^$')" | sort -t '.' -k 1,1n -k 2,2n -k 3,3n -k 4,4n -u))
      fi

      #Разбивка списка адресов на количество потоков
      splitting_list_into_parts
    fi
  fi

  unset subnetaddres
  unset col_value_ignore
  unset intervalvalue
  unset col_ignore
  unset startvalue
  unset colcycle
  unset modulecolcycle
}

#Разделение списка устройств на количество потоков
function splitting_list_into_parts {
  echo -e "Устройств в списке: ${#list_ipall[@]}\n"

  #Продолжаем, если список адресов не пуст
  if [[ "${#list_ipall[@]}" -gt "0" ]]; then

    #Повторное считывание значения количества потоков отправки и его проверка
    multisend="$(sed -nr "/^\[$use_section_settings\]/,/^\[$nextsection\]/p" "$dir_conf/sssc.conf" | sed -nr "{ :l /^multisend[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" | tr -d '\n')"

    if ! [[ "$multisend" =~ $check_num ]] || [[ "$multisend" -le "0" ]]; then
      multisend="1"
    fi

    #Если количество потоков превышает количество найденных ip, то количество потоков будет равно количеству найденных ip
    if [[ "$multisend" -gt "${#list_ipall[@]}" ]]; then
      let multisend=${#list_ipall[@]}
    fi

    echo "Количество потоков: $multisend"

    #Если количество потоков больше 1, то разбивка массива найденных ip на указанное количество потоков
    if [[ "$multisend" -gt "1" ]]; then

      #Вычисление значения, сколько устройств должно быть в 1 потоке
      let ipcountinstream="${#list_ipall[@]}/$multisend"

      #Вычисление остатка от деления
      let moduleipcountinstream="${#list_ipall[@]}%$multisend"

      #Вычисление значения, сколько устройств должно быть в последнем потоке
      let ipcountlaststream="$ipcountinstream+$moduleipcountinstream"

      #Т.к. отсчет начинается с 0, отнимаем от количества потоков 1 и получаем номер последнего потока
      let lastmultisend="$multisend-1"

      #Запись в новый массив диапазона значений согласно условию
      for ((i = 0; i < $lastmultisend; i++)); do
        let j=$ipcountinstream*$i
        list_ip[$i]=$(echo "${list_ipall[@]:$j:$ipcountinstream}")
      done

      #Запись в новый массив диапазона значений согласно условию для последнего потока
      let j=$ipcountinstream*$lastmultisend
      list_ip[$lastmultisend]=$(echo "${list_ipall[@]:$j:$ipcountlaststream}")
    fi
  fi

  unset ipcountinstream
  unset moduleipcountinstream
  unset ipcountlaststream
  unset lastmultisend
}

#Запуск отправки в зависимости от количества потоков
function prerunsend {
  #Если массив ip адресов не пуст и значение потоков рассылки равно 1
  if [[ "${#list_ipall[@]}" -gt "0" ]] && [[ "$multisend" -eq "1" ]]; then
    runsend
    delsendfiles
  fi

  #Если массив ip адресов не пуст и значение потоков рассылки больше 1
  if [[ "${#list_ipall[@]}" -gt "0" ]] && [[ "$multisend" -gt "1" ]]; then
    trfs="$temp_dir_send_script/runmultisend-$value_date"

    mkdir -p "$trfs/"

    session="sssc-$value_date"

    #Если переменная console_or_multiplexer равна 1, то создается сессия tmux, если он выбран в параметре typeterminalmultiplexer
    if [[ "$console_or_multiplexer" -eq "1" ]]; then

      if [[ "$typeterminalmultiplexer" = "tmux" ]]; then
        let window=0
        tmux set-option -g history-limit 5000 \; set-option -g mouse on \; new-session -d -s $session
      fi
    fi

    if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
      debug=1
      set +x
    fi

    #Выполняемая команда, которая записана в переменную в base64
    tcms="$(echo "sshtypecon=\"$sshtypecon\"; sshkeyfile=\"$sshkeyfile\"; logname=\"$logname\"; gpgfilepass=\"$gpgfilepass\"; gpgpass=\"$gpgpass\"; runsend" | base64 -w0)"

    [[ $debug == 1 ]] && set -x && unset debug

    for ((i = 0; i < $multisend; i++)); do

      #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
      if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
        debug=1
        set +x
      fi

      unset namescript

      #Создаем скрипт запуска выполнения для потока
      echo "#!/bin/bash
namescript=\"sssc$i\"
dir_runscript=\"$dir_runscript\"
path_exec_script_version=\"$path_exec_script_version\"
source \"\$dir_runscript/func.sh\"
force_exec_script=\"$force_exec_script\"
multisend=\"$multisend\"
reboot_max_try_wait_devaice=\"$reboot_max_try_wait_devaice\"
reboot_time_wait_devaice=\"$reboot_time_wait_devaice\"
remotedirgroup=\"$remotedirgroup\"
sshtimeout=\"$sshtimeout\"
numportssh=\"$numportssh\"
typesendfiles=\"$typesendfiles\"
typesend=\"$typesend\"
list_ipall=($(echo ${list_ip[$i]}))
listIgnoreInaccurate=($([[ "${#listIgnoreInaccurate[@]}" -gt "0" ]] && echo "${listIgnoreInaccurate[@]/%/$'\''}" | sed "s/' /' '/g" | sed "s/^/'/"))
listIgnoreAccurate=($([[ "${#listIgnoreAccurate[@]}" -gt "0" ]] && echo "${listIgnoreAccurate[@]/%/$'\''}" | sed "s/' /' '/g" | sed "s/^/'/"))
list_param_send_script=($(echo "${list_param_send_script[@]/%/$'\''}" | sed "s/' /' '/g" | sed "s/^/'/"))
remotedirrunscript=\"$remotedirrunscript\"
value_date=\"$value_date\"
temp_dir_send_script=\"$temp_dir_send_script\"
tcms=\"$tcms\"
eval \`echo \"\$tcms\" | base64 -d\`
rm -f -v \"\$0\"" >"$trfs/$i-$session"

      [[ $debug == 1 ]] && set -x && unset debug

      #Даем право выполнения на созданный файл скрипта
      chmod +x "$trfs/$i-$session"

      #Если console_or_multiplexer равен 0, то запуск каждого потока в фоновом режиме текущего окна консоли. При обычном запуске без параметров console_or_multiplexer будет всегда равен 1.
      if [[ "$console_or_multiplexer" -eq "0" ]]; then
        (
          export HISTFILE=/dev/null
          sh "$trfs/$i-$session"
        ) &
      else
        #Если выбран tmux
        if [[ "$typeterminalmultiplexer" = "tmux" ]]; then

          #Если это второй и более поток
          if [[ "$window" -gt "0" ]]; then
            tmux new-window -t $session:$window -n "sshsend$window"
          fi

          tmux send-keys -t $session:$window "export HISTFILE=/dev/null; stty -icanon" C-m
          tmux send-keys -t $session:$window "bash \"$trfs/$i-$session\"; exit" C-m
          let window+=1

          #Если выбран screen
        elif [[ "$typeterminalmultiplexer" = "screen" ]]; then

          #Если это первый поток
          if [[ "$i" -eq "0" ]]; then
            screen -c "$dir_conf/screenrc.conf" -dmS $session bash -c "export HISTFILE=/dev/null; bash \"$trfs/$i-$session\"; exit"
          #Если это второй и более поток
          elif [[ "$i" -gt "0" ]]; then
            screen -S $session -x -X screen bash -c "export HISTFILE=/dev/null; bash \"$trfs/$i-$session\"; exit"
          fi

        fi
      fi
    done

    #Если console_or_multiplexer равен 0, то ожидание завершения всех фоновых процессов и удаление файлов
    if [[ "$console_or_multiplexer" -eq "0" ]]; then
      wait
      delsendfiles

      multisend_exec_info_in_one_file
      echo -e "\n${GREEN}Выполнение завершено $NoColor\n"
    else
      #Ожидаем завершения сессии tmux/screen
      if [[ "$typeterminalmultiplexer" = "tmux" ]]; then
        tmux attach-session -t $session
        echo -e "${YELLOW}Ожидание завершения сессии tmux: $session $NoColor"

        while [[ -n "$(tmux ls 2>/dev/null | grep -w "$session")" ]]; do
          sleep 3s
        done

        echo -e "${GREEN}Сессия tmux $session завершена $NoColor"
      elif [[ "$typeterminalmultiplexer" = "screen" ]]; then
        screen -r $session
        echo -e "${YELLOW}Ожидание завершения сессии screen: $session $NoColor"

        while [[ -n "$(screen -ls 2>/dev/null | grep -w "$session")" ]]; do
          sleep 3s
        done

        echo -e "${GREEN}Сессия screen $session завершена $NoColor"
      fi

      #Удаляем файлы
      delsendfiles

      multisend_exec_info_in_one_file
      echo -e "\n${GREEN}Выполнение завершено $NoColor\n"
    fi
  fi

  unset_send_values
}

#Сбор финальной информации о выполнении при многопоточной отправке в один файл
function multisend_exec_info_in_one_file {
  echo -e "\n${GREEN}Запущена обработка log файлов$NoColor\n"

  #Каталог лог файлов при многопоточной отправке
  sendlogs="$dir_logs/${value_date}_$(echo "${list_param_send_script[0]}" | cut -d ';' -f 1)_${#list_param_send_script[@]}"

  mkdir -p "$sendlogs"

  echo -e "Общая информация о выполнении\n" >>"$sendlogs/all-sendinfo.txt"

  let sum_num_devices_access=0

  if [[ -f "$sendlogs/tmp-sum_devices" ]]; then
    temp_massive_values=($(cat "$sendlogs/tmp-sum_devices" | grep -Ev '^$'))
    rm -f "$sendlogs/tmp-sum_devices"

    for ((num_value = 0; num_value < ${#temp_massive_values[@]}; num_value++)); do
      let sum_num_devices_access+=${temp_massive_values[$num_value]}
    done

    unset temp_massive_values
  fi

  if [[ -f "$sendlogs/tmp-successful_exec_script" ]]; then
    echo -e "${GREEN}Успешное выполнение (Записей в списке: $(wc -l <"$sendlogs/tmp-successful_exec_script")$([[ "${#list_param_send_script[@]}" -eq "1" ]] && echo "; Доступно устройств: $sum_num_devices_access")): $NoColor" >>"$sendlogs/all-sendinfo.txt"

    cat "$sendlogs/tmp-successful_exec_script" | sort >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
    rm -f "$sendlogs/tmp-successful_exec_script"
  else
    echo -e "${GREEN}Успешное выполнение (Записей в списке: 0$([[ "${#list_param_send_script[@]}" -eq "1" ]] && echo "; Доступно устройств: $sum_num_devices_access")): $NoColor" >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
  fi

  if [[ -f "$sendlogs/tmp-successful_exec_full_scripts" ]]; then
    echo -e "${GREEN}Успешное выполнение всех отправленных скриптов (Записей в списке: $(wc -l <"$sendlogs/tmp-successful_exec_full_scripts"); Доступно устройств: $sum_num_devices_access): $NoColor" >>"$sendlogs/all-sendinfo.txt"

    cat "$sendlogs/tmp-successful_exec_full_scripts" | sort >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
    rm -f "$sendlogs/tmp-successful_exec_full_scripts"
  else
    if [[ "${#list_param_send_script[@]}" -gt "1" ]]; then
      echo -e "${GREEN}Успешное выполнение всех отправленных скриптов (Записей в списке: 0; Доступно устройств: $sum_num_devices_access): $NoColor" >>"$sendlogs/all-sendinfo.txt"
      echo "" >>"$sendlogs/all-sendinfo.txt"
    fi
  fi

  if [[ -f "$sendlogs/tmp-skip_host" ]]; then
    echo -e "${YELLOW}Пропущенные устройства (Записей в списке: $(wc -l <"$sendlogs/tmp-skip_host"); Доступно устройств: $sum_num_devices_access): $NoColor" >>"$sendlogs/all-sendinfo.txt"

    cat "$sendlogs/tmp-skip_host" | sort >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
    rm -f "$sendlogs/tmp-skip_host"
  else
    echo -e "${YELLOW}Пропущенные устройства (Записей в списке: 0; Доступно устройств: $sum_num_devices_access): $NoColor" >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
  fi

  if [[ -f "$sendlogs/tmp-failed_scripts" ]]; then
    echo -e "${RED}Выполнение с ошибкой (Записей в списке: $(wc -l <"$sendlogs/tmp-failed_scripts")$([[ "${#list_param_send_script[@]}" -eq "1" ]] && echo "; Доступно устройств: $sum_num_devices_access")): $NoColor" >>"$sendlogs/all-sendinfo.txt"

    cat "$sendlogs/tmp-failed_scripts" | sort >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
    rm -f "$sendlogs/tmp-failed_scripts"
  else
    echo -e "${RED}Выполнение с ошибкой (Записей в списке: 0$([[ "${#list_param_send_script[@]}" -eq "1" ]] && echo "; Доступно устройств: $sum_num_devices_access")): $NoColor" >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
  fi

  if [[ -f "$sendlogs/tmp-devices_err_exec_scripts" ]]; then
    echo -e "${RED}Устройства с ошибками (Записей в списке: $(wc -l <"$sendlogs/tmp-devices_err_exec_scripts"); Доступно устройств: $sum_num_devices_access): $NoColor" >>"$sendlogs/all-sendinfo.txt"

    cat "$sendlogs/tmp-devices_err_exec_scripts" | sort >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
    rm -f "$sendlogs/tmp-devices_err_exec_scripts"
  else
    if [[ "${#list_param_send_script[@]}" -gt "1" ]]; then
      echo -e "${RED}Устройства с ошибками (Записей в списке: 0; Доступно устройств: $sum_num_devices_access): $NoColor" >>"$sendlogs/all-sendinfo.txt"
      echo "" >>"$sendlogs/all-sendinfo.txt"
    fi
  fi

  if [[ -f "$sendlogs/tmp-failed_conn" ]]; then
    echo -e "${RED}Устройства к которым нет доступа (Записей в списке: $(wc -l <"$sendlogs/tmp-failed_conn")): $NoColor" >>"$sendlogs/all-sendinfo.txt"

    cat "$sendlogs/tmp-failed_conn" | sort -f -V >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
    rm -f "$sendlogs/tmp-failed_conn"
  else
    echo -e "${RED}Устройства к которым нет доступа (Записей в списке: 0): $NoColor" >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
  fi

  unset sum_num_devices_access

  cat "$sendlogs/all-sendinfo.txt"

  echo -e "\nИнформация по каждому потоку\n" >>"$sendlogs/all-sendinfo.txt"

  for file_log in $(ls -1 "$sendlogs" | grep "^sssc"); do
    echo -e "Файл $file_log\n" >>"$sendlogs/all-sendinfo.txt"
    cat "$sendlogs/$file_log" | sed -nr "/^-----Информация/,/^-----Конец информации/p" >>"$sendlogs/all-sendinfo.txt"
    echo "" >>"$sendlogs/all-sendinfo.txt"
  done

  unset file_log

  echo -e "${GREEN}Обработка log файлов завершена$NoColor"
}

#Удаление переменных
function unset_send_values {
  unset list_ipall
  unset list_ip
  unset epas
  unset cspas
  unset rc
  unset tempnamescript
  unset tfs
  unset tcms
  unset sendlogs
  unset type_run_remote_script
  unset typesend
  unset oiter
  unset trfs
  unset session
  unset namescript
  unset select_file_hosts
  unset logfile
  unset sshconcmd
  unset scpconcmd
  unset rsyncconcmd
  unset remhostcmd
  unset remhost
  unset remdir
  unset sshversion
  unset rsynccheck
  unset start_system
  unset start_system_new
  unset scpcmd
  unset scprun
  unset list_successful_exec_script
  unset list_skip_host
  unset list_failed_scripts
  unset list_failed_conn
  unset errconnmsg
  unset temp_dir_send_script
  unset list_param_send_script
  unset reboot_system_script_finish
  unset check_version_exec_script
  unset local_version_exec_script
  unset remote_version_exec_script
  unset namesendscript
  unset num_devices_access
  unset cmdready
  unset list_devices_err_exec_scripts
  unset list_successful_exec_full_scripts
  unset successful_run
  unset err_exec_script
  unset type_find_hosts
  unset exec_descriptor
  unset filename_PIPE
  unset num_descriptior
}

#Запуск отправки, в зависимости от количества потоков, для обеспечения логирования
function runsend {
  unset exec_descriptor
  unset filename_PIPE
  unset num_descriptior

  #Если подключение по паролю
  if [[ "$sshtypecon" = "pas" ]]; then
    #Записываем в переменную номера всех активных дескрипторов процесса
    exec_descriptor="$(ls -1 /proc/$$/fd/)"

    #Ищем первый свободный номер, начиная с 10, для нового дескриптора
    for ((num_descriptior = 10; num_descriptior < 255; num_descriptior++)); do

      #Если найден свободный номер для дескриптора, то выходим из цикла
      if [[ "$(grep "^$num_descriptior$" <<<"$exec_descriptor" | wc -l)" -eq "0" ]]; then
        break
      else
        #Если не найден и это последний круг цикла, удаляем переменную и выходим из цикла
        if [[ "$num_descriptior" -eq "254" ]]; then
          unset num_descriptior
          break
        fi
      fi
    done
  fi

  #Продолжаем, если номер дескриптора является числом или подключение по ключу
  if [[ "$num_descriptior" =~ $check_num ]] || [[ "$sshtypecon" = "key" ]]; then

    if [[ "$multisend" -eq "1" ]]; then
      #Имя лог файла для однопоточной отправки
      logfile="$(date +"%Y.%m.%d-%H%M%S")_$(echo "${list_param_send_script[0]}" | cut -d ';' -f 1)_${#list_param_send_script[@]}"

      echo "Начало выполнения: ($(date +"%Y.%m.%d %H:%M:%S"))" >>"$dir_logs/$logfile"

      sshsendscript 2>&1 | tee -a "$dir_logs/$logfile"
    else
      #Каталог лог файлов при многопоточной отправке
      sendlogs="$dir_logs/${value_date}_$(echo "${list_param_send_script[0]}" | cut -d ';' -f 1)_${#list_param_send_script[@]}"

      mkdir -p "$sendlogs"

      echo "Начало выполнения: ($(date +"%Y.%m.%d %H:%M:%S"))" >>"$sendlogs/$namescript"

      sshsendscript 2>&1 | tee -a "$sendlogs/$namescript"
    fi

    #Удаляем дескриптор, если num_descriptior является числом
    if [[ "$num_descriptior" =~ $check_num ]]; then
      exec {num_descriptior}>&-
      unset num_descriptior
      unset exec_descriptor
    fi
  fi
}

#Функция отправки файлов и запуск выполнения
function sshsendscript {
  unset sshconcmd
  unset scpconcmd
  unset rsyncconcmd
  unset sshcmd
  unset scpcmd
  unset scprun
  let cmdready=0

  #Подсчет количества устройств, к которым есть доступ
  let num_devices_access=0

  #Инициализация пустого массива для списка устройств, на которых была ошибка
  list_devices_err_exec_scripts=()

  #Инициализация пустого массива для списка устройств, на которых был успешно выполнен отправляемый скрипт
  list_successful_exec_script=()

  #Инициализация пустого массива для списка устройств, на которых были успешно выполнены все отправляемые скрипты (если отправлено более одного скрипта)
  list_successful_exec_full_scripts=()

  #Инициализация пустого массива для списка пропущенных устройств в соответствии с условиями: если устройство из списка исключения (если на этапе поиска устройств nmap не смог определить имя хоста, но оно есть в списке исключения, то после дополнительной проверки во время подключения к устройству, оно будет пропущено и добавлено в данный массив); если не установлен rsync на удаленном устройстве (если выбрана отправка файлов через rsync); если указанный в настройках каталог на удаленном устройстве не существует или к нему нет доступа
  list_skip_host=()

  #Инициализация пустого массива для списка устройств, к которым не удалось подключиться начиная со второго скрипта или произошла ошибка передачи файлов/запуска/выполнения скрипта
  list_failed_scripts=()

  #Инициализация пустого массива для списка устройств, к которым не удалось подключиться на первом скрипте
  list_failed_conn=()

  #Помещаем пароль в созданный дескриптор. Выполняется перед ssh подключением, если подключение по паролю
  function pas_to_descriptor {
    if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
      debug=1
      set +x
    fi

    #Выполнить, если подключение по паролю
    if [[ "$sshtypecon" = "pas" ]]; then
      unset filename_PIPE

      #Записываем в переменную путь к файлу
      filename_PIPE="$temp_dir_send_script/$(basename "$(mktemp -u)")"

      #Создаем канал c правами 600
      mkfifo -m 600 "$filename_PIPE"

      #Создаем дескриптор
      exec {num_descriptior}<>"$filename_PIPE"

      #Удаляем файл
      rm -f "$filename_PIPE"

      unset filename_PIPE

      base64 -d <<<"$cspas" >&$num_descriptior
    fi

    [[ $debug == 1 ]] && set -x && unset debug
  }

  function create_list_failed {
    #Добавление текущего устройства в массив списка устройств к которым не удалось подключиться (начиная со второго скрипта) или произошла ошибка передачи/запуска/выполнения скрипта
    list_failed_scripts[${#list_failed_scripts[@]}]="$(echo "$errconnmsg ${list_ipall[$i]} (Скрипт № $(expr $num_send_script + 1): $namesendscript)")"

    if [[ "$err_exec_script" -eq "0" ]] && [[ "${#list_param_send_script[@]}" -gt "1" ]]; then
      create_list_devices_err_exec_scripts
      let err_exec_script=1
    fi
  }

  function create_list_failed_conn {
    #Добавление текущего устройства в массив списка устройств к которым не удалось подключиться на первом скрипте
    list_failed_conn[${#list_failed_conn[@]}]="$(echo "$errconnmsg ${list_ipall[$i]}")"
  }

  function create_list_successful_exec_script {
    #Добавление текущего устройства (имя хоста и ip адрес) в массив списка устройств на которых было успешно завершено выполнение скрипта
    list_successful_exec_script[${#list_successful_exec_script[@]}]="${errconnmsg}$remhost - ${list_ipall[$i]} (Скрипт № $(expr $num_send_script + 1): $namesendscript)"
  }

  function create_list_successful_exec_full_scripts {
    #Добавление текущего устройства (имя хоста и ip адрес) в массив списка устройств на которых было успешно завершено выполнение всех скриптов (если отправляется более одного скрипта)
    list_successful_exec_full_scripts[${#list_successful_exec_full_scripts[@]}]="$remhost - ${list_ipall[$i]}"
  }

  function create_list_devices_err_exec_scripts {
    #Добавление текущего устройства (имя хоста и ip адрес) в массив списка устройств на которых на которых была ошибка (если отправляется более одного скрипта)
    list_devices_err_exec_scripts[${#list_devices_err_exec_scripts[@]}]="$remhost - ${list_ipall[$i]}"
  }

  function create_list_skip_host {
    echo "$remhost - ${list_ipall[$i]} ($errconnmsg)"

    #Добавление текущего устройства (имя хоста, ip адрес, причина пропуска) в массив списка устройств, которые были пропущены
    list_skip_host[${#list_skip_host[@]}]="$remhost - ${list_ipall[$i]} ($errconnmsg)"
  }

  #Присвоение значений переменным, в зависимости от типа подключения (пароль или ключ)
  if [[ "$sshtypecon" = "pas" ]]; then

    #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
    if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
      debug=1
      set +x
    fi

    #Если тип подключения ssh по паролю, то пароль расшифровывается и записывается в переменную в base64 виде, чтобы избежать нагрузки при многопоточном режиме отправки.
    cspas="$(cat "$gpgfilepass" | gpg2 --decrypt -q --pinentry-mode loopback --batch --yes --passphrase "$(echo "$gpgpass" | base64 -d)" | base64 -w0)"

    [[ $debug == 1 ]] && set -x && unset debug

    #Команда подключения ssh
    sshconcmd='sshpass -d $num_descriptior ssh -F /dev/null -o ConnectTimeout=$sshtimeout -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -t -t $logname@$(printf %s ${list_ipall[$i]}) -p $numportssh "${sshcmd[$sshcmdnum]}"'

    #Команда подключения scp
    scpconcmd='sshpass -d $num_descriptior scp $scprun -C -F /dev/null -o ConnectTimeout=$sshtimeout -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -P $numportssh -r "$temp_dir_send_script/$tempnamescript" $logname@$(printf %s ${list_ipall[$i]}):"$scpcmd"'

    #Команда подключения rsync
    rsyncconcmd='sshpass -d $num_descriptior rsync -avkczhe "ssh -F /dev/null -o ConnectTimeout=$sshtimeout -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -p $numportssh" --progress "$temp_dir_send_script/$tempnamescript" $logname@$(printf %s ${list_ipall[$i]}):"$remotedirrunscript"'

    let cmdready=1
  fi

  #Если подключение по ключу
  if [[ "$sshtypecon" = "key" ]]; then
    #Команда подключения ssh
    sshconcmd='ssh -F /dev/null -o ConnectTimeout=$sshtimeout -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=yes -o PreferredAuthentications=publickey -o IdentitiesOnly=yes -i "$sshkeyfile" -o AddKeysToAgent=yes -t -t $logname@$(printf %s ${list_ipall[$i]}) -p $numportssh "${sshcmd[$sshcmdnum]}"'

    #Команда подключения scp
    scpconcmd='scp $scprun -C -F /dev/null -o ConnectTimeout=$sshtimeout -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=yes -o PreferredAuthentications=publickey -o IdentitiesOnly=yes -i "$sshkeyfile" -o AddKeysToAgent=yes -P $numportssh -r "$temp_dir_send_script/$tempnamescript" $logname@$(printf %s ${list_ipall[$i]}):"$scpcmd"'

    #Команда подключения rsync
    rsyncconcmd='rsync -avkczhe "ssh -F /dev/null -o ConnectTimeout=$sshtimeout -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=yes -o PreferredAuthentications=publickey -o IdentitiesOnly=yes -i "$sshkeyfile" -o AddKeysToAgent=yes -p $numportssh" --progress "$temp_dir_send_script/$tempnamescript" $logname@$(printf %s ${list_ipall[$i]}):"$remotedirrunscript"'

    let cmdready=1
  fi

  #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
  if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
    debug=1
    set +x
  fi

  #Команда выполняемая при первом подключении (проверка необходимых данных и попытка создать каталог, если не существует). Записываем в нулевой элемент массива
  sshcmd[0]="export HISTFILE=/dev/null; sudo -k 2>/dev/null; remotedirrunscript=\"$remotedirrunscript\"; function acces_folder { [[ -d \"\$remotedirrunscript\" ]] && [[ -w \"\$remotedirrunscript\" ]] && [[ -r \"\$remotedirrunscript\" ]] && [[ -x \"\$remotedirrunscript\" ]]; }; echo \"remhost=\\\"\$(hostname)\\\";\"; echo \"remdir=\\\"\$(acces_folder && echo 1 || ((mkdir -p \"\$remotedirrunscript\" 2>/dev/null && chmod -R 2770 \"\$remotedirrunscript\" 2>/dev/null && chown -R :\"$remotedirgroup\" \"\$remotedirrunscript\" 2>/dev/null); acces_folder && echo 1 || echo 0))\\\";\"; echo \"sshversion=\\\"\$([[ -n \"\$(ssh -V 2>&1 | sed 's/OpenSSH_\([0-9]*\+\.\+[0-9]*\).*/\1/')\" ]] && echo \"\$(ssh -V 2>&1 | sed 's/OpenSSH_\([0-9]*\+\.\+[0-9]*\).*/\1/')\" || echo 0)\\\";\"; echo \"rsynccheck=\\\"\$([[ -n \"\$(which rsync 2>/dev/null)\" ]] && echo 1 || echo 0)\\\";\"; echo \"start_system=\\\"\$(uptime -s | tr -d '[:punct:]|[:space:]')\\\";\""

  #Команда получения значения старта системы. Записываем во второй элемент массива
  sshcmd[2]="export HISTFILE=/dev/null; sudo -k 2>/dev/null; echo \"start_system_new=\\\"\$(uptime -s | tr -d '[:punct:]|[:space:]')\\\";\""

  [[ $debug == 1 ]] && set -x && unset debug

  if [[ "$cmdready" -eq "1" ]]; then
    #Запись используемой версии ssh на локальном ПК
    sshversionlocal="$(ssh -V 2>&1 | sed 's/OpenSSH_\([0-9]*\+\.\+[0-9]*\).*/\1/')"

    #Продолжаем, если локальная версия ssh определена
    if [[ -n "$sshversionlocal" ]]; then

      #Если список ip не пуст, то запускаем выполнение
      for ((i = 0; i < ${#list_ipall[@]}; i++)); do
        echo -e "\n---------------\n"

        echo "Дата: ($(date +"%Y.%m.%d %H:%M:%S"))"

        let successful_run=0

        let err_exec_script=0

        #Перебираем массив отправляемых скриптов
        for ((num_send_script = 0; num_send_script < ${#list_param_send_script[@]}; num_send_script++)); do

          unset namesendscript
          unset tempnamescript
          unset type_run_remote_script
          unset reboot_system_script_finish
          unset epas
          unset rc
          unset local_version_exec_script
          unset remote_version_exec_script

          #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
          if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
            debug=1
            set +x
          fi

          #Получаем значение необходимых переменных
          namesendscript="$(echo "${list_param_send_script[$num_send_script]}" | cut -d ';' -f 1)"
          tempnamescript="$(echo "${list_param_send_script[$num_send_script]}" | cut -d ';' -f 2)"
          type_run_remote_script="$(echo "${list_param_send_script[$num_send_script]}" | cut -d ';' -f 3)"
          reboot_system_script_finish="$(echo "${list_param_send_script[$num_send_script]}" | cut -d ';' -f 4)"
          epas="$(echo "${list_param_send_script[$num_send_script]}" | cut -d ';' -f 5)"
          rc="$(echo "${list_param_send_script[$num_send_script]}" | cut -d ';' -f 6)"
          local_version_exec_script="$(echo "${list_param_send_script[$num_send_script]}" | cut -d ';' -f 7)"

          [[ $debug == 1 ]] && set -x && unset debug

          #Получение значений с устройства
          check_value_devaice

          #Если переменная remhost с именем ПК пуста, то переход к следующему ip адресу.
          if [[ -z "$remhost" ]]; then
            echo -e "\n$RED Не удалось подключиться к ${list_ipall[$i]} $NoColor"

            #Добавление значения к одному из массивов, в зависимости от номера отправляемого скрипта, и выход из цикла
            if [[ "$num_send_script" -eq "0" ]]; then
              errconnmsg="Нет доступа к устройству"
              create_list_failed_conn
            elif [[ "$num_send_script" -gt "0" ]]; then
              errconnmsg="Не удалось подключиться к"
              create_list_failed
            fi
            break
          else
            if [[ "$num_send_script" -eq "0" ]]; then
              #Добавляем 1 к счетчику доступных устройств
              let num_devices_access+=1
            fi

            echo -e "\n$GREEN Устройство доступно: $remhost $NoColor"

            #Если каталог на удаленном устройстве существует, то продолжаем
            if [[ "$remdir" -eq "1" ]]; then

              #Если отправка выполняется на все устройства (Мультиотправка) и это первый отправляемый на устройство скрипт, то выполняется проверка по спискам исключений (повторная проверка нужна для того, чтобы гарантировать исключение по имени хоста, т.к. при поиске nmap может не отобразить имя хоста, если, например, это другая подсеть и ваш dns сервер не может выдать имя хоста из этой подсети). Если имя хоста будет соответствовать условию любого списка исключения, то имени хоста присваивается пустое значение
              if [[ $typesend = "sshmultisend" ]] && [[ "$num_send_script" -eq "0" ]]; then

                #Если записей для пропуска по частичному совпадению больше 0, то выполняем фильтрацию. За 1 цикл одновременно ищется 15 элементов из списка исключения.
                if [[ "${#listIgnoreInaccurate[@]}" -gt "0" ]]; then

                  if [[ "${#listIgnoreInaccurate[@]}" -lt "15" ]]; then
                    let intervalvalue=${#listIgnoreInaccurate[@]}
                  else
                    let intervalvalue=15
                  fi

                  #Вычисление количества необходимых циклов
                  let colcycle="(${#listIgnoreInaccurate[@]}/$intervalvalue)"

                  #Вычисление остатка от деления
                  let modulecolcycle="${#listIgnoreInaccurate[@]}%$intervalvalue"

                  for ((num_cycle = 0; num_cycle < $colcycle; num_cycle++)); do
                    let startvalue=$intervalvalue*$num_cycle

                    #Если есть совпадение в списке исключения, то обнуляем переменную remhost
                    if [[ "$(grep -Ei "$(tr '\n ' '|' <<<"${listIgnoreInaccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$remhost" | wc -l)" -gt "0" ]]; then
                      errconnmsg="Устройство пропущено в соответствии со списком исключения"
                      create_list_skip_host
                      remhost=""
                      break 2
                    fi
                  done

                  #Если остаток от деления не равен нулю, то оставшиеся значения проверяем в последнем условии
                  if [[ "$modulecolcycle" -ne "0" ]]; then
                    let startvalue=$intervalvalue*$colcycle

                    #Если есть совпадение в списке исключения, то обнуляем переменную remhost
                    if [[ "$(grep -Ei "$(tr '\n ' '|' <<<"${listIgnoreInaccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$remhost" | wc -l)" -gt "0" ]]; then
                      errconnmsg="Устройство пропущено в соответствии со списком исключения"
                      create_list_skip_host
                      remhost=""
                      break
                    fi
                  fi
                fi

                #Выполняем, если remhost не пуста
                if [[ -n "$remhost" ]]; then
                  #Если записей для пропуска по точному совпадению больше 0, то выполняем фильтрацию. За 1 цикл одновременно ищется 15 элементов из списка исключения.
                  if [[ "${#listIgnoreAccurate[@]}" -gt "0" ]]; then

                    if [[ "${#listIgnoreAccurate[@]}" -lt "15" ]]; then
                      let intervalvalue=${#listIgnoreAccurate[@]}
                    else
                      let intervalvalue=15
                    fi

                    #Вычисление количества необходимых циклов
                    let colcycle="(${#listIgnoreAccurate[@]}/$intervalvalue)"

                    #Вычисление остатка от деления
                    let modulecolcycle="${#listIgnoreAccurate[@]}%$intervalvalue"

                    for ((num_cycle = 0; num_cycle < $colcycle; num_cycle++)); do
                      let startvalue=$intervalvalue*$num_cycle

                      #Если есть совпадение в списке исключения, то обнуляем переменную remhost
                      if [[ "$(grep -Eiw "$(tr '\n ' '|' <<<"${listIgnoreAccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$remhost" | wc -l)" -gt "0" ]]; then
                        errconnmsg="Устройство пропущено в соответствии со списком исключения"
                        create_list_skip_host
                        remhost=""
                        break 2
                      fi
                    done

                    #Если остаток от деления не равен нулю, то оставшиеся значения проверяем в последнем условии
                    if [[ "$modulecolcycle" -ne "0" ]]; then
                      let startvalue=$intervalvalue*$colcycle

                      #Если есть совпадение в списке исключения, то обнуляем переменную remhost
                      if [[ "$(grep -Eiw "$(tr '\n ' '|' <<<"${listIgnoreAccurate[@]:$startvalue:$intervalvalue}" | sed -e 's/.$//g')" <<<"$remhost" | wc -l)" -gt "0" ]]; then
                        errconnmsg="Устройство пропущено в соответствии со списком исключения"
                        create_list_skip_host
                        remhost=""
                        break
                      fi
                    fi
                  fi
                fi
              fi

              #Если переменная с именем хоста не пуста после проверки, то выполняется проверка значения типа отправки. В случае с отправкой по scp проверяется версия ssh на локальном и удаленном ПК (от соответствия определенным условиям зависит итоговая команда отправки). В случае с rsync проверяется значение в переменной (установлен ли rsync на удаленном ПК). Для отправки файлов рекомендуется rsync
              if [[ -n "$remhost" ]]; then

                #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
                if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
                  debug=1
                  set +x
                fi

                if [[ "$local_version_exec_script" -gt "0" ]]; then
                  #Команда выполняемая в случае проверки версии выполненного скрипта (проверка существования файла, если не существует, то попытка создать. Поиск версии выполненного скрипта в файле, если файл до этого существовал). Записываем в третий элемент массива
                  sshcmd[3]="export HISTFILE=/dev/null; sudo -k 2>/dev/null; shopt -s dotglob; file_version=\"$path_exec_script_version\"; dir_file_ver=\"\$(dirname \"\$file_version\")\"; function find_ver_rs { script_ver=\"\$(sed -nr \"{ :l /$namesendscript[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}\" \"\$file_version\")\"; [[ -n \"\$script_ver\" ]] && echo \"\$script_ver\" || echo 0; }; function touch_f_v { touch \"\$file_version\" 2>/dev/null && chmod 770 \"\$file_version\" 2>/dev/null; }; function check_f_e { [[ -f \"\$file_version\" ]] && [[ -w \"\$file_version\" ]] && [[ -r \"\$file_version\" ]]; }; function check_d_e { [[ -d \"\$dir_file_ver\" ]] && [[ -w \"\$dir_file_ver\" ]] && [[ -r \"\$dir_file_ver\" ]] && [[ -x \"\$dir_file_ver\" ]]; }; echo \"remote_version_exec_script=\\\"\$(check_f_e && find_ver_rs || ((check_d_e && touch_f_v || (mkdir -p \"\$dir_file_ver\" 2>/dev/null && touch_f_v && chmod -R 2770 \"\$dir_file_ver\" 2>/dev/null && chown -R :\"$remotedirgroup\" \"\$dir_file_ver\" 2>/dev/null)); chown :\"$remotedirgroup\" \"\$file_version\" 2>/dev/null; check_f_e && echo 0))\\\";\""

                  let sshcmdnum=3

                  pas_to_descriptor

                  #Выполнение команды на удаленном устройстве. Запись результата в переменную
                  remhostcmd="$(eval "$sshconcmd")"

                  eval "$(echo $remhostcmd | tr -d '\r|\n')"
                  unset remhostcmd

                  echo -e "\nВключено сравнение отправляемой и выполненной ранее версии скрипта (если значение 0, то файл существует и к нему есть доступ, но строки с версией скрипта в нем еще нет.)\n"
                  echo "Отправляемая версия: $local_version_exec_script"

                  if [[ "$remote_version_exec_script" =~ $check_num ]]; then
                    echo "Выполненная версия: $remote_version_exec_script"
                    echo ""

                    if [[ "$remote_version_exec_script" -gt "0" ]]; then
                      if [[ "$remote_version_exec_script" -eq "$local_version_exec_script" ]]; then
                        errconnmsg="Версия № $local_version_exec_script отправляемого скрипта совпадает с выполненной. "

                        echo ""
                        echo "$errconnmsg $remhost - ${list_ipall[$i]} (Скрипт № $(expr $num_send_script + 1): $namesendscript)."

                        create_list_successful_exec_script

                        let successful_run+=1

                        #Если отправляется более одного скрипта и количество успешно выполненных скриптов равно количеству отправляемых скриптов, то добавляется значение к массиву create_list_successful_exec_full_scripts
                        if [[ "${#list_param_send_script[@]}" -gt "1" ]] && [[ "$successful_run" -eq "${#list_param_send_script[@]}" ]]; then
                          create_list_successful_exec_full_scripts
                        fi
                        continue
                      fi
                    fi
                  else
                    echo "Выполненная версия: нет доступа к файлу"
                    echo ""

                    errconnmsg="Для скрипта включено сравнение версий, но не удалось создать/получить доступ к файлу версий. $remhost -"
                    create_list_failed
                    break
                  fi
                fi

                #В зависимости от типа выполнения, записываем в первый элемент массива команду выполняемую при втором подключении (команда запуска отправляемого скрипта)
                if [[ "$type_run_remote_script" = "autopassudo" || "$type_run_remote_script" = "cronscript" ]]; then
                  sshcmd[1]="sudo -k; export HISTFILE=/dev/null; eval \`echo \"$epas\" | base64 -d\`; eval \`echo \"$rc\" | base64 -d\`; echo \"$(cat "$dir_runscript/remote-runprecommand.sh" | sed -r '2,${/(^[[:space:]]*#|^$)/d}' | base64 -w0)\" | base64 -d | bash && err_status=\"0\" || err_status=\"1\"; [[ \"\$err_status\" -eq \"1\" ]] && exit 1 || exit 0"
                elif [[ "$type_run_remote_script" = "nopassudo" ]]; then
                  sshcmd[1]="sudo -k; export HISTFILE=/dev/null; dir_run_script=\"$remotedirrunscript/$tempnamescript\"; chown -R :\"$remotedirgroup\" \"\$dir_run_script\"; chmod 2700 \"\$dir_run_script\"; chmod 700 \"\$dir_run_script/$tempnamescript\"; sudo \"\$dir_run_script/$tempnamescript\" && err_status=\"0\" || err_status=\"1\"; [[ \"$local_version_exec_script\" -gt \"0\" ]] && [[ \"\$err_status\" -eq \"0\" ]] && chmod 700 \"\$dir_run_script/add_ver_to_file.sh\" && \"\$dir_run_script/add_ver_to_file.sh\"; sudo rm -f -R -v \"\$dir_run_script/\"; sudo -k; [[ \"\$err_status\" -eq \"1\" ]] && exit 1 || exit 0"
                elif [[ "$type_run_remote_script" = "nosudo" ]]; then
                  sshcmd[1]="sudo -k; export HISTFILE=/dev/null; dir_run_script=\"$remotedirrunscript/$tempnamescript\"; chown -R :\"$remotedirgroup\" \"\$dir_run_script\"; chmod 2700 \"\$dir_run_script\"; chmod 700 \"\$dir_run_script/$tempnamescript\"; \"\$dir_run_script/$tempnamescript\" && err_status=\"0\" || err_status=\"1\"; [[ \"$local_version_exec_script\" -gt \"0\" ]] && [[ \"\$err_status\" -eq \"0\" ]] && chmod 700 \"\$dir_run_script/add_ver_to_file.sh\" && \"\$dir_run_script/add_ver_to_file.sh\"; rm -f -R -v \"\$dir_run_script/\"; [[ \"\$err_status\" -eq \"1\" ]] && exit 1 || exit 0"
                fi

                [[ $debug == 1 ]] && set -x && unset debug

                #Если отправка через scp
                if [[ "$typesendfiles" = "scp" ]]; then

                  if [[ -n "$sshversion" ]]; then
                    unset scpcmd
                    unset scprun

                    scpcmd="'$remotedirrunscript'"

                    #Если версия ssh больше или равна 9.0, то добавляем параметр -O
                    if [[ "$(echo "$sshversionlocal >= 9.0" | bc -l)" -eq "1" ]]; then
                      scprun="-O"
                    elif [[ "$(echo "$sshversionlocal < 9.0" | bc -l)" -eq "1" ]]; then
                      scprun=""
                    fi

                    echo -e "Отправка скрипта ($(expr $num_send_script + 1)-$namesendscript) на $remhost \n"

                    #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
                    if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
                      debug=1
                      set +x
                    fi

                    pas_to_descriptor

                    eval "($scpconcmd) && err_status_send_files=\"0\" || err_status_send_files=\"1\""
                    [[ $debug == 1 ]] && set -x && unset debug

                    #Если передано без ошибок, то запускаем выполнение
                    if [[ "$err_status_send_files" -eq "0" ]]; then
                      sshrunscript

                      #Если статус ошибки равен 1 и принудительное выполнение скрипта не включено, то завершаем выполнение скриптов на текущем устройстве
                      if [[ "$err_status_exec_script" -eq "1" || "$err_status_reboot_system" -eq "1" ]] && [[ "$force_exec_script" -ne "1" ]]; then
                        break
                      fi
                    elif [[ "$err_status_send_files" -eq "1" ]]; then
                      errconnmsg="Ошибка при передаче скрипта на $remhost -"
                      create_list_failed
                      break
                    fi

                  else
                    errconnmsg="Версия SSH на удаленном устройстве не определена"
                    create_list_skip_host
                    break
                  fi

                  #Если отправка через rsync
                elif [[ "$typesendfiles" = "rsync" ]]; then

                  #Если rsync на удаленном устройстве установлен, то продолжаем
                  if [[ "$rsynccheck" -eq "1" ]]; then
                    echo -e "Отправка скрипта ($(expr $num_send_script + 1)-$namesendscript) на $remhost \n"

                    #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
                    if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
                      debug=1
                      set +x
                    fi

                    pas_to_descriptor

                    eval "($rsyncconcmd) && err_status_send_files=\"0\" || err_status_send_files=\"1\""
                    [[ $debug == 1 ]] && set -x && unset debug

                    #Если передано без ошибок, то запускаем выполнение
                    if [[ "$err_status_send_files" -eq "0" ]]; then
                      sshrunscript

                      #Если статус ошибки равен 1 и принудительное выполнение скрипта не включено, то завершаем выполнение скриптов на текущем устройстве
                      if [[ "$err_status_exec_script" -eq "1" || "$err_status_reboot_system" -eq "1" ]] && [[ "$force_exec_script" -ne "1" ]]; then
                        break
                      fi
                    elif [[ "$err_status_send_files" -eq "1" ]]; then
                      errconnmsg="Ошибка при передаче скрипта на $remhost -"
                      create_list_failed
                      break
                    fi
                  else
                    errconnmsg="На устройстве не установлен rsync"
                    create_list_skip_host
                    break
                  fi
                fi
              fi

            else
              errconnmsg="На устройстве не удалось создать каталог или к нему нет доступа"
              create_list_skip_host
              break
            fi
          fi
        done
      done

      echo -e "\n-----Информация о подключении/выполнении скриптов-----\n"

      list_successful_exec_script=($(printf '%s\n' "${list_successful_exec_script[@]}" | sort))
      echo -e "${GREEN}Успешное выполнение (Записей в списке: ${#list_successful_exec_script[@]}$([[ "${#list_param_send_script[@]}" -eq "1" ]] && echo "; Доступно устройств: $num_devices_access")): $NoColor"
      printf '%s\n' "${list_successful_exec_script[@]}"

      if [[ "${#list_param_send_script[@]}" -gt "1" ]]; then
        echo ""

        list_successful_exec_full_scripts=($(printf '%s\n' "${list_successful_exec_full_scripts[@]}" | sort))
        echo -e "${GREEN}Успешное выполнение всех отправленных скриптов (Записей в списке: ${#list_successful_exec_full_scripts[@]}; Доступно устройств: $num_devices_access): $NoColor"
        printf '%s\n' "${list_successful_exec_full_scripts[@]}"
      fi

      echo ""

      list_skip_host=($(printf '%s\n' "${list_skip_host[@]}" | sort))
      echo -e "${YELLOW}Пропущенные устройства (Записей в списке: ${#list_skip_host[@]}; Доступно устройств: $num_devices_access): $NoColor"
      printf '%s\n' "${list_skip_host[@]}"

      echo ""

      list_failed_scripts=($(printf '%s\n' "${list_failed_scripts[@]}" | sort))
      echo -e "${RED}Выполнение с ошибкой (Записей в списке: ${#list_failed_scripts[@]}$([[ "${#list_param_send_script[@]}" -eq "1" ]] && echo "; Доступно устройств: $num_devices_access")): $NoColor"
      printf '%s\n' "${list_failed_scripts[@]}"

      if [[ "${#list_param_send_script[@]}" -gt "1" ]]; then
        echo ""

        list_devices_err_exec_scripts=($(printf '%s\n' "${list_devices_err_exec_scripts[@]}" | sort))
        echo -e "${RED}Устройства с ошибками (Записей в списке: ${#list_devices_err_exec_scripts[@]}; Доступно устройств: $num_devices_access): $NoColor"
        printf '%s\n' "${list_devices_err_exec_scripts[@]}"
      fi

      echo ""

      echo -e "${RED}Устройства к которым нет доступа (Записей в списке: ${#list_failed_conn[@]}): $NoColor"
      printf '%s\n' "${list_failed_conn[@]}"

      echo -e "\n-----Конец информации о подключении к устройствам-----\n"

      if [[ "$multisend" -gt "1" ]]; then

        if [[ "${#list_successful_exec_script[@]}" -gt "0" ]]; then
          printf '%s\n' "${list_successful_exec_script[@]}" | grep -v '^$' >>"$sendlogs/tmp-successful_exec_script"
        fi

        if [[ "${#list_successful_exec_full_scripts[@]}" -gt "0" ]]; then
          printf '%s\n' "${list_successful_exec_full_scripts[@]}" | grep -v '^$' >>"$sendlogs/tmp-successful_exec_full_scripts"
        fi

        if [[ "${#list_skip_host[@]}" -gt "0" ]]; then
          printf '%s\n' "${list_skip_host[@]}" | grep -v '^$' >>"$sendlogs/tmp-skip_host"
        fi

        if [[ "${#list_failed_scripts[@]}" -gt "0" ]]; then
          printf '%s\n' "${list_failed_scripts[@]}" | grep -v '^$' >>"$sendlogs/tmp-failed_scripts"
        fi

        if [[ "${#list_devices_err_exec_scripts[@]}" -gt "0" ]]; then
          printf '%s\n' "${list_devices_err_exec_scripts[@]}" | grep -v '^$' >>"$sendlogs/tmp-devices_err_exec_scripts"
        fi

        if [[ "${#list_failed_conn[@]}" -gt "0" ]]; then
          printf '%s\n' "${list_failed_conn[@]}" | grep -v '^$' >>"$sendlogs/tmp-failed_conn"
        fi

        if [[ "$num_devices_access" -gt "0" ]]; then
          echo "$num_devices_access" >>"$sendlogs/tmp-sum_devices"
        fi
      fi
    else
      echo "Версия SSH на локальном устройстве не определена"
    fi
  fi
}

#Подключение к ПК. В случае успешного подключения: определяется имя ПК; проверяется существует ли указанный в файле конфигурации каталог, а также права чтения, записи и выполнения на него (если каталог не существует или нет какого-либо права, то попытка создать каталог и выставить на него права. Если все условия выполнены, то на выходе выдаст значение 1); определяется версия ssh; определяется наличие rsync; определяется значение старта системы
function check_value_devaice {
  echo -e "\nПроверка доступности устройства ${list_ipall[$i]}\n"

  unset remhostcmd
  unset remhost
  unset remdir
  unset sshversion
  unset rsynccheck
  unset start_system

  #Номер элемента массива с командой ssh
  let sshcmdnum=0

  #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
  if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
    debug=1
    set +x
  fi

  pas_to_descriptor

  #Выполнение команды на удаленном устройстве. Запись результата в переменную
  remhostcmd="$(eval "$sshconcmd")"

  eval "$(echo $remhostcmd | tr -d '\r|\n')"
  unset remhostcmd

  echo ""
  echo "Имя хоста: $remhost (${list_ipall[$i]})"
  echo "Статус каталога ($remotedirrunscript): $remdir"
  echo "Версия SSH: $sshversion"
  echo "Статус rsync: $rsynccheck"
  echo "Старт системы: $start_system"

  [[ $debug == 1 ]] && set -x && unset debug
}

#Функция запуска выполнения скрипта на удаленном ПК
function sshrunscript {
  echo -e "\nВыполнение скрипта на $remhost \n"

  let sshcmdnum=1
  unset errconnmsg
  unset err_status_exec_script
  err_status_reboot_system="0"

  #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
  if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
    debug=1
    set +x
  fi

  pas_to_descriptor

  eval "($sshconcmd) && err_status_exec_script=\"0\" || err_status_exec_script=\"1\""

  [[ $debug == 1 ]] && set -x && unset debug

  #Если выполнение успешно, то добавляем в массив create_list_successful_exec_script
  if [[ "$err_status_exec_script" -eq "0" ]]; then
    create_list_successful_exec_script

    let successful_run+=1

    #Если отправляется более одного скрипта и количество успешно выполненных скриптов равно количеству отправляемых скриптов, то добавляется значение к массиву create_list_successful_exec_full_scripts
    if [[ "${#list_param_send_script[@]}" -gt "1" ]] && [[ "$successful_run" -eq "${#list_param_send_script[@]}" ]]; then
      create_list_successful_exec_full_scripts
    fi

    #Если это не последний отправляемый скрипт и есть признак ожидания перезагрузки, то выполняется ожидание перезагрузки устройства
    if [[ "$reboot_system_script_finish" -eq "1" ]] && [[ "$num_send_script" -lt "$(expr ${#list_param_send_script[@]} - 1)" ]]; then
      let wait_devaice=1

      #Фиксированное ожидание 90 секунд
      echo "Ожидание (90 секунд) перезагрузки устройства $remhost (${list_ipall[$i]})."
      sleep 90

      while true; do

        #Ожидание в зависимости от определенных переменных (количества попыток и времени каждой попытки)
        echo "Ожидание подключения устройства $remhost (${list_ipall[$i]}) к сети. Попытка $wait_devaice из $reboot_max_try_wait_devaice"
        while ! ping -c 2 -i $reboot_time_wait_devaice ${list_ipall[$i]} &>/dev/null; do

          if [[ "$wait_devaice" -lt "$reboot_max_try_wait_devaice" ]]; then
            let wait_devaice+=1
            echo "Ожидание подключения устройства $remhost (${list_ipall[$i]}) к сети. Попытка $wait_devaice из $reboot_max_try_wait_devaice"
          else
            errconnmsg="Истёк лимит ожидания перезагрузки после скрипта № $(expr $num_send_script + 1) на $remhost -"
            echo "$errconnmsg ${list_ipall[$i]} (Скрипт № $(expr $num_send_script + 1): $namesendscript)"
            create_list_failed
            err_status_reboot_system="1"
            break 2
          fi
        done

        #Если устройство обнаружено в сети, то получаем значение запуска системы
        let sshcmdnum=2
        unset remhostcmd
        unset start_system_new

        #Если обнаружен debug режим, то он выключается для изоляции от debug идущего далее кода. debug режим будет включен после выполнения, если был отключен условием. Для полного debug вывода, выполните ' export ssscdebugmode="1" ' и запустите debug скрипта
        if [[ $- =~ x ]] && [[ "$ssscdebugmode" -ne "1" ]]; then
          debug=1
          set +x
        fi

        pas_to_descriptor

        remhostcmd="$(eval "$sshconcmd 2>/dev/null")"

        [[ $debug == 1 ]] && set -x && unset debug
        eval "$(echo $remhostcmd | tr -d '\r|\n')"
        unset remhostcmd

        #Если значение запуска является числом, то проверяем, что оно не равно предыдущему значению. Если значение запуска не является числом, то продолжаем ожидание/проверку до истечения попыток/успешной проверки
        if [[ "$start_system_new" =~ $check_num ]]; then

          if [[ "$start_system_new" -ne "$start_system" ]]; then
            echo -e "\nСистема успешно перезагружена. Продолжается выполнение\n"
            err_status_reboot_system="0"
            break
          else
            errconnmsg="Устройство $remhost не перезагрузилось после выполнения скрипта № $(expr $num_send_script + 1) -"
            echo "$errconnmsg ${list_ipall[$i]} (Скрипт № $(expr $num_send_script + 1): $namesendscript)"
            create_list_failed
            err_status_reboot_system="1"
            break
          fi
        else
          if [[ "$wait_devaice" -lt "$reboot_max_try_wait_devaice" ]]; then
            let wait_devaice+=1
          else
            errconnmsg="Не удалось определить статус перезагрузки системы после скрипта № $(expr $num_send_script + 1) на $remhost -"
            echo "$errconnmsg ${list_ipall[$i]} (Скрипт № $(expr $num_send_script + 1): $namesendscript)"
            create_list_failed
            err_status_reboot_system="1"
            break
          fi
        fi
      done
    fi
  elif [[ "$err_status_exec_script" -eq "1" ]]; then
    errconnmsg="Ошибка запуска/выполнения скрипта № $(expr $num_send_script + 1) на $remhost -"
    create_list_failed
  fi

  sleep 0.150s
}

#Удаление временного каталога
function delsendfiles {
  echo -e "\nУдаление локальных временных файлов\n"
  rm -f -R -v "$temp_dir_send_script"
}
