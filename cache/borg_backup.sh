#!/bin/bash
set -e

# ...
function usage {
  echo "Usage: ${SCRIPTFILE} [-c <config-file>] [-l] [-d]" 1>&2
  echo "  -f <config_file> Configuration file to be used" 1>&2
  echo "  -n               Dry run" 1>&2
}

# Set defaults and read arguments
CACHE_CONFIG_FILE=/etc/backup/cache.conf
OPTIND=1
DRYRUN=false
while getopts ":f:n" ARGUMENT; do
  case "${ARGUMENT}" in
    f)
      CACHE_CONFIG_FILE=${OPTARG}
      ;;
    n)
      DRYRUN=true
      ;;
    *)
      usage
      exit 1
      ;;
    esac
done
shift $((OPTIND-1))

# Load configuration file settings
source ./backup_env.sh -f ${CACHE_CONFIG_FILE}

# Command aliases
DATE=$(date +%F)
BORG=borg
if ${DRYRUN}; then BORG="echo borg"; fi

function backup_dir {
  DIR=$1
  if [[ $# == 2 ]]; then LEVEL=$2; else LEVEL=0; fi
  EXCLUDE="${DIR}/$(for i in $(seq $LEVEL); do printf '*/'; done)deleted/*"
  ARCHIVE=${DATE}_$(basename ${DIR})
  echo
  echo "Creating backup of $(du -hs --exclude=${EXCLUDE} ${DIR}) into ${ARCHIVE}"
  echo
  ${BORG} create --exclude "${EXCLUDE}" --progress --stats ::${ARCHIVE} ${DIR}
}

backup_dir /data/media/fotos
backup_dir /data/media/videos
backup_dir /data/einstein 1
backup_dir /data/vdr
backup_dir /data/cubie
backup_dir /data/android_ralph

ssh-agent -k
exit 0

echo "Creating backup of `du -hs /data/media/fotos`"
echo
borg create --progress ::${DATE}_fotos          /data/media/fotos   || exit 1

echo
echo "Creating backup of `du -hs /data/media/videos`"
echo
borg create --progress ::${DATE}_videos         /data/media/videos || exit 2

echo
echo "Creating backup of `du -hs /data/einstein`"
echo
borg create --progress ::${DATE}_einstein      /data/einstein      || exit 3

echo
echo "Creating backup of `du -hs /data/vdr`"
echo
borg create --progress ::${DATE}_vdr           /data/vdr           || exit 4

echo
echo "Creating backup of `du -hs /data/cubie`"
echo
borg create --progress ::${DATE}_cubie         /data/cubie         || exit 5

echo
echo "Creating backup of `du -hs /data/android_ralph`"
echo
borg create --progress ::${DATE}_android_ralph /data/android_ralph || exit 6

echo
ssh-agent -k

exit 0

