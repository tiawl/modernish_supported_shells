#! /usr/bin/env modernish
#! use safe
#! use sys/base/shuf
#! use sys/cmd/harden
#! use sys/term/putr
#! use var/arith
#! use var/assign
#! use var/local
#! use var/loop
#! use var/stack/trap
#! use var/string/touplow

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

help ()
{
  _dirname ${ME}
  push IFS
  IFS=' '
  set -- ${oss}
  IFS=','
  _oss="${*}"
  IFS=' '
  set -- ${shells}
  IFS=','
  _shells="${*}"
  pop IFS

  printf 'Usage:

  ./%s [-f INDEX] [-l] [-s SHELLS] [-t INDEX]

Description:

  Schedule host and containers operations to test modernish installation for different shells

Options:

  -e, --error                -  Error mode: die if runner.sh script execution fail on a container
  -f, --from <INDEX>         -  Start tests from INDEX
                                Use -l/--list option to show available INDEXes for selected shells repositories
                                Default: %s
  -k, --keep                 -  Do not clean Docker objects instanciated AFTER the tests
  -l, --list                 -  Show available INDEXes for selected shells repositories then exit
  -o, --os <OS_LIST>         -  An operating system list to test (use comma to separate elements)
                                Available values: all,%s
                                all is an alias for %s
                                Default: all
  -s, --shells <SHELL_LIST>  -  A shells list to test (use comma to separate elements)
                                Available values: all,%s
                                all is an alias for %s
                                Default: all
  -t, --to <INDEX>           -  End tests before INDEX
                                Use -l/--list option to show available INDEXes for selected shells repositories
                                Default: %s
' ${ME#"${REPLY}/"} ${default_from} ${_oss} ${_oss} ${_shells} ${_shells} ${default_to} 1>&2
}

list_indexes ()
{
  LOCAL table index='-1' _from=${2} _to=${3} _break _continue --split=' ' -- ${1}
  BEGIN
    push IFS
    IFS=':'
    table="index:${*}"
    pop IFS
    shift ${#}

    case ":${table}:" in
    ( *':bash:'* ) set -- "${@}" $(git ls-remote --tags --refs ${bash_url} 'refs/tags/bash-*' | sed 's:^.*/::g; s:^bash-::g' | sort -V -r)${CCn} ;;
    esac

    case ":${table}:" in
    ( *':busybox:'* ) set -- "${@}" $(git ls-remote --tags --refs ${busybox_url} | sed 's:^.*/::g' | sort -V -r)${CCn} ;;
    esac

    case ":${table}:" in
    ( *':dash:'* ) set -- "${@}" $(git ls-remote --tags --refs ${dash_url} | sed 's:^.*/::g' | sort -V -r)${CCn} ;;
    esac

    case ":${table}:" in
    ( *':mksh:'* ) set -- "${@}" $(wget -q -O - ${mksh_url} | pandoc -f html -t plain | grep -o 'mksh-R.*gz' | grep -o 'R[^.]\+' | sort -V -r)${CCn} ;;
    esac

    case ":${table}:" in
    ( *':yash:'* ) set -- "${@}" $(git ls-remote --tags --refs ${yash_url} | sed 's:^.*/::g' | sort -V -r)${CCn} ;;
    esac

    case ":${table}:" in
    ( *':zsh:'* ) set -- "${@}" $(git ls-remote --tags --refs ${zsh_url} 'refs/tags/zsh-*' | sed 's:^.*/::g; s:^zsh-::g' | sort -V -r)${CCn} ;;
    esac

    toupper table

    while not str empty "${*}"
    do
      unset -v _continue
      index=$(( ${index} + 1 ))

      if ge ${index} ${_to}
      then
        shift ${#}
        _break=y
      fi
      if str empty ${_break:-}
      then
        if lt ${index} ${_from}
        then
          LOOP repeat ${#}
          DO
            set -- "${@}" "${1#*"${CCn}"}"
            shift
          DONE
          _continue=y
        fi
        if str empty ${_continue:-}
        then
          table=${table}${CCn}${index}
          LOOP repeat ${#}
          DO
            table=${table}:${1%%"${CCn}"*}
            set -- "${@}" "${1#*"${CCn}"}"
            shift
          DONE
        fi
      fi
    done

    printf '%s\n' "${table}" | csvlook -I
  END
}

runner ()
{
  LOCAL os=${1} sh=${2} tag name img sh_path
        list_tag_cmd="if [ -d ${mount}/${2} ]; then git -C ${mount}/${2} for-each-ref --format '%(refname:short)' refs/tags$(if str eq ${2} bash || str eq ${2} zsh; then printf '/%s-*' ${2}; fi) | sort -V -r | while read -r REPLY; do if [ \${i:-0} -ge ${from:-"${default_from}"} ] && [ \${i:-0} -lt ${to:-"${default_to}"} ]; then printf '%s\\n' \"\${REPLY}\"; fi; i=\"\$(( \${i:-0} + 1 ))\"; done; else printf '%s${CCn}' ${mount}/${2}* | sed 's:^${mount}/::g' | sort -V -r; fi"
  BEGIN
    assign -r name=${os%%:*}_runner_name
    assign -r img=${os%%:*}_runner_img
    shift 2
    push IFS
    IFS=' '
    set -- ${1}
    pop IFS
    LOOP for --split=${CCn} tag in $(docker container exec ${cloner_name} sh -c ${list_tag_cmd})
    DO
      mkdir -p ${logs}/${sh}/${sh}-${tag#"${sh}-"}

      docker container run --name ${name}_${sh}-${tag#"${sh}-"} \
                           --env DOCKER_NAME=${name}_${sh}-${tag#"${sh}-"} \
                           --volume ${volume}:${mount} \
                           --cpu-period=100000 \
                           --cpu-quota=${MAX_CPU:-$(( 100 * ${nproc} ))}000 \
                           --tty --detach ${img} > /dev/null 2>&1

      if docker container exec --env TERM=${TERM:-xterm-256color} --tty \
                               ${name}_${sh}-${tag#"${sh}-"} \
                               sh -c "${ctnr_scripts}/runner.sh ${1} ${sh} ${tag}"
      then
        sh_path=/usr/bin/${sh}
        if str eq ${sh} 'busybox'
        then
          sh_path=/usr/bin/ash
        fi
        docker container exec --env MSH_FTL_DEBUG=y --tty \
                              ${name}_${sh}-${tag#"${sh}-"} \
                              sh -c "\${MOUNT}/modernish/install.sh -n -s ${sh_path} || :" >| ${logs}/${sh}/${sh}-${tag#"${sh}-"}/${os}.log 2>&1
      else
        putln 'Installation failed' >| ${logs}/${sh}/${sh}-${tag#"${sh}-"}/${os}.log 2>&1
        if not str empty ${error_mode}
        then
          trap "if str empty ${keep_docker_obj}; then docker container stop --time 0 ${name}_${sh}-${tag#"${sh}-"} > /dev/null 2>&1; docker container remove --force ${name}_${sh}-${tag#"${sh}-"} > /dev/null 2>&1; docker container stop --time 0 ${cloner_name} > /dev/null 2>&1; docker container remove --force ${cloner_name} > /dev/null 2>&1; docker volume remove --force ${volume} > /dev/null 2>&1; fi;" DIE
          die 'runner.sh failed'
        fi
      fi

      if str empty ${keep_docker_obj}
      then
        docker container stop --time 0 ${name}_${sh}-${tag#"${sh}-"} > /dev/null 2>&1
        docker container remove --force ${name}_${sh}-${tag#"${sh}-"} > /dev/null 2>&1
      fi

      set -- "${@}" ${1}
      shift
    DONE
  END
}

main ()
{
  trace docker

  harden -X mkdir
  harden -X cp
  harden -X mv
  harden -X rm

  harden -X sort
  harden -X sed
  harden -X git
  harden -X csvlook
  harden -X wget
  harden -X pandoc

  if not extern -v -p grep > /dev/null 2>&1
  then
    putln 'This script needs grep utility to run' 1>&2
    exit 1
  fi

  if extern -v -p nproc > /dev/null 2>&1
  then
    harden -X nproc
    nproc=$(nproc --all)
  elif is reg /proc/cpuinfo
  then
    nproc=$(grep -c ^processor /proc/cpuinfo)
  else
    nproc=1
  fi

  . ${WD}/const.sh

  mount='/opt/clones'
  volume=${repo}-clones
  cloner_name=${repo}_cloner
  runner_name=${repo}_runner
  alpine_runner_name=${runner_name}_alpine-3.18.0
  cloner_img=${repo}-cloner
  runner_img=${repo}-runner
  alpine_runner_img=${runner_img}-alpine:3.18.0
  alpine_install='apk add --update --no-cache'
  alpine_update='apk update'
  cloner_pkgs='cpio git lynx'
  alpine_runner_pkgs='autoconf automake bison coreutils e2fsprogs-dev gcc gettext-dev git linux-headers make musl-dev ncurses ncurses-dev'
  ctnr_scripts=/opt/${repo}/scripts
  ushells=${shells}
  oss='alpine:3.18.0'
  uoss=${oss}
  default_from=0
  default_to=99999
  keep_docker_obj=
  list_mode=
  error_mode=
  readonly WD nproc \
           mount volume \
           cloner_name cloner_img cloner_pkgs \
           runner_name runner_img \
           alpine_install alpine_update \
           alpine_runner_name alpine_runner_img alpine_runner_pkgs \
           ctnr_scripts oss \
           default_from default_to

  while gt ${#} '0'
  do
    case ${1} in
    ( -h|--help) help
                 exit 1 ;;

    # Handle '-abc' the same as '-a -bc' for short-form no-arg options
    ( -[ekl]?* ) push IFS
                 IFS=' '
                 set -- ${1%"${1#??}"} -${1#??} $(shift; put "${@}")
                 pop IFS
                 continue ;;

    # Handle '-foo' the same as '-f oo' for short-form 1-arg options
    ( -[fost]?* ) push IFS
                  IFS=' '
                  set -- ${1%"${1#??}"} ${1#??} $(shift; put "${@}")
                  pop IFS
                  continue ;;

    # Handle '--file=file1' the same as '--file file1' for long-form 1-arg options
    ( --from=*|--os=*|--shells=*|--to=* ) push IFS
                                          IFS=' '
                                          set -- ${1%%=*} ${1#*=} $(shift; put "${@}")
                                          pop IFS
                                          continue ;;

    # No-arg options
    ( -e|--error ) error_mode=y ;;
    ( -k|--keep ) keep_docker_obj=y ;;
    ( -l|--list ) list_mode=y ;;

    # 1 mandatory arg options
    ( -f|--from ) from=${2}
                  if not str isint ${from} || lt ${from} 0
                  then
                    putln '--from argument must be a positive or null integer' 1>&2
                    exit 1
                  fi
                  shift ;;

    ( -o|--os ) shift
                if str eq ${1} 'all'
                then
                  uoss=${oss}
                else
                  LOCAL --split=',' -- ${1}
                  BEGIN
                    push IFS
                    IFS=' '
                    uoss="${*}"
                    pop IFS
                  END
                fi ;;

    ( -s|--shells ) shift
                    if str eq ${1} 'all'
                    then
                      ushells=${shells}
                    else
                      LOCAL --split=',' -- ${1}
                      BEGIN
                        push IFS
                        IFS=' '
                        ushells="${*}"
                        pop IFS
                      END
                    fi ;;

    ( -t|--to ) to=${2}
                if not str isint ${to} || lt ${to} 0
                then
                  putln '--to argument must be a positive or null integer' 1>&2
                  exit 1
                fi
                shift ;;

    ( * ) putln "Unknown option '${1}' 'Run ${ME} -h" 1>&2
          exit 1 ;;
    esac
    shift
  done

  if ge ${from:-"${default_from}"} ${to:-"${default_to}"}
  then
    to=$(( ${from} + 1 ))
    putln '--from argument should be less than --to argument' \
      '--to argument is changed to be the --from argument plus 1' 1>&2
  fi

  readonly from uoss ushells to keep_docker_obj list_mode error_mode

  if not str empty ${list_mode}
  then
    list_indexes ${ushells} ${from:-"${default_from}"} ${to:-"${default_to}"}
    exit 0
  fi

  ctnrs=$(docker container list --filter name=${repo} --all --quiet)
  readonly ctnrs
  if not str empty ${ctnrs}
  then
    push IFS
    IFS=${CCn}
    docker container stop --time 0 ${ctnrs} > /dev/null 2>&1
    docker container remove --force ${ctnrs} > /dev/null 2>&1
    pop IFS
  fi

  if not str empty $(docker volume list --filter name=${repo} --quiet)
  then
    docker volume remove --force ${volume} > /dev/null 2>&1
  fi

  imgs=$(docker image list --all --filter reference=${repo}* --quiet)
  readonly imgs
  if not str empty ${imgs}
  then
    push IFS
    IFS=${CCn}
    docker image remove --force ${imgs} > /dev/null 2>&1
    pop IFS
  fi

  docker builder prune --all --force > /dev/null 2>&1

  push IFS
  IFS=${CCn}

  set -- $(printf '%s' "227 11 184${CCn}214 208 166${CCn}203 196 124${CCn}207 200 127${CCn}171 165 91${CCn}135 93 55${CCn}69 21 19${CCn}45 39 32${CCn}87 51 44${CCn}85 48 41${CCn}120 118 112" | shuf)
  pop IFS

  trap '' CONT TSTP

  docker builder build --build-arg from=alpine:3.18.0 \
                       --build-arg repo=${repo} \
                       --build-arg mount=${mount} \
                       --build-arg update=${alpine_update} \
                       --build-arg install=${alpine_install} \
                       --build-arg pkgs=${cloner_pkgs} \
                       --build-arg http_proxy=${http_proxy:-"${HTTP_PROXY:-}"} \
                       --build-arg https_proxy=${https_proxy:-"${HTTPS_PROXY:-}"} \
                       --tag ${cloner_img} ${WD} > /dev/null 2>&1 &

  LOCAL img update install pkgs
  BEGIN
    LOOP for --split=' ' os in ${uoss}
    DO
      assign -r img=${os%%:*}_runner_img
      assign -r update=${os%%:*}_update
      assign -r install=${os%%:*}_install
      assign -r pkgs=${os%%:*}_runner_pkgs
      docker builder build --build-arg from=${os} \
                           --build-arg repo=${repo} \
                           --build-arg mount=${mount} \
                           --build-arg update=${update} \
                           --build-arg install=${install} \
                           --build-arg pkgs=${pkgs} \
                           --build-arg http_proxy=${http_proxy:-"${HTTP_PROXY:-}"} \
                           --build-arg https_proxy=${https_proxy:-"${HTTPS_PROXY:-}"} \
                           --tag ${img} ${WD} > /dev/null 2>&1 &
    DONE
  END

  wait
  trap - CONT TSTP

  docker container run --name ${cloner_name} \
                       --env DOCKER_NAME=${cloner_name} \
                       --volume ${volume}:${mount} \
                       --cpu-period=100000 \
                       --cpu-quota=${MAX_CPU:-$(( 100 * ${nproc} ))}000 \
                       --tty --detach ${cloner_img} > /dev/null 2>&1

  docker container exec --env TERM=${TERM:-xterm-256color} ${cloner_name} \
                        sh -c "${ctnr_scripts}/cloner.sh ${from:-"${default_from}"} ${to:-"${default_to}"} '${ushells}'"

  mkdir -p ${logs}

  LOCAL shell log suffix
  BEGIN
    trap '' CONT TSTP

    LOOP for --split=' ' os in ${uoss}
    DO
      LOOP for --split=' ' shell in ${ushells}
      DO
        runner ${os} ${shell} ${1} &
        shift
      DONE
    DONE

    wait
    trap - CONT TSTP

    if str empty ${keep_docker_obj}
    then
      docker container stop --time 0 ${cloner_name} > /dev/null 2>&1
      docker container remove --force ${cloner_name} > /dev/null 2>&1
      docker volume remove --force ${volume} > /dev/null 2>&1
    fi

    putln '# Modernish supported shells' '' \
      'A detailed list of POSIX-compliant shells versions supported by the last [modernish](https://github.com/modernish/modernish) version' '' \
      '## Before going further' '' \
      'If you achieve to install the last **modernish** version with a shell version marked as unsupported, we would be very grateful if you could open an issue [here](https://github.com/tiawl/modernish_supported_shells/issues) to explain us how you make it works: let us know of any successes !' '' \
      'If you do not achieve to install the last **modernish** version with a shell version marked as supported, you definitely should consider the [scripts/runner.sh script](https://github.com/tiawl/modernish_supported_shells/blob/main/scripts/runner.sh) before opening an issue.' '' \
      'If you want to know if an unlisted shell or an unlisted shell version is supported with the last **modernish** version, please open an issue [here](https://github.com/tiawl/modernish_supported_shells/issues).' '' \
      'If your shell version is marked as (:grey_question:), there are 2 possibilities: we are working on it or this shell version is not intented to be supported.' '' \
      'If your shell is listed here, is marked as unsupported by the last **modernish** version and you want to know why, you definitely should consider the ['${logs#"${WD}/"}' directory](https://github.com/tiawl/modernish_supported_shells/blob/main/'${logs#"${WD}/"}') before opening an issue into the [modernish main project](https://github.com/modernish/modernish) (**Useful tip**: Run `less -R '${logs#"${WD}/"}'/<SHELL>/<LOGFILE>` for a better reading experience).' >| ${readme} '' \
      '_The following tables are generated through script._'

    LOOP for --split=' ' shell in ${shells}
    DO
      if str eq ${shell} 'busybox'
      then
        suffix='-ash'
      else
        unset -v suffix
      fi

      push IFS
      IFS=' '
      set -- ${oss}
      IFS='|'
      putln '' "## ${shell}${suffix:-}" '' "|Version|${*}|" "|:---|$(putr ${#} ':---:|')" >> ${readme}
      pop IFS

      LOOP for --split=${CCn} tag in $(set +f; printf '%s\n' ${logs}/${shell}/* | sort -V -r)
      DO
        if is dir ${tag}
        then
          printf '|%s|' ${tag#"${logs}/${shell}/"} >> ${readme}

          push IFS
          IFS=' '
          set -- ${oss}
          pop IFS

          LOOP for --split=${CCn} log in $(set +f; LC_ALL=C; printf '%s\n' ${tag}/*)
          DO
            log=${log%.log}

            if str eq ${log#"${tag}/"} ${1}
            then
              if grep -E 'Modernish [-.a-z0-9]+ installed successfully' "${log}.log" > /dev/null
              then
                printf ':heavy_check_mark:|' >> ${readme}
              else
                if grep -E "Installation failed|^${mount}/modernish/install.sh: shell not found: /usr/bin/" "${log}.log" > /dev/null
                then
                  printf ':grey_question:|' >> ${readme}
                else
                  printf ':x:|' >> ${readme}
                fi
              fi
            else
              printf ' |' >> ${readme}
            fi
            shift
          DONE
          putln >> ${readme}
        fi
      DONE
    DONE
  END
}

main "${@}"
