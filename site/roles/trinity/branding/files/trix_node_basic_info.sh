#!/bin/bash
MEM=$(cat /proc/meminfo  | awk 'NR==1{m=$2/2^20; print m == int(m)? int(m) : int(m+1)}')

echo -n "MEM=${MEM}G"

CPU=$(cat /proc/cpuinfo | awk '/model name/{for (i=4; i <= NF-1; i++) printf "%s ", $i; print $NF; exit }')
echo -n "; CPU=${CPU}"

CORES=$(cat /proc/cpuinfo | awk '/model name/{i++}END{print i}')
echo -n "; cores=${CORES}"

HT="unkn"
if hash lscpu 2> /dev/null; then
    HT=$(lscpu | awk '/Thread\(s\) per core:/{print ($NF>1) ? "yes" : "no"}')
fi
echo -n "; HT=${HT}"

TURBO="unkn"
if hash cpupower 2> /dev/null; then
    TURBO=$(
        cpupower frequency-info \
        | awk '
            /boost state support:/{i=1}
            i{if ($1=="Active:"){i=0; print $NF}}
        '
    )
fi
echo -n "; Turbo=${TURBO}"

if [ -f /root/osimage ]; then
    IMAGE=$(cat /root/osimage)
    echo -n "; osimage=${IMAGE}"
fi

echo

