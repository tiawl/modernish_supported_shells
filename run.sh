#! /usr/bin/env modernish
#! use safe
#! use sys/cmd/harden
#! use var/arith
#! use var/loop

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
  harden -X mkdir
  harden -X cp
  harden -X mv
  harden -X rm

  harden -X pwd
  harden -X getconf

  if ! extern -v -p pstree > /dev/null 2>&1 || \
    ! extern -v -p grep > /dev/null 2>&1 || \
    ! extern -v -p kill > /dev/null 2>&1
  then
    putln 'This script needs pstree, grep and kill utilities to run' 1>&2
    exit 1
  fi

  if not is dir /proc || not is reg /proc/uptime || not is dir /proc/${$}
  then
    putln 'This script needs procfs to run' 1>&2
    exit 1
  fi

  wd=$(_dirname ${ME}; chdir ${REPLY}; pwd -P)

  if extern -v -p nproc > /dev/null 2>&1
  then
    harden -X nproc
    nproc=$(nproc --all)
  elif is reg /proc/cpuinfo
  then
    harden -X grep
    nproc=$(grep -c ^processor /proc/cpuinfo)
  else
    nproc=1
  fi

  readonly wd nproc

  MAX_CPU=${MAX_CPU:-$(( 100 * ${nproc} ))} WD=${wd} ${wd}/scripts/orchestrator.sh "${@}" &
  pid=${!}
  readonly pid

  while is dir /proc/${pid}
  do
    tree=$(pstree -p ${pid} 2> /dev/null | grep -o '([[:digit:]]*)' | grep -o '[[:digit:]]*')
    cpu=0
    LOOP for --split=${CCn} _ps in ${tree}
    DO
      if { read -r REPLY < /proc/${_ps}/stat; } 2> /dev/null
      then
        push IFS
        IFS=')'
        set -- ${REPLY}
        IFS=' '
        set -- ${2}
        pop IFS
        read -r REPLY < /proc/uptime
        REPLY=${REPLY%% *}
        set -- ${12} ${13} ${20} ${REPLY%.*} ${REPLY#*.}
        set -- ${1} ${2} ${3} ${4} ${5%"${5#??}"}
        set -- ${1} ${2} ${3} $(( ((${4} * 100 + ${5#0}) * $(getconf CLK_TCK)) / 100 ))
        set -- $(( ${4} - ${3} )) $(( ${1} + ${2} ))
        if gt ${1} 0
        then
          cpu=$(( ${cpu} + (${2} * 100) / ${1} ))
        fi
      fi
    DONE

    push IFS
    IFS=${CCn}
    if gt ${cpu} ${MAX_CPU:-$(( 100 * ${nproc} ))} && le ${lcpu:-0} ${MAX_CPU:-$(( 100 * ${nproc} ))}
    then
      kill -20 ${tree} > /dev/null 2>&1
    elif gt ${lcpu:-0} ${MAX_CPU:-$(( 100 * ${nproc} ))} && le ${cpu} ${MAX_CPU:-$(( 100 * ${nproc} ))}
    then
      kill -18 ${tree} > /dev/null 2>&1
    fi
    pop IFS
    lcpu=${cpu}
  done
}

main "${@}"
