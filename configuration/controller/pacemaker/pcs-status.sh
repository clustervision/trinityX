function pcs() {
    if [ "$1" = "status" -a $# -eq 1 ]; then
        /usr/sbin/pcs status | sed \
            -e 's/Stopped/\x1b[1;31mStopped\x1b[0m/g' \
            -e 's/Offline/\x1b[1;31mOffline\x1b[0m/g' \
            -e 's/FAILED/\x1b[1;31mFAILED\x1b[0m/g' \
            -e 's/Started/\x1b[1;32mStarted\x1b[0m/g' \
            -e 's/Online/\x1b[1;32mOnline\x1b[0m/g' \
            -e 's/Masters/\x1b[1;32mMasters\x1b[0m/g' \
            -e 's/Slaves/\x1b[1;36mSlaves\x1b[0m/g' \
            -e 's/standby/\x1b[1;34mstandby\x1b[0m/g' \
            -e 's/OFFLINE/\x1b[1;31;5mOFFLINE\x1b[0m/g' \
            -e 's/UNCLEAN/\x1b[1;31;5mUNCLEAN\x1b[0m/g' \
            -e 's/unmanaged/\x1b[1;34munmanaged\x1b[0m/g' \
            -e 's/Failed Actions/\x1b[1;31;5mFailed Actions\x1b[0m/g' 
    else
        /usr/sbin/pcs $@
    fi
   
}
