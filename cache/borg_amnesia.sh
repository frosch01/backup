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
#source ./borg_env.sh -f ${CACHE_CONFIG_FILE}

BORG_DEL="borg delete -s"
BORG_INFO="borg info"
if ${DRYRUN}; then BORG_DEL="borg delete -n"; fi

BACKUPS=$(borg list --format "{time} {name}{NL}" ::)
while read -r BACKUP; do
    BACKUP_DATE=$(echo ${BACKUP} | cut -d " " -f 2,3)
    BACKUP_NAME=$(echo ${BACKUP} | cut -d " " -f 4)
    BACKUP_TIME=$(date -d "$BACKUP_DATE" +"%s")
    NOW=$(date +"%s")
    if ((${NOW}-${BACKUP_TIME}>2*31557600)); then
        echo "Backup $BACKUP_NAME from $BACKUP_DATE will be deleted, you have 2s to abort"
        echo "Command executed: ${BORG_DEL} ::${BACKUP_NAME}"
        sleep 2
        ${BORG_DEL} ::${BACKUP_NAME}
    fi
done < <(echo "${BACKUPS}")

${BORG_INFO} ::
