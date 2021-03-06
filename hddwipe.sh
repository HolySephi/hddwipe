#!/bin/bash

#########################################################################
#               hddwipe - wipe/erase hard drives safely                 #
#                                                                       #
#   Copyright (c) 2015 - Florian Wicke - https://github.com/HolySephi   #
#                                                                       #
# This program is free software: you can redistribute it and/or modify  #
# it under the terms of the GNU General Public License as published by  #
# the Free Software Foundation, either version 2 of the License, or     #
# (at your option) any later version.                                   #
#                                                                       #
# This program is distributed in the hope that it will be useful,       #
# but WITHOUT ANY WARRANTY; without even the implied warranty of        #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
# GNU General Public License for more details.                          #
#                                                                       #
# You should have received a copy of the GNU General Public License     #
# along with this program.  If not, see <http://www.gnu.org/licenses/>. #
#########################################################################

######
# wipe hdd safely

# example usage:
# ./hddwipe.sh /dev/sda

display_usage() {
  if [ -n "$1" ]; then
    echo "$1" >&2
    echo "" >&2
  fi
  echo "usage: $0 [-c <count for random wipes>] <device>" >&2
  echo "" >&2
}

while getopts ":c:" opt; do
  case $opt in
    c)
      if [[ "$OPTARG" =~ ^[0-9]*$ ]]; then
        RandomWipeCount="$OPTARG"
      else
        display_usage "ERROR: Argument to -$opt is no number: $OPTARG"
        exit 1
      fi
      ;;
    \?)
      display_usage "ERROR: Invalid option -$OPTARG"
      exit 1
      ;;
    :)
      display_usage "ERROR: Option -$OPTARG requires an argument"
      exit 1
      ;;
  esac
done

if [ -z "${@: -1}" ]; then
  display_usage "please give device target as parameter"
  exit 1
fi

Device="${@: -1}"
DeviceSize="$(sfdisk -s $Device)"

if [ -z "$RandomWipeCount" ]; then
  RandomWipeCount=5
fi
WipeSteps="$[$RandomWipeCount + 2]"

pvArgs="-brtpe -s ${DeviceSize}k -i1 -N ${Device}"
ddArgs="bs=4M conv=fdatasync"

startWipe() {
  WipeSource="$1"
  WipeDestination="$2"
  
  TempFile="$(mktemp)"
  echo -n "  creating tempfile for wipe..."
  dd if="$WipeSource" of="$TempFile" bs=4M count=1 >> /dev/null 2>&1
  echo "done"
  echo "  wiping.."
  until false; do
    cat "$TempFile"; EXITCODE=$?
    if [ $EXITCODE -ne 0 ]; then
      break
    fi
  done | pv $pvArgs | dd of="$WipeDestination" $ddArgs >>/dev/null 2>&1
  echo "done"
  rm -f "$TempFile"
  echo ""
}

# step 1 - zeros
echo "Step 1/$WipeSteps - zeros"
startWipe "/dev/zero" "$Device"

for i in $(seq $RandomWipeCount); do
  ActualStep="$[$i + 1]"
  echo "Step $ActualStep/$WipeSteps - random"
  startWipe "/dev/urandom" "$Device"
done

# step 3 - zeros
echo "Step $WipeSteps/$WipeSteps - zeros"
startWipe "/dev/zero" "$Device"

