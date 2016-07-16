
DIRNAME=$(dirname -- $(readlink -f -- $0))
export XDG_DATA_HOME=$DIRNAME
$DIRNAME/update-mime-database $DIRNAME/mime
$DIRNAME/update-mime-database $DIRNAME/discard
