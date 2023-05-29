#! /usr/bin/env modernish
#! use safe
#! use sys/cmd/harden
#! use var/arith

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
  harden -X id

  if not is eq $(id -u) 0
  then
    die 'Run this script as root'
  fi

  harden -X mkdir
  harden -X pwd
  harden -X cat
  harden -X git
  harden -X systemctl

  wd=$(_dirname ${ME}; chdir ${REPLY}; pwd -P)
  readonly wd

  . ${wd}/../const.sh

  if is dir /etc/systemd/system
  then
    printf $(cat ${wd}/systemd/bot.timer) |> /etc/systemd/system/${repo}-bot.timer
    printf $(cat ${wd}/systemd/bot.service) |> /etc/systemd/system/${repo}-bot.service

    mkdir -p /opt
    git clone https://github.com/tiawl/modernish_supported_shells.git /opt/${repo} > /dev/null 2>&1
    git -C /opt/${repo} config user.name 'tiawl-bot' > /dev/null 2>&1
    git -C /opt/${repo} config user.email 'p.tomas431@laposte.net' > /dev/null 2>&1

    systemctl enable ${repo}-bot.timer
  else
    die '/etc/systemd/system does not exists'
  fi
}

main "${@}"
