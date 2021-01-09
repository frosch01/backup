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
source ./borg_env.sh -f ${CACHE_CONFIG_FILE}

# Command aliases
DATE=$(date +%F)
BORG=borg
if ${DRYRUN}; then BORG="echo borg"; fi

# backup_dir <backup-dir> [rsync_backup-level]
#
# Create borg backup archive from the given backup directory. The name of
# the borg archive is taken from the last path component.
# "deleted" directory as created by rsync are excluded from the backup.
# Depending on the ways rsync is used, there is perhaps more than 1 rsync
# source that uses a backup directory. So deleted directory is not always
# found at the root of the backup directory. With the 2nd arugment, one may
# give the number of additional path levels in use by rsync.
#
# PARAMETERS:
# backup-dir:         Directory that shall be pushed to borg server
# rsync-backup-level: Additinal path levels to the backups directory
# return:             The exit code from borg create.
#
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
