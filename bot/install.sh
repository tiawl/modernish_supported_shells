#! /usr/bin/env modernish
#! use safe
#! use sys/cmd/harden
#! use var/arith
#! use var/local

_dirname ()
{
  set -- ${1:-.}
  set -- ${1%%"${1##*[!/]}"}

  if not str empty ${1##*/*}
  then
    set -- '.'
  fi

  set -- ${1%/*}
  set -- ${1%%"${1##*[!/]}"}
  REPLY=${1:-/}
}

main ()
{
  PS4="[e\${?:-0}] "
  readonly PS4

  set -x

  harden -X id

  if not eq $(id -u) 0
  then
    die 'Run this script as root'
  fi

  harden -X mkdir
  harden -X env
  harden -X envsubst
  harden -X pwd
  harden -X git
  harden -X systemctl
  harden -f ssh_add -X ssh-add

  wd=$(_dirname ${ME}; chdir ${REPLY}; pwd -P)
  readonly wd

  . ${wd}/../const.sh

  if is dir /etc/systemd/system
  then
    env repo=${repo} envsubst < ${wd}/systemd/bot.timer >| /etc/systemd/system/${repo}-bot.timer
    env repo=${repo} envsubst < ${wd}/systemd/bot.service >| /etc/systemd/system/${repo}-bot.service

    mkdir -p /opt

    if is dir /opt/${repo}
    then
      rm -r -f /opt/${repo}
    fi

    if is reg /etc/ssh/ssh_config.d/tiawl-bot.conf
    then
      LOCAL line key _break
      BEGIN
        while str empty ${_break:-} && read -r line
        do
          case ${line} in
          ( IdentityFile* ) read -r key < ${line#IdentityFile }
                            if not str in $(ssh_add -L) ${key}
                            then
                              ssh_add ${line#IdentityFile }
                            fi
                            _break=y ;;
          ( * ) ;;
          esac
        done < /etc/ssh/ssh_config.d/tiawl-bot.conf
      END
      git clone tiawl-bot:tiawl/modernish_supported_shells.git /opt/${repo} > /dev/null 2>&1
      git -C /opt/${repo} config user.name 'tiawl-bot' > /dev/null 2>&1
      git -C /opt/${repo} config user.email 'p.tomas431@laposte.net' > /dev/null 2>&1
      git config --global --add safe.directory /opt/${repo} > /dev/null 2>&1

      systemctl enable ${repo}-bot.timer
    else
      die '/etc/ssh/ssh_config.d/tiawl-bot.conf does not exist'
    fi
  else
    die '/etc/systemd/system does not exist'
  fi
}

main "${@}"
