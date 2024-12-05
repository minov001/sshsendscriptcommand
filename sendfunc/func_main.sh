#!/bin/bash

#Условия для проверки
check_num='^[0-9]+$'
check_login_or_group='^[A-Za-zА-Яа-я0-9@._-]+$'
check_hostname_or_ip='^[A-Za-zА-Яа-я0-9.-]+$'
check_path='^[A-Za-zА-Яа-я0-9(),./@_[:space:]-]+$'
check_namesettings='^[A-Za-zА-Яа-я0-9(),.@_[:space:]-]+$'

IFS=$'\n'

#Переменные с цветами
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
NoColor='\033[0m'

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
    if [[ "${#list_check_files_error[@]}" -eq "0" ]]; then
      list_check_files_error=("${chekfiles[@]}")
    else
      list_check_files_error=("${list_check_files_error[@]}" "${chekfiles[@]}")
    fi
  else
    if [[ "${#list_check_files_error[@]}" -eq "0" ]]; then
      list_check_files_error=("${chekfiles[0]}")
    else
      list_check_files_error=("${list_check_files_error[@]}" "${chekfiles[0]}")
    fi
  fi
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

        #Добавление значения в массив в зависимости от того пуст массив или нет
        if [[ "${#list_package_management_installed[@]}" -eq "0" ]]; then
          list_package_management_installed=("${list_package_management[$num_value_massive]}")
        else
          list_package_management_installed=("${list_package_management_installed[@]}" "${list_package_management[$num_value_massive]}")
        fi
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
      return 1
    fi
  else
    if [[ "$(grep -Eix "$select_package_management" <<<"$(echo "${list_package_management[@]/%/$'\n'}" | sed 's/^ //' | grep -v '^$')" | wc -l)" -gt "0" ]]; then

      if [[ -z "$(which "$select_package_management" 2>/dev/null)" ]]; then
        echo "$(echo -e "${RED}Указанная система управления пакетами не обнаружена:$NoColor") $select_package_management"
        unset_install_pkg_param
        return 1
      fi
    else
      echo -e "${RED}Указанная система управления пакетами не поддерживается$NoColor"
      unset_install_pkg_param
      return 1
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
    return 1
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
      return 1
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

              if [[ "${#list_pkg_inst[@]}" -eq "0" ]]; then
                list_pkg_inst=("${temp_list_pkgnames[$i]}")
              else
                list_pkg_inst=("${list_pkg_inst[@]}" "${temp_list_pkgnames[$i]}")
              fi
              break
            elif [[ "${#temp_list_pkgnames[@]}" -gt "1" ]]; then
              if [[ "${#list_pkg_insttemp[@]}" -eq "0" ]]; then
                list_pkg_insttemp=("${temp_list_pkgnames[$i]}")
              else
                list_pkg_insttemp=("${list_pkg_insttemp[@]}" "${temp_list_pkgnames[$i]}")
              fi
            fi
          fi

          if [[ -z "$pkgstatus" && -z "$existence_pkg_in_repo" && "${#temp_list_pkgnames[@]}" -eq "1" ]] || [[ -z "$pkgstatus" && -z "$existence_pkg_in_repo" && "${#list_pkg_insttemp[@]}" -eq "0" && "$i" -eq "$(expr ${#temp_list_pkgnames[@]} - 1)" ]]; then
            if [[ "${#pkg_noinst_and_notinrepo[@]}" -eq "0" ]]; then
              pkg_noinst_and_notinrepo=("${list_names_pkg[$j]}")
            else
              pkg_noinst_and_notinrepo=("${pkg_noinst_and_notinrepo[@]}" "${list_names_pkg[$j]}")
            fi
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

          if [[ "${#list_pkg_inst[@]}" -eq "0" ]]; then
            list_pkg_inst=("${list_pkg_insttemp[0]}")
          else
            list_pkg_inst=("${list_pkg_inst[@]}" "${list_pkg_insttemp[0]}")
          fi

        elif [[ "${#list_pkg_insttemp[@]}" -gt "1" ]]; then
          echo -e "\n${YELLOW}Обнаружено несколько неустановленнных пакетов из списка (${list_names_pkg[$j]}) присутствующих в репозитории.
Выберите 1 пакет для добавления в список установки.$NoColor\n"

          while true; do
            PS3="Введите номер: "
            COLUMNS=1

            select listlist_pkg_insttemp in "${list_pkg_insttemp[@]}"; do

              if [[ "$REPLY" =~ $check_num ]]; then

                if [[ "$REPLY" -gt "0" ]] && [[ "$REPLY" -le "${#list_pkg_insttemp[@]}" ]]; then

                  if [[ "${#list_pkg_inst[@]}" -eq "0" ]]; then
                    list_pkg_inst=("$listlist_pkg_insttemp")
                  else
                    list_pkg_inst=("${list_pkg_inst[@]}" "$listlist_pkg_insttemp")
                  fi
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
    return 1
  fi
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

  if [[ "$send_notifysend" -eq "1" ]] || [[ "$send_flydialog" -eq "1" ]] || [[ "$send_zenity" -eq "1" ]]; then

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
                      cmd_run_send_msg="systemd-run $([[ "$send_msg_use_root" -eq "0" ]] && echo "--uid=\"${activeusername[$num_au]}\" ")/bin/bash -c \"XAUTHORITY='${env_XAUTHORITY[$numenv]}' DBUS_SESSION_BUS_ADDRESS='${env_DBUS_SESSION_BUS_ADDRESS[$numenv]}' DISPLAY='${env_DISPLAY[$numenv]}' notify-send '$headertext' '$(cat ${msgfile[$num_msg]})'\""

                      eval "$cmd_run_send_msg"
                    done
                  fi
                else
                  echo -e "\nnotify-send не найден"
                fi
              fi

              #Если отправка через fly-dialog
              if [[ "$send_flydialog" -eq "1" ]]; then

                if [[ -n "$(which fly-dialog 2>/dev/null)" ]]; then

                  if [[ -n "${env_DISPLAY[$numenv]}" && -n "${env_XAUTHORITY[$numenv]}" ]]; then

                    for ((num_msg = 0; num_msg < ${#msgfile[@]}; num_msg++)); do
                      cmd_run_send_msg="systemd-run $([[ "$send_msg_use_root" -eq "0" ]] && echo "--uid=\"${activeusername[$num_au]}\" ")/bin/bash -c \"XAUTHORITY='${env_XAUTHORITY[$numenv]}' DISPLAY='${env_DISPLAY[$numenv]}' fly-dialog --caption '$headertext' --textbox '${msgfile[$num_msg]}'\""

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
                      cmd_run_send_msg="systemd-run $([[ "$send_msg_use_root" -eq "0" ]] && echo "--uid=\"${activeusername[$num_au]}\" ")/bin/bash -c \"XAUTHORITY='${env_XAUTHORITY[$numenv]}' DISPLAY='${env_DISPLAY[$numenv]}' zenity --text-info --filename='${msgfile[$num_msg]}' --title='$headertext'\""

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
