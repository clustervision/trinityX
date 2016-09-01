#!/bin/bash

# Setup for the additional package list

systemctl enable haveged
flag_is_unset POST_CHROOT && systemctl restart haveged || true

