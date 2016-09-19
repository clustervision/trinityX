
Hints and tips for a Luna installation
======================================



Custom kernel version and parameters
------------------------------------



Compute node NIC naming
-----------------------

By default CentOS 7 uses new-style naming of network interfaces, based on the NIC type, their location in the machine, etc (eg. enp0s29u1u2). The name is decided either by the udev naming rules, or by the ``biosdevname`` module. The exact naming rules are documented in the SystemD / udev sources, and in the RHEL 7 documentation:

`Predictable network interface device names <https://github.com/systemd/systemd/blob/master/src/udev/udev-builtin-net_id.c>`

`Consistent Network Device Naming <https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/ch-Consistent_Network_Device_Naming.html>`

In a few cases this may be more of a hindrance than anything. If you have good reasons for wanting the old naming scheme back (which comes with its own set of issues), you can specify boot kernel parameters in the image to revert to the old scheme. Assuming that the image was added to Luna as ``compute``, you can run::

    luna osimage change -n compute --kernopts "net.ifnames=0 biosdevname=0"
    luna osimage pack -n compute -b

The first line will overwrite the current kernel options, so make sure to add any other option to the string. For further details, see `Custom kernel version and parameters`_.

