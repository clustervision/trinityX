
.. vim: si:et:ts=4:sw=4:tw=80

:Name:          TrinityX local repository
:Post script:   local-repo.sh
:Priority:      optional


TrinityX local repository
=========================

During the TrinityX controller installation, the optional ``local-repo.sh``
script can create a local RPM repository to install custom-built packages or to
work around the lack of connectivity.

It does this by copying the contents of the ``packages`` directory (which
contains this file) as-is. Therefore the directory must contain a ready-to-use
repository in its top level. When preparing the installation media for TrinityX,
don't forget to run a command like this one::

    createrepo -v --update --compress-type bz2 /path/to/packages

The internal layout of the directory doesn't matter, as long as the repository
was created in its top level.

Currently, the path of the ``packages`` directory is hardcoded as being at the
same level as the one containing the ``local-repo.sh`` script, so one level
above the script itself::

    [root@domina controller-post]# ls local-repo.sh 
    local-repo.sh
    
    [root@domina controller-post]# pwd
    /root/trinityX/controller-post
    
    [root@domina controller-post]# readlink -e ../packages
    /root/trinityX/packages

As long as the tree layout isn't modified and that the repository is created in
the existing ``packages`` directory, it will work just fine.


Getting all the packages
------------------------

In case of a disconnected install, this repository must contain everything that
will be needed to install all packages needed by all post scripts, that aren't
in the base minimal install.

Getting the actual list of packages can be rather complicated. Probably the
easiest way to do it is with virtual machines:


1. install a minimal CentOS VM

2. configure yum to keep the package cache::

    sed -i 's/\(^keepcache\).*/\1=1/g' /etc/yum.conf

3. take a snapshot of the VM

4. ``yum -y install git`` and ``git pull`` the TrinityX repository

5. configure the post scripts as needed for the next deployment

6. run all the configuration scripts. This will download all required packages
   and their dependencies that are not already installed.

7. copy all the downloaded packages to the ``packages`` directory on the
   installation media::

    mkdir -p /path/to/packages/x86_64
    
    find /var/cache/yum -iname \*.rpm | \
        xargs -I '{}' cp -v '{}' /path/to/packages/x86_64

8. create the repository (see above for the command)


For any other deployment, or when doing changes to the list of post scripts,
restore the VM snapshot (or create another VM from it) and start again at point
number 4.

Although it may seem like a lot of work, you get to do a test of your
installation procedure in the process. And as you would have done that test
anyway (wouldn't you?), getting the packages is basically free.

