#!/bin/bash

# Setup for the additional package list

source "$POST_CONFIG"

systemctl enable haveged
flag_is_unset CHROOT_INSTALL && systemctl restart haveged || true

