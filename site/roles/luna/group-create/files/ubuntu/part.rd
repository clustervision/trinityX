ls "$rootmnt" || mkdir "$rootmnt"
mount -t tmpfs tmpfs "$rootmnt"
