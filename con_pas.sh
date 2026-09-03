#Команда подключения ssh
sshconcmd='sshpass -d $num_descriptior ssh -F /dev/null -o ConnectTimeout=$sshtimeout -o ServerAliveInterval=$ssh_check_interval -o ServerAliveCountMax=$ssh_check_col -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -t -t $logname@$(printf %s ${list_ipall[$i]}) -p $numportssh "${sshcmd[$sshcmdnum]}"'

#Команда подключения scp
scpconcmd='sshpass -d $num_descriptior scp $scprun -C -F /dev/null -o ConnectTimeout=$sshtimeout -o ServerAliveInterval=$ssh_check_interval -o ServerAliveCountMax=$ssh_check_col -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -P $numportssh -r "$temp_dir_send_script/$tempnamescript" $logname@$(printf %s ${list_ipall[$i]}):"$scpcmd"'

#Команда подключения rsync
rsyncconcmd='sshpass -d $num_descriptior rsync -avkczhe "ssh -F /dev/null -o ConnectTimeout=$sshtimeout -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -p $numportssh" --timeout=$rsync_timeout --progress "$temp_dir_send_script/$tempnamescript" $logname@$(printf %s ${list_ipall[$i]}):"$remotedirrunscript"'
