#!/bin/bash
set -e

declare -A tuned
declare -A outoftune

cmd_opts=""

if [ ! -z $PG_VERSION ]
then
  cmd_opts+=" -v "$PG_VERSION
else
  cmd_opts+=" -v "$PG_MAJOR
fi

if [ ! -z $DB_TYPE ]
then
  cmd_opts+=" -t "$DB_TYPE
fi

if [ ! -z $TOTAL_MEM ]
then
  cmd_opts+=" -m "$TOTAL_MEM
fi

if [ ! -z $CPU_COUNT ]
then
  cmd_opts+=" -u "$CPU_COUNT
fi

if [ ! -z $MAX_CONN ]
then
  cmd_opts+=" -c "$MAX_CONN
fi

if [ ! -z $STGE_TYPE ]
then
  cmd_opts+=" -s "$STGE_TYPE
fi

# Determine the correct postgresql.conf path
PG_CONF_PATH="/var/lib/postgresql/data/postgresql.conf"
if [ ! -f "$PG_CONF_PATH" ]; then
  PG_CONF_PATH="/var/lib/postgresql/postgresql.conf"
fi

# Safety check to ensure the file exists at either location
if [ ! -f "$PG_CONF_PATH" ]; then
  echo "[pgtuned.sh] Error: postgresql.conf not found at either location!"
  exit 1
fi

cd /tmp

echo "[pgtuned.sh] executing \"pgtune.sh$cmd_opts\""
bash pgtune.sh $cmd_opts > tuned.conf

echo "[pgtuned.sh] importing additional parameters from existing postgresql.conf at $PG_CONF_PATH"
while IFS= read -r line; do
  if [[ $line =~ ^[[:blank:]]*([^\#]*)\ =\ ([^[[:blank:]]\#\'\"]*|\'.*\'|\".*\")[[:blank:]]*(\#?.*)$ ]]; then
    key=${BASH_REMATCH[1]}
    value=${BASH_REMATCH[2]}
    outoftune[$key]=$value
  fi
done < "$PG_CONF_PATH"

while IFS= read -r line; do
  if [[ $line =~ ^([^\#]*)\ =\ (.*)$ ]]; then
    key=${BASH_REMATCH[1]}
    value=${BASH_REMATCH[2]}
    tuned[$key]=$value
  fi
done < tuned.conf

comment_line=0
for key in "${!outoftune[@]}"
do
  if [ ! "${tuned[$key]}" ]; then
    if [ "$comment_line" -eq 0 ]; then
      echo >> tuned.conf 
      echo "# Configuration parameters harvested from original docker postgres image postgresql.conf" >> tuned.conf
      echo >> tuned.conf
      comment_line=1
    fi
    echo $key" = "${outoftune[$key]} >> tuned.conf
  fi
done

cp /tmp/tuned.conf "$PG_CONF_PATH"
echo "[pgtuned.sh] postgresql.conf has been successfully pgtuned"