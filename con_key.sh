#Команда подключения ssh
sshconcmd='ssh -F /dev/null -o ConnectTimeout=$sshtimeout -o ServerAliveInterval=$ssh_check_interval -o ServerAliveCountMax=$ssh_check_col -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=yes -o PreferredAuthentications=publickey -o IdentitiesOnly=yes -i "$sshkeyfile" -o AddKeysToAgent=yes -t -t $logname@$(printf %s ${list_ipall[$i]}) -p $numportssh "${sshcmd[$sshcmdnum]}"'

#Команда подключения scp
scpconcmd='scp $scprun -C -F /dev/null -o ConnectTimeout=$sshtimeout -o ServerAliveInterval=$ssh_check_interval -o ServerAliveCountMax=$ssh_check_col -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=yes -o PreferredAuthentications=publickey -o IdentitiesOnly=yes -i "$sshkeyfile" -o AddKeysToAgent=yes -P $numportssh -r "$temp_dir_send_script/$tempnamescript" $logname@$(printf %s ${list_ipall[$i]}):"$scpcmd"'

#Команда подключения rsync
rsyncconcmd='rsync -avkczhe "ssh -F /dev/null -o ConnectTimeout=$sshtimeout -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=yes -o PreferredAuthentications=publickey -o IdentitiesOnly=yes -i "$sshkeyfile" -o AddKeysToAgent=yes -p $numportssh" --timeout=$rsync_timeout --progress "$temp_dir_send_script/$tempnamescript" $logname@$(printf %s ${list_ipall[$i]}):"$remotedirrunscript"'
