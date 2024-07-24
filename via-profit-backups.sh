#!/bin/bash

#+-----------------------------------------------------------------------+
#|              Copyright (C) 2024 LLC Via-profit                        |
#!              website: https://via-profit.ru                           |
#+-----------------------------------------------------------------------+
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

cd "$(dirname "$0")"

if ! [ -f ./.env ]; then
  echo "Error. environment file ./.env does not exists"
  echo "Script will now exit..."
  exit 1
fi

# import environment file
. ./.env

###################################################################
#                          compare_dates()                        #
###################################################################

# Compares the dates which are extracted from the two (2) timestamps
# given as function parameters.
# Return value:	'0' - if date0 = date1
#          	'1' - if date0 < date1
#          	'2' - if date0 > date1
#
# Parameters:	$1 -> Timestamp #0
#		$2 -> Timestamp #1
#
# The format of Timestamp #0 and #1 matches the template of ${TIMESTAMP}.
# i.e. 2016-06-20_11-50-20
compare_dates() {
  d0=${1::10}
  d1=${2::10}

  if [ "${d0}" \< "${d1}" ]; then
    return 1
  elif [ "${d0}" \> "${d1}" ]; then
    return 2
  fi
  return 0
}

###################################################################
#                          init_logging()                         #
###################################################################

# This function initialize log files and promts stdin of this script to this file
init_logging() {

  LOG_TIMESTAMP=$(date "+%Y-%m")
  TO_REMOVE_LOG_TIMESTAMP=$(date --date="${BACKUP_LOG_MONTH_AMOUNT} month ago" "+%Y-%m")
  DEFAULT_LOG_FOLDER="./log"
  BACKUP_LOG_FOLDER="${BACKUP_LOG_ROOT_FOLDER:-$DEFAULT_LOG_FOLDER}"

  # Create log folder if not exists
  if [ ! -d ${BACKUP_LOG_FOLDER} ]; then
    mkdir -p ${BACKUP_LOG_FOLDER}
    if [ ${?} -ne 0 ]; then
      echo "Error creating ${BACKUP_LOG_FOLDER}!"
      echo "Script will now exit..."
      exit 1
    fi
  fi

  BACKUP_LOG_FILES=$(ls -1 ${BACKUP_LOG_FOLDER} | grep -E \
    "^backup_[0-9]{4}-[0-9]{2}.log" \
    2>/dev/null | sort -r)

  # Clear old log files
  for file in ${BACKUP_LOG_FILES}; do
    BACKUP_TIME=${file:(-11):7}

    compare_dates ${BACKUP_TIME} ${TO_REMOVE_LOG_TIMESTAMP}
    x=${?}
    if [ ${x} -le 1 ]; then
      # Drop expired backups
      rm ${BACKUP_LOG_FOLDER}/${file}
    fi
  done

  #Compile path of log file
  BACKUP_LOG_FILE=${BACKUP_LOG_FOLDER}/backup_${LOG_TIMESTAMP}.log

  # Create log file if not exists
  if [ ! -f $BACKUP_LOG_FILE ]; then
    touch $BACKUP_LOG_FILE
  fi

  # promt stdin & stderr to log file
  exec 3>&1 4>&2
  trap 'exec 2>&4 1>&3' 0 1 2 3
  exec 1>${BACKUP_LOG_FILE} 2>&1
}

if [ "$BACKUP_LOG_WRITE" = true ]; then
  init_logging
fi

TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")

###################################################################
#                          check_config()                         #
###################################################################

# Checks if the directory where the backups will be saved exists
# (creates it if needed), then checks if the directory to be backed
# up exists and finally if the day for the backup to be taken
# is valid.
#
# Parameter:	$1 -> {WIKI, CLOUD, ...}
check_params() {
  TOKEN_LOWERCASE=$(echo ${1} | tr '[:upper:]' '[:lower:]')
  BACKUPS_DIR_NAME="${1}_BACKUPS_DIR"
  BACKUPS_DIR="${!BACKUPS_DIR_NAME}/${TOKEN_LOWERCASE}"
  BACKUPS_DATABASE_DIR="${!BACKUPS_DIR_NAME}/${TOKEN_LOWERCASE}/db"
  DIR="${1}_DIR"
  BACKUPS_AMOUNT="${1}_BACKUPS_AMOUNT"
  DATABASE_NAME="${1}_DATABASE_NAME"

  if [ ! -d ${BACKUPS_DIR} ]; then
    echo "Creating...${BACKUPS_DIR}"
    mkdir -p ${BACKUPS_DIR}
    if [ ${?} -ne 0 ]; then
      echo "Error creating ${BACKUPS_DIR}!"
      echo "Script will now exit..."
      exit 1
    fi
  fi

  if [ ! -d ${BACKUPS_DATABASE_DIR} ] && [ ! -z ${!DATABASE_NAME} ]; then
    echo "Creating...${BACKUPS_DATABASE_DIR}"
    mkdir -p ${BACKUPS_DATABASE_DIR}
    if [ ${?} -ne 0 ]; then
      echo "Error creating ${BACKUPS_DATABASE_DIR}!"
      echo "Skip database backup..."
      return 1
    fi
  fi

  if [ ! -d ${!DIR} ]; then
    echo "${!DIR}: No such directory!"
    echo "Script will now exit..."
    exit 2
  fi

  if [ "${BACKUPS_DIR}" == "${!DIR}" ]; then
    echo "\$${BACKUPS_DIR} and \$${DIR} are the same!"
    echo "Script will now exit..."
    exit 3
  fi

  if [ -z ${!BACKUPS_AMOUNT} ]; then
    echo "The length of variable: \$${BACKUPS_AMOUNT} is 0 (zero)!"
    echo "Script will now exit..."
    exit 4
  fi

  # Checking load average
  la=$(cat /proc/loadavg | cut -f 1 -d ' ' | cut -f 1 -d '.')
  i=0
  while [ "$la" -ge "$BACKUP_LA_LIMIT" ]; do
    echo -e "$(date "+%F %T") Load Average $la"
    sleep 60
    if [ "$i" -ge "15" ]; then
      echo "\$${la} greather than \$${BACKUP_LA_LIMIT}! Your server will burn if we start this backup. Aborting"
      echo "Script will now exit..."
      exit 5
    fi
    la=$(cat /proc/loadavg | cut -f 1 -d ' ' | cut -f 1 -d '.')
    ((++i))
  done

  # Checking disk space
  disk_usage=$(df ${BACKUPS_DIR} | tail -n1 | tr ' ' '\n' | grep % | cut -f 1 -d %)
  if [ "$disk_usage" -ge "$BACKUP_DISK_LIMIT" ]; then
    echo "Not enough disk space"
    echo "Script will now exit..."
    exit 6
  fi
}

###################################################################
#                          make_backup()                          #
###################################################################

# The main worker function
# It makes a backup for a given folder
# Function takes an alias of project as a $1 param

# Parameter:	$1 -> {WIKI, CLOUD, ...}

make_backup() {
  TOKEN_LOWERCASE=$(echo ${1} | tr '[:upper:]' '[:lower:]')
  BACKUPS_DIR_NAME="${1}_BACKUPS_DIR"
  BACKUPS_DIR="${!BACKUPS_DIR_NAME}/${TOKEN_LOWERCASE}"
  DIR="${1}_DIR"

  TEMPFILE="$(mktemp /tmp/backup.XXXXXX)"
  PATH_TOKENS=$(echo ${!DIR} | tr "/" " ")

  for token in ${PATH_TOKENS[@]}; do
    continue
  done

  PATHTODIR=${!DIR/\/$token/}

  echo -e "\nBacking up ${!DIR} ..."
  echo -e "This might take some time!\n"

  if [ -f "${!DIR}/.backup.exclude" ]; then
    echo -e "Backup exlude file was found! ${!DIR}/.backup.exclude \n"
    tar --exclude-from="${!DIR}/.backup.exclude" -zcf ${TEMPFILE} -C ${PATHTODIR} ./${token}
  else
    tar -zcf ${TEMPFILE} -C ${PATHTODIR} ./${token}
  fi

  if [ $? -ne 0 ]; then
    echo "tar: Exited with errors!"
    rm ${TEMPFILE}
    echo "Script will now exit..."
    exit 3
  fi

  mv ${TEMPFILE} ${BACKUPS_DIR}/backup_${TOKEN_LOWERCASE}_${TIMESTAMP}.tar.gz
}

###################################################################
#                     make_database_backup()                      #
###################################################################

# This function performs database backup using creditanils from config
# Only Postrgesql is supported for this moment
# _DATABASE_USER - Database user
# _DATABASE_NAME - Database name
# _DATABASE_PASSWORD - Database password
#
# Parameter:	$1 -> {WIKI, CLOUD, ...}
make_database_backup() {
  TOKEN_LOWERCASE=$(echo ${1} | tr '[:upper:]' '[:lower:]')
  BACKUPS_DIR_NAME="${1}_BACKUPS_DIR"
  BACKUPS_DATABASE_DIR="${!BACKUPS_DIR_NAME}/${TOKEN_LOWERCASE}/db"
  DATABASE_USER="${1}_DATABASE_USER"
  DATABASE_NAME="${1}_DATABASE_NAME"
  DATABASE_PASSWORD="${1}_DATABASE_PASSWORD"
  DATABASE_HOST="${1}_DATABASE_HOST"
  DATABASE_PORT="${1}_DATABASE_PORT"

  if [ -z ${!DATABASE_PORT} ]; then
    echo "The length of variable: \$${DATABASE_PORT} is 0 (zero)!"
    echo "Skip database backup..."
    return 1
  fi

  if [ -z ${!DATABASE_HOST} ]; then
    echo "The length of variable: \$${DATABASE_HOST} is 0 (zero)!"
    echo "Skip database backup..."
    return 1
  fi

  if [ -z ${!DATABASE_PASSWORD} ]; then
    echo "The length of variable: \$${DATABASE_PASSWORD} is 0 (zero)!"
    echo "Skip database backup..."
    return 1
  fi

  if [ -z ${!DATABASE_NAME} ]; then
    echo "The length of variable: \$${DATABASE_NAME} is 0 (zero)!"
    echo "Skip database backup..."
    return 1
  fi

  if [ -z ${!DATABASE_USER} ]; then
    echo "The length of variable: \$${DATABASE_USER} is 0 (zero)!"
    echo "Skip database backup..."
    return 1
  fi

  echo -e "\nBacking up ${!DATABASE_NAME} ..."
  echo -e "This might also take some time!\n"

  pg_dump --dbname="postgresql://${!DATABASE_USER}:${!DATABASE_PASSWORD}@${!DATABASE_HOST}:${!DATABASE_PORT}/${!DATABASE_NAME}" | gzip -9 >${BACKUPS_DATABASE_DIR}/backup_db_${TOKEN_LOWERCASE}_${TIMESTAMP}.sql.gz

  return 0
}

###################################################################
#                        check_backups()                          #
###################################################################

# Does all the job..
#	- Checks if a any backups were taken the last X days from config. Number of backups taken from _BACKUPS_AMOUNT parametr.
#	- Older backup would be deleted
# Parameter:	$1 -> {WIKI, CLOUD, ...}
check_backups() {
  TOKEN_LOWERCASE=$(echo ${1} | tr '[:upper:]' '[:lower:]')
  BACKUPS_DIR_NAME="${1}_BACKUPS_DIR"
  BACKUPS_DIR="${!BACKUPS_DIR_NAME}/${TOKEN_LOWERCASE}"
  BACKUPS_AMOUNT="${1}_BACKUPS_AMOUNT"
  DATABASE_NAME="${1}_DATABASE_NAME"
  BACKUP_FILES=$(ls -1 ${BACKUPS_DIR} | grep -E \
    "^backup_${TOKEN_LOWERCASE}_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}.tar.gz" \
    2>/dev/null | sort -r)

  TODAY=$(date +%a)
  FILENUM=0
  FILENUM_DATABASE=0
  DELETED_SUM=0
  DELETED_DATABASE_SUM=0
  TO_REMOVE_BACKUP_DATE=$(date --date="${!BACKUPS_AMOUNT} days ago" "+%Y-%m-%d_%H-%M-%S")

  echo -e "\n##### $1\n"

  # Check previous backup files dates and drop it if backup date greather than amount of days stored in _BACKUPS_AMOUNT
  for file in ${BACKUP_FILES}; do
    BACKUP_TIME=${file:(-26):19}
    echo -e "\t${file}"
    ((FILENUM++))

    compare_dates ${BACKUP_TIME} ${TO_REMOVE_BACKUP_DATE}
    x=${?}
    if [ ${x} -le 1 ]; then
      echo -e "\t[rm ${BACKUPS_DIR}/${file}]"

      # Drop expired backups
      rm ${BACKUPS_DIR}/${file}

      ((DELETED_SUM++))
    fi
  done

  make_backup ${1}
  ((FILENUM++))

  # Then do the same for the database files
  if [ ! -z ${!DATABASE_NAME} ]; then
    BACKUPS_DATABASE_DIR="${!BACKUPS_DIR_NAME}/${TOKEN_LOWERCASE}/db"
    BACKUP_DATABASE_FILES=$(ls -1 ${BACKUPS_DATABASE_DIR} | grep -E \
      "^backup_db_${TOKEN_LOWERCASE}_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}.sql.gz" \
      2>/dev/null | sort -r)

    for bfile in ${BACKUP_DATABASE_FILES}; do
      BACKUP_TIME=${bfile:(-26):19}
      echo -e "\t${bfile}"
      ((FILENUM_DATABASE++))

      compare_dates ${BACKUP_TIME} ${TO_REMOVE_BACKUP_DATE}
      x=${?}
      if [ ${x} -le 1 ]; then
        echo -e "\t[rm ${BACKUPS_DATABASE_DIR}/${bfile}]"

        # Drop expired backups
        rm ${BACKUPS_DATABASE_DIR}/${bfile}

        ((DELETED_DATABASE_SUM++))
      fi
    done

    # Make backup of Database
    make_database_backup ${1}
    ((FILENUM_DATABASE++))
  fi

  if [ ${FILENUM} -eq 0 ]; then
    echo -e "\tNo backup files were found!"
  fi

  echo " "
  echo "===== REPORT ====="
  echo "${FILENUM} ${2} backup file(s) exist!"
  echo "${DELETED_SUM} ${2} backup file(s) were deleted!"
  echo "$((FILENUM - DELETED_SUM)) ${2} OLD backup file(s) currently exist!"
  echo "===== DATABASE ====="
  echo "${FILENUM_DATABASE} ${2} database backup file(s) exist!"
  echo "${DELETED_DATABASE_SUM} ${2} backup file(s) were deleted!"
  echo "$((FILENUM_DATABASE - DELETED_DATABASE_SUM)) ${2} OLD backup database file(s) currently exist!"
}

###################################################################
#                              main()                             #
###################################################################

# For every directory (to be backed up) configuration conducts a
# configuration check and calls check_backups function.
main() {
  for tok in ${TOKENS[@]}; do
    check_params ${tok}
    check_backups ${tok}
  done
}

main
