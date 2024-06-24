#!/trinity/local/python/bin/python3

import os
import sys
import hostlist

def main(argv):
    rawhosts=None
    if (len(argv) == 0):
        sys.exit(1)
    while len(argv)>0:
        item = argv.pop(0)
        if not rawhosts:
            rawhosts=item
        else:
            rawhosts+=','+item
    hosts = hostlist.expand_hostlist(rawhosts)
    if not hosts:
        sys.exit(1)
    for host in hosts:
        print(host)

main(sys.argv[1:])
