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
  harden -X cp
  harden -X rm
  harden -X mv

  harden -X chown
  harden -X env
  harden -X envsubst
  harden -X pwd
  harden -X systemctl

  if not extern -v -p git > /dev/null 2>&1
  then
    die 'This script needs git utility to run bot when using a proxy.'
  fi

  wd=$(_dirname ${ME}; chdir ${REPLY}/..; pwd -P)
  readonly wd

  . ${wd}/const.sh

  ssh_config=/etc/ssh/ssh_config.d/tiawl-bot.conf
  bot_wd=/opt/${repo}
  readonly ssh_config bot_wd

  if is dir /etc/systemd/system
  then
    env repo=${repo} envsubst < ${wd}/bot/systemd/bot.timer >| /etc/systemd/system/${repo}-bot.timer
    env repo=${repo} envsubst < ${wd}/bot/systemd/bot.service >| /etc/systemd/system/${repo}-bot.service

    mkdir -p /opt

    if is reg ${ssh_config}
    then
      rm -f ${ssh_config}
    fi

    if str empty ${http_proxy:-}
    then
      env HOME=/home/user envsubst < ${wd}/bot/ssh/noproxy.conf >| ${ssh_config}
    elif extern -v -p nc > /dev/null 2>&1
    then
      env http_proxy=${http_proxy#http://} HOME=/home/user envsubst < ${wd}/bot/ssh/proxy.conf >| ${ssh_config}
    else
      die 'This script needs nc utility to run bot when using a proxy.'
    fi

    chown root:root ${ssh_config}

    LOCAL line key file _break
    BEGIN
      push IFS
      IFS="${CCn} "
      while str empty ${_break:-} && read -r line
      do
        case ${line} in
        ( IdentityFile* ) file=$(eval "printf '%s' \"${line#IdentityFile }\"")
                          read -r key < ${file}.pub
                          pop IFS
                          if not str in $(ssh-add -L 2> /dev/null) ${key}
                          then
                            harden -f ssh_add -X ssh-add
                            harden -f ssh_agent -X ssh-agent
                            eval "$(ssh_agent -s)"
                            ssh_add ${file}
                          fi
                          _break=y ;;
        ( * ) ;;
        esac
      done < ${ssh_config}
      pop IFS
    END

    if is dir ${bot_wd}
    then
      rm -r -f ${bot_wd}
    fi

    http_proxy=${http_proxy:-} https_proxy=${https_proxy:-} git clone tiawl-bot:tiawl/modernish_supported_shells.git ${bot_wd} > /dev/null 2>&1
    git -C ${bot_wd} config user.name 'tiawl-bot' > /dev/null 2>&1
    git -C ${bot_wd} config user.email 'p.tomas431@laposte.net' > /dev/null 2>&1
    if not str in $(git config --includes --get-all --system safe.directory 2> /dev/null) ${bot_wd}
    then
      git config --system --add safe.directory ${bot_wd} > /dev/null 2>&1
    fi

    systemctl enable ${repo}-bot.timer
  else
    die '/etc/systemd/system does not exist'
  fi
}

main "${@}"
