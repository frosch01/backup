#!/bin/bash

#!/bin/sh
# This script is intended to be used an anacron script to be addd to
# /etc/cron.daily. It may be also invoced on an interactive shell
# As anacron is often based on sh, this script is written for sh

# Exit on any error
set -e

# Determine where script is executing from.
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
SCRIPTFILE=$(basename "$SCRIPT")

# Is the script executed by an interactive environment?
if [ -t 0 ]; then INTERACTIVE=true;  else INTERACTIVE=false; fi

# ...
function usage {
  echo "Usage: ${SCRIPTFILE} [-c <config-file>] [-l] [-d]" 1>&2
  echo "  -f <config_file> Configuration file to be used" 1>&2
  echo "  -l <backup_list> Backup list file to be used" 1>&2
  echo "  -d               Enable debugging" 1>&2
  echo "  -n               Dry run" 1>&2
  exit  1
}

# Set defaults and read arguments
CLIENT_CONFIG_FILE=/etc/backup/client.conf
BACKUP_LIST_FILE=/etc/backup/backup.list
DEBUG=false
DRYRUN=false
while getopts ":l:f:dn" ARGUMENT; do
  case "${ARGUMENT}" in
    l)
      BACKUP_LIST_FILE=${OPTARG}
      ;;
    f)
      CLIENT_CONFIG_FILE=${OPTARG}
      ;;
    d)
      DEBUG=true
      ;;
    n)
      DRYRUN=true
      ;;
    *)
      usage
      ;;
    esac
done
shift $((OPTIND-1))

# Load configuration file
[ -f "${CLIENT_CONFIG_FILE}" ] || { echo "Configuration file ${CLIENT_CONFIG_FILE} not found" 1>&2; exit 1; }
. ${CLIENT_CONFIG_FILE}

# Check for expected variables to be present
[ -n "${RSYNC_HOST}" ] || { echo "RSYNC_HOST is mandatory to be set in ${CLIENT_CONFIG_FILE}" 1>&2; exit 1; }
[ -n "${WORKING_DIR}" ] || WORKING_DIR=/tmp/backup.dir || true
[ -n "${FULL_PATH}" ] || FULL_PATH=true || true

# Check backup list to be present
[ -f "${BACKUP_LIST_FILE}" ] || { echo "backup list file ${BACKUP_LIST_FILE} not found" 1>&2; exit 1; }

# Handle debugging
RSYNC=rsync
if ${INTERACTIVE}; then
  if ${DEBUG}; then
    echo "CLIENT_CONFIG_FILE=${CLIENT_CONFIG_FILE}"
    echo "BACKUP_LIST_FILE=${BACKUP_LIST_FILE}"
    echo "RSYNC_HOST=${RSYNC_HOST}"
    echo "WORKING_DIR=${WORKING_DIR}"
    echo "DEBUG=${DEBUG}"
  fi
  if ${DRYRUN}; then RSYNC="echo rsync"; fi
else
  if ${DRYRUN}; then RSYNC="rsync_stub"; fi
fi

# Rsync options explained
# -r recurse into directories
# -t preserve modification times
# -p preserve permissions
# -l copy symlinks as symlinks
# -u skip files that are newer on the receiver
# -R Use relative paths. This means that the full path names specified on the command line are sent to the server rather than just the last parts of the filenames.
BASIC_OPTS="-r -t -p -l -u"
BACKUP_OPTS="--delete-after --delete-excluded --backup --backup-dir=deleted/`date +%F`"
EXCLUDE_OPTS="--exclude=**/*tmp*/ --exclude=**/*cache*/ --exclude=**/*Cache*/ --exclude=**~ --exclude=**/*Trash*/ --exclude=**/*trash*/ --exclude=**/.gvfs/"
if ${INTERACTIVE}; then INTERACTVE_OPTS="-h --progress --stats"; fi
if ${FULL_PATH} ; then FULL_PATH_OPTS="-R"; fi

# A stubbed function in case of dryrun without interactive terminal
function rsync_stub {
  :
}

# $1 local directory for the backup
function rsync_backup {
  LOCAL_DIR=$1
  BACKUP_REMOTE="${RSYNC_HOST}::$2"
  if $DEBUG; then
    echo "Backing up ${LOCAL_DIR} to ${BACKUP_REMOTE}"
  fi
  if ${RSYNC} ${BASIC_OPTS} ${FULL_PATH_OPTS} ${INTERACTVE_OPTS} ${BACKUP_OPTS} ${EXCLUDE_OPTS} ${LOCAL_DIR} ${BACKUP_REMOTE}; then
    if ! ${DRYRUN}; then
      date +%F >> ${LOCAL_DIR}/.backuptag
    fi
  fi
  if $DEBUG; then
    echo "--------------------------------------------"
  fi
}

function get_backup_list {
  awk -F\# '$1!="" { print $1 ;}' ${BACKUP_LIST_FILE}
}

BACKUP_LIST=`get_backup_list`
for ENTRY in $BACKUP_LIST; do
  if [[ $ENTRY == \[*\] ]]; then
    RSYNC_MODULE=${ENTRY:1:-1}
    LOCAL_DIR=""
  else
    LOCAL_DIR=${ENTRY}
  fi
  [ -n "${RSYNC_MODULE}" ] || { echo "RSYNC_MODULE is mandatory to be given in ${BACKUP_LIST_FILE}" 1>&2; exit 1; }
  [ -n "${LOCAL_DIR}" ] && rsync_backup ${LOCAL_DIR} ${RSYNC_MODULE}
done
