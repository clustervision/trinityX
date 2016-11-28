
Controller storage post-scripts engineering documentation
=========================================================

Overview
--------

The TrinityX installer contains several post-scripts that cover multiple ways of setting up of the shared storage between the controllers. Although split into multiple scripts, they behave as one single high-level block. This document covers the usage and configuration of all the HA storage post-scripts included in the installer.

The shared storage between the controllers has multiple roles:

======================= =================================== ======================= ======================= ===============
Configuration option    Description                         Default location        Passive controller      Nodes
======================= =================================== ======================= ======================= ===============
``STDCFG_TRIX_ROOT``    Root path of the TrinityX files     ``/trinity``            -                       -
-                       Local files                         ``/trinity/local``      RW                      -
``STDCFG_TRIX_IMAGES``  Compute node images                 ``/trinity/images``     RW                      -
``STDCFG_TRIX_SHARED``  TrinityX global shared files        ``/trinity/shared``     RW                      RO
``STDCFG_TRIX_HOME``    Home directories (if configured)    ``/trinity/home``       RW                      RW
======================= =================================== ======================= ======================= ===============

By default all of those directories exist under the same tree, and are exported from the active controller to the passive controller and the nodes. Their default locations are shown in the table above. Apart from the local files, all locations can be changed in the configuration file through the configuration options above.

The export of those directories is done via NFS from the active controller, which has RW access to the whole tree at any time. Because the active controller role can change when a failover occurs, both controllers must have a way of accessing that whole tree. The root of this tree, ``STDCFG_TRIX_ROOT``, is what is referred to as the shared storage.

There are multiple ways of creating and accessing the shared storage. The TrinityX installer supports a subset of them, as well as the possibility to leave part or the entirety of the configuration to the engineer.

The choice of the configuration, as well as providing additional variables when required, is done through the configuration files like all other post scripts.



Use cases
---------

The use cases supported by the post-scripts are:

- ``none``

    No configuration is done on the controllers. On both controllers the path to ``STDCFG_TRIX_ROOT`` is expected to exist and be accessible RW. No NFS export is set up. No configuration is done in the compute node images.

    Typical usage: external distributed filesystems (GPFS, Lustre, etc), exotic configurations that aren't covered by any other use case.

    Available in: HA, non-HA.


- ``export``

    No filesystem creation is done on the controllers. On the active controller the path to ``STDCFG_TRIX_ROOT`` is expected to exist and be accessible RW. The subfolders are exported via NFS from the active controller to the passive controller and the nodes.

    Typical usage: remote shared block devices (iSCSI), ZFS shared arrays.

    Available in: HA, non-HA.


- ``dev``

    A block device must exist on both controllers. At installation time it is partitioned and formatted, and at runtime it is mounted at ``STDCFG_TRIX_ROOT``, all on the active controller. The subfolders are exported via NFS from the active controller to the passive controller and the nodes.

    Typical usage: local shared block device (shared disk, JBOD with mdraid or LVM).

    Available in: HA, non-HA.


- ``drbd``

    Two block devices must exist, one on each controller. At installation time those block devices are set up as a DRBD replicated volume and formatted, and at runtime the DRBD volume is mounted at ``STDCFG_TRIX_ROOT`` on the active controller. The subfolders are exported via NFS from the active controller to the passive controller and the nodes.

    Typical usage: controllers without shared block device.

    Available in: HA only.



Failover and fencing
--------------------

In all cases but with an external distributed filesystems, the shared storage must be managed by a Pacemaker resource and the controllers must be able to fence each other, in order to guarantee that the backing filesystem will be accessed only by the active controller at any time. Fencing is hardware-dependent, and therefore is not managed by the filesystem post scripts. All fencing configuration must be done by the engineer.

For ``none`` and ``export``, all backing filesystem failover configuration must be done by the engineer.

For ``dev`` and ``drbd``, if the block devices are RAID arrays their creation must be done before the TrinityX installation, and the Pacemaker resources to assemble them on the active node must be configured by the engineer.

For ``export``, ``dev`` and ``drbd``, a Pacemaker resource to manage the NFS server will be installed. It will be colocated on the same controller as the floating IP resource. Note that in all cases where some Pacemaker resources are provided by the engineer, they most be ordered very carefully and the NFS resource must only run after all previous one (backend device, filesystem, etc) have completed.



Non-HA setups
-------------

All use cases outside of ``drbd`` are available for non-HA setups. The default when ``SHARED_FS_TYPE`` is not specified, is ``export``. For all supported cases, the same configuration options are available.



Creation configuration options
------------------------------

The configuration options that are accepted by the HA storage post-scripts are the following:


``SHARED_FS_TYPE``

    The top-level configuration. Its possible values are the `Use cases`_.


``SHARED_FS_DEVICE``

    For ``dev`` and ``drbd``, the name of the block device that is to be used. Note that the name must be identical on both controllers.


``SHARED_FS_CTRL1_IP``
``SHARED_FS_CTRL1_IP``

    For ``drbd`` only, the IPs to use for replication and synchronization. This allows the DRBD traffic to use a separate network, preferably a direct cable between the two controllers. If not set, the main ``STDCFG_CTRL1_IP`` and ``STDCFG_CTRL2_IP`` will be used.

.. warning:: Make sure that the interfaces set with those IPs are trusted interfaces in firewalld (i.e. wide open), or that at least port ``7789`` is open.


``SHARED_FS_DRBD_WAIT_FOR_SYNC``

    For ``drbd`` only: if set, wait for full synchronization of the secondary disk before continuing with the TrinityX setup. That will take a while.

``SHARED_FS_NO_FORMAT``

    For ``dev`` and ``drbd``, don't partition or format the new block device, assume that it is ready for use. For ``dev`` it will then behave in almost the same way as ``export``; the only difference being that for ``dev`` there will be a Pacemaker resource to mount the filesystem.

.. warning:: This will likely only work if the block device has been previously prepared by this post-script, i.e. if you're reinstalling the primary controller and don't want to lose data.


``SHARED_FS_FORMAT_OPTIONS``

    For ``dev`` and ``drbd``, additional options to pass to the format command. This is especially useful when the backing device requires additional parameters for optimal performance: RAID arrays, SSD, etc.




NFS exports
-----------

In most cases, parts or the whole of the TrinityX root tree will be exported via NFS to the secondary controller and the compute nodes. Except when using the ``none`` use case (in which all data is supposed to be available automagically on both controllers), at least the export of the local folder to the secondary controller is required.

All exports (and the matching mounts on the secondary controller and the compute nodes) are controlled by individual configuration flags, that enable or disable them. Using those flags together with non-standard paths for some of the subfolders of the TrinityX tree, allows for mixed models where part of the tree may be shared over NFS, while other parts can be on an external distributed FS, for example.

In non-HA setups, only the homes are exported to the compute nodes by default.

The floowing flags are currently supported:

======================= =================== =================== =================== =================== ===================
Flag name               Default ``none``    Default ``export``  Default ``dev``     Default ``drbd``    Default non-HA
======================= =================== =================== =================== =================== ===================
``NFS_EXPORT_LOCAL``    0                   1                   1                   1                   0
``NFS_EXPORT_IMAGES``   0                   1                   1                   1                   0
``NFS_EXPORT_SHARED``   0                   1                   1                   1                   1
``NFS_EXPORT_HOME``     0                   1                   1                   1                   1
======================= =================== =================== =================== =================== ===================

.. note:: Refer to the `Overview`_ for the scope of the export of each of those directories.

.. note:: The installer will set those flags to the values above based on the shared FS use case selected in the configuration file. They only need to be redefined when the required setup differs from the defaults.

.. warning:: ``NFS_EXPORT_LOCAL`` is expected to be enabled for installation of the secondary controller. If disabled, the directory must be available locally on the secondary controller before the TrinityX setup starts.




Examples
--------

Home on an external distributed FS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The most common modification will probably to have the users' home directories on an external distributed FS (Lustre / GPFS / BeeGFS), while everything else is exported from the controllers via NFS.

Let's assume that we have an external JBOD with a RAID array on it. The procedure would be:

1. *PRIMARY INSTALL*: assemble and configure the array;

2. *PRIMARY AND SECONDARY*: ``mkdir -p /trinity/home``, and mount the distributed FS in ``/trinity/home`` (or any other path if you diverge from the standard tree);

.. warning:: Remember that all failover configuration for the RAID array, and the mounts of the distributed FS, need to be done by the engineer!

3. *PRIMARY AND SECONDARY*: set up the configuration file. In that case it would look like this::

    # no change to the default paths
    
    SHARED_FS_TYPE=dev
    SHARED_FS_DEVICE=/dev/<path to RAID block device>
    SHARED_FS_FORMAT_OPTIONS=<as required by the array>
    
    # only one change to the default exports, the rest is fine
    NFS_EXPORT_HOME=0

.. note:: Remember that the same configuration file must be used for both primary and secondary installations. So if the configuration file is modified on the primary controller before installation, make sure to copy it over to the secondary and use it for the secondary install.

4. *COMPUTE IMAGES*: set up the mount of the distributed FS to ``/trinity/home``.

