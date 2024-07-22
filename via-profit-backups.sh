#!/bin/bash

#+-----------------------------------------------------------------------+
#|              Copyright (C) 2024 LLC Via-profit                        |
#!              website: https://via-pforit.ru                           |
#+-----------------------------------------------------------------------+
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
DAYS=(Mon Tue Wed Thu Fri Sat Sun)

###################################################################
#                    CONFIGURATION SECTION                        #
###################################################################

# The configuration section is the only section you should modify,
# unless you really(!) know what you are doing!!!

# Make sure to always comply with the name format of the variables
# below. As you may have noticed, all variables related to each
# other begin with the same token (i.e. WIKI, CLOUD, ...).

# To add any additional directories to be backed up, you should only
# add three (3) new lines and modify ${TOKENS} variable. See the
# examples below to get a better understanding.

# Example of ${TOKENS} variable.
TOKENS="TLKTRANSFER" # For any additional entry add the appropriate
# <token-uppercase> separating it with a space
# character from existing tokens.

# Template - The three lines that should be added for every new directory addition.
# <token-uppercase>_BACKUPS_DIR="/path/to/dir"     # No '/' at the end of the path!
# <token-uppercase>_DIR="/path/to/another-dir"     # No '/' at the end of the path!
# <token-uppercase>_BACKUP_DAY="<weekday-3-letters>"

TLKTRANSFER_BACKUPS_DIR="/home/bablo/backup"   # Where backup files will be saved.
TLKTRANSFER_DIR="/home/bablo/sample/graphql-server"           # The directory that should be backed up.
TLKTRANSFER_DATABASE_USER="tlktransfer"        # The databaase user
TLKTRANSFER_DATABASE_NAME="tlktransfer_server" # The database name
TLKTRANSFER_DATABASE_PASSWORD="admin"          # The database password
TLKTRANSFER_BACKUPS_AMOUNT=7                   # The amount of stored backups
# TLKTRANSFER_BACKUPS_EXCLUDE_FILE="${TLKTRANSFER_DIR}/.backup.exclude"   # Backup exclude file path, similar as gitignore

# If disk space useage more than 95% then skip backup
BACKUP_DISK_LIMIT=95

# If load average more than 5 then skip backup
BACKUP_LA_LIMIT=5

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
  BACKUPS_DIR="${1}_BACKUPS_DIR"
  DIR="${1}_DIR"
  BACKUPS_AMOUNT="${1}_BACKUPS_AMOUNT"

  if [ ! -d ${!BACKUPS_DIR} ]; then
    echo "Creating...${!BACKUPS_DIR}"
    mkdir -p ${!BACKUPS_DIR}
    if [ ${?} -ne 0 ]; then
      echo "Error creating ${!BACKUPS_DIR}!"
      echo "Script will now exit..."
      exit 1
    fi
  fi

  if [ ! -d ${!DIR} ]; then
    echo "${!DIR}: No such directory!"
    echo "Script will now exit..."
    exit 2
  fi

  if [ "${!BACKUPS_DIR}" == "${!DIR}" ]; then
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
  disk_usage=$(df ${!BACKUPS_DIR} | tail -n1 | tr ' ' '\n' | grep % | cut -f 1 -d %)
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
  BACKUPS_DIR="${1}_BACKUPS_DIR"
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

  TOKEN_LOWERCASE=$(echo ${1} | tr '[:upper:]' '[:lower:]')
  mv ${TEMPFILE} ${!BACKUPS_DIR}/backup_${TOKEN_LOWERCASE}_${TIMESTAMP}.tar.gz
}

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
#                        check_backups()                          #
###################################################################

# Does all the job.
# 	- Checks if a backup was taken this week.
#	- Checks if a any backups were taken the last 6 weeks.
#	- If today is "<token-uppercase>_BACKUP_DAY" a backup is taken.
#	- If no backups were taken this week or the preview one,
#	  a backup is taken.
#	- If the total number of backups is more than 5 (>=6),
#	  excess backups which are older than 5 weeks are deleted.
#	  (counting current week in those 5)
# Parameter:	$1 -> {WIKI, CLOUD, ...}
check_backups() {
  TOKEN_LOWERCASE=$(echo ${1} | tr '[:upper:]' '[:lower:]')
  BACKUPS_DIR="${1}_BACKUPS_DIR"
  BACKUPS_AMOUNT="${1}_BACKUPS_AMOUNT"
  BACKUP_FILES=$(ls -1 ${!BACKUPS_DIR} | grep -E \
    "^backup_${TOKEN_LOWERCASE}_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}.tar.gz" \
    2>/dev/null | sort -r)

  TODAY=$(date +%a)
  FILENUM_SUM=0
  DELETED_SUM=0
  TO_REMOVE_BACKUP_DATE=$(date --date="${!BACKUPS_AMOUNT} days ago" +"%Y-%m-%d")

  echo -e "\n##### $1\n"

  for file in ${BACKUP_FILES}; do
    BACKUP_TIME=${file:(-26):19}
    echo $BACKUP_TIME

    compare_dates ${BACKUP_TIME} ${SUN}
    x=${?}
    compare_dates ${BACKUP_TIME} ${MON}
    y=${?}
    if [ ${x} -le 1 ] && [ ${y} -eq 2 -o ${y} -eq 0 ]; then
      echo -e "\t${file}"
      ((FILENUM++))

      if [ ${week} -eq 6 ] && [ $((FILENUM_SUM + FILENUM)) -gt 5 ]; then
        echo -e "\t[rm ${!BACKUPS_DIR}/${file}]"
        rm ${!BACKUPS_DIR}/${file}
        ((DELETED_SUM++))
      fi
    fi
  done

  make_backup ${1}
  ((FILENUM++))

  ((FILENUM_SUM += FILENUM))

  if [ ${FILENUM} -eq 0 ]; then
    echo -e "\tNo backup files were found!"
  fi

  # MON=$(date "+%Y-%m-%d_%H-%M-%S" --date="${MON::10} -1 week")
  # SUN=$(date "+%Y-%m-%d_%H-%M-%S" --date="${SUN::10} -1 week")

  echo " "
  echo "===== REPORT ====="
  echo "${FILENUM_SUM} ${2} backup file(s) exist!"
  echo "${DELETED_SUM} ${2} backup file(s) were deleted!"
  echo "$((FILENUM_SUM - DELETED_SUM)) ${2} OLD backup file(s) currently exist!"
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
