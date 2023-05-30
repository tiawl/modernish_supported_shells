#!/bin/sh

REPLY=to_del
log=final
rev const.sh >| $REPLY
printf '%.250s\n' "$(tac $REPLY)" >| $log
tac $log >| $REPLY
REPLY=$(rev $REPLY)
printf '%s\n' "$REPLY" >| $log
