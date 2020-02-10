# This script is intended to be sourced by bash. It provides basic
# setup of borg backup for use with german provider hetzner

# ...
function usage {
  echo "Usage: ${SCRIPTFILE} [-c <config-file>] [-l] [-d]" 1>&2
  echo "  -f <config_file> Configuration file to be used" 1>&2
}

# Set defaults and read arguments
CACHE_CONFIG_FILE=/etc/backup/cache.conf
OPTIND=1
while getopts ":f:" ARGUMENT; do
  case "${ARGUMENT}" in
    f)
      CACHE_CONFIG_FILE=${OPTARG}
      ;;
    *)
      usage
      return 1
      ;;
    esac
done
shift $((OPTIND-1))

# Load the configuration and test settings, apply default when optional
[ -f "${CACHE_CONFIG_FILE}" ] || { echo "Configuration file ${CACHE_CONFIG_FILE} not found" 1>&2; return 1; }
. ${CACHE_CONFIG_FILE}

# Test for source of private key file
if [ ! -r "${SSH_PRIVATE_KEY_FILE}" ]; then
  KEY_FILE_EXTEN=${SSH_PRIVATE_KEY_FILE##*/}
  KEY_FILE_NOEXT=${KEY_FILE_EXTEN%%.*}
  SSH_PRIVATE_KEY_OPT1=${HOME}/.ssh/${KEY_FILE_EXTEN}
  SSH_PRIVATE_KEY_OPT2=${HOME}/.ssh/${KEY_FILE_NOEXT}
  if [ -r ${SSH_PRIVATE_KEY_OPT1} ]; then
    SSH_PRIVATE_KEY_FILE=${SSH_PRIVATE_KEY_OPT1}
  elif [ -r ${SSH_PRIVATE_KEY_OPT2} ]; then
    SSH_PRIVATE_KEY_FILE=${SSH_PRIVATE_KEY_OPT2}
  else
    echo "Unable to find valid private key file. File missing or not readable" 2>&1
    echo "Files tried are:" 2>%1
    echo "  1. ${SSH_PRIVATE_KEY_FILE}" 2>&1
    echo "  2. ${SSH_PRIVATE_KEY_OPT1}" 2>&1
    echo "  3. ${SSH_PRIVATE_KEY_OPT2}" 2>&1
    return 1;
  fi
fi

# Add provate key to ssh-agent. Start agent if not runing
if [[ ! -v SSH_AGENT_PID ]]; then
  eval `ssh-agent` || { echo "starting ssh-agent failed" 1>&2; return 1; }
fi
if ! ssh-add -l | grep -q ${SSH_PRIVATE_KEY_FILE}; then
  ssh-add ${SSH_PRIVATE_KEY_FILE} || { echo "Adding private key ${SSH_PRIVATE_KEY_FILE} to ssh-agent failed"; return 1; }
fi

# Export / clean environment
export BORG_REPO="ssh://u174119@u174119.your-storagebox.de:23/./Backup/cubie"
export BORG_REMOTE_PATH="borg-1.1"
echo -n "Please give password for backup repository $BORG_REPO: "
read -s BORG_PASSPHRASE
echo
export BORG_PASSPHRASE
