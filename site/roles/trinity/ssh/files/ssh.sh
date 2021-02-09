if [ "$(id -u 2>/dev/null)" != "0" ]; then
  if [ ! -f ~/.ssh/id_rsa ]; then
    if [ -w ~ ]; then
      echo Creating RSA key for ssh
      ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -q -N ""
      cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
      chmod 600 ~/.ssh/authorized_keys ~/.ssh/id_rsa ~/.ssh/id_rsa.pub
    fi
  fi
fi 
