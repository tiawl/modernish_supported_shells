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

    git clone git@github.com:tiawl/modernish_supported_shells.git /opt/${repo} > /dev/null 2>&1
    git -C /opt/${repo} config user.name 'tiawl-bot' > /dev/null 2>&1
    git -C /opt/${repo} config user.email 'p.tomas431@laposte.net' > /dev/null 2>&1
    git config --global --add safe.directory /opt/${repo} > /dev/null 2>&1

    systemctl enable ${repo}-bot.timer
  else
    die '/etc/systemd/system does not exists'
  fi
}

main "${@}"
