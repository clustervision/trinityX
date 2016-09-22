
Hints and tips for a Luna installation
======================================


Generating pdsh group from Luna groups
--------------------------------------

`pdsh <https://github.com/grondo/pdsh>`_ is a popular parallel shell tool, allowing to run the same command or set of commands on multiple machines at the same time. It is installed by default on Trinity X systems, and the sysadmins may chose to use it over other alternatives.

As of Trinity X release 1 there is no integration of Luna with ``pdsh``, and the configuration files required by ``pdsh`` have to be created by the sysadmins. Although it's possible to write a script around the output of ``luna node list``, the Trinity X source tree comes with a pre-written tool: ``scripts/luna2pdsh.sh``.

A typical output would be similar to this::

    [root@controller trinityX]# ./scripts/luna2pdsh.sh 
    
    Group: compute
    node001
    node002
    
    Group: compute2
    node003

It will create group files in ``/etc/dsh/groups``, that can be used with the ``dshgroup`` module of ``pdsh``::

    # pdsh -g compute hostname
    node001
    node002

Note that the files include all node names known to Luna, including those that haven't been discovered yet (i.e., Luna doesn't know their MAC addresses, and no entry will exist in the DNS records). If you have added nodes recently, boot them up at least once to make sure that Luna discovers them, then run ``luna cluster makedns`` followed by the ``luna2pdsh.sh`` script again.


Custom kernel version and parameters
------------------------------------



Compute node NIC naming
-----------------------

By default CentOS 7 uses new-style naming of network interfaces, based on the NIC type, their location in the machine, etc (eg. enp0s29u1u2). The name is decided either by the udev naming rules, or by the ``biosdevname`` module. The exact naming rules are documented in the SystemD / udev sources, and in the RHEL 7 documentation:

`Predictable network interface device names <https://github.com/systemd/systemd/blob/master/src/udev/udev-builtin-net_id.c>`_

`Consistent Network Device Naming <https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/ch-Consistent_Network_Device_Naming.html>`_

In a few cases this may be more of a hindrance than anything. If you have good reasons for wanting the old naming scheme back (which comes with its own set of issues), you can specify boot kernel parameters in the image to revert to the old scheme. Assuming that the image was added to Luna as ``compute``, you can run::

    luna osimage change -n compute --kernopts "net.ifnames=0 biosdevname=0"
    luna osimage pack -n compute -b

The first line will overwrite the current kernel options, so make sure to add any other option to the string. For further details, see `Custom kernel version and parameters`_.

