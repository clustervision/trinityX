#!/bin/bash

v4dec() {
        for i; do
                echo $i | {
                        IFS=./
                        read a b c d e
                        test -z "$e" && e=32
                        echo -n "$((a<<24|b<<16|c<<8|d)) $((-1<<(32-e))) "
                }
        done
}

v4test() {
        v4dec $1 $2 | {
                read addr1 mask1 addr2 mask2
                if (( (addr1&mask2) == (addr2&mask2) && mask1 >= mask2 )); then
                        echo "$1 is in network $2"
                else
                        echo "$1 is not in network $2"
			exit 1
                fi
        }
}

IP=$1
NETWORK=$2
if [ "$(echo $IP $NETWORK | grep ':')" ]; then
	echo "ipv6 not supported"
	exit
fi
v4test $IP $NETWORK
