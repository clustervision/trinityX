
HA storage post-scripts engineering documentation
=================================================

Overview
--------

The TrinityX installer contains several post-scripts that cover multiple ways of setting up of the shared storage between the controllers. Although split into multiple scripts, they behave as one single high-level block. This document covers the usage and configuration of all the HA storage post-scripts included in the installer.

The shared storage between the controllers has multiple roles:

======================= =================================== ======================= ======================= ===============
Configuration option    Description                         Default location        Passive controller      Nodes
======================= =================================== ======================= ======================= ===============
``STDCFG_TRIX_ROOT``    Root path of the TrinityX files     ``/trinity``            -                       -
``STDCFG_TRIX_IMAGES``  Compute node images                 ``/trinity/images``     RW                      -
``STDCFG_TRIX_LOCAL``   Local files                         ``/trinity/local``      RW                      -
``STDCFG_TRIX_SHARED``  TrinityX global shared files        ``/trinity/shared``     RW                      RO
``STDCFG_TRIX_HOME``    Home directories (if configured)    ``/trinity/home``       RW                      RW
======================= =================================== ======================= ======================= ===============

By default all of those directories exist under the same tree, and are exported from the active controller to the passive controller and the nodes. The export of those directories is done via NFS from the active controller, which has RW access to the whole tree at any time. Because the active controller role can change when a failover occurs, both controllers must have a way of accessing that whole tree. The root of this tree, ``STDCFG_TRIX_ROOT``, is what is referred to as the shared storage.

There are multiple ways of creating and accessing the shared storage. The TrinityX installer supports a subset of them, as well as the possibility to leave part or the entirety of the configuration to the engineer.

The choice of the configuration, as well as providing additional variables when required, is done through the configuration files like all other post scripts.



Note for non-HA setups
----------------------

Non-HA setups are not dealt with by those post-script. They will simply exit without doing anything if run for a non-HA configuration. In effect, the non-HA setup of the TrinityX root is similar to the ``export`` HA option.



Use cases
---------

The use cases supported by the post-scripts are:

- ``none``

    No configuration is done on the controllers. On both controllers the path to ``STDCFG_TRIX_ROOT`` is expected to exist and be accessible RW. No configuration is done in the compute node images.

    Typical usage: external distributed filesystems (GPFS, Lustre, etc), exotic configuration that isn't covered by any other use case.


- ``export``

    No filesystem creation is done on the controllers. On the active controller the path to ``STDCFG_TRIX_ROOT`` is expected to exist and be accessible RW. The subfolders are exported via NFS from the active controller to the passive controller and the nodes.

    Typical usage: remote shared block devices (iSCSI), ZFS shared arrays.


- ``dev``

    A block device must exist on both controllers. At installation time it is partitioned and formatted, and at runtime it is mounted at ``STDCFG_TRIX_ROOT``, all on the active controller. The subfolders are exported via NFS from the active controller to the passive controller and the nodes.

    Typical usage: local shared block device (shared disk, JBOD with mdraid or LVM).


- ``drbd``

    Two block devices must exist, one on each controller. At installation time those block devices are set up as a DRBD replicated volume and formatted, and at runtime the DRBD volume is mounted at ``STDCFG_TRIX_ROOT`` on the active controller. The subfolders are exported via NFS from the active controller to the passive controller and the nodes.

    Typical usage: controllers without shared block device.



Failover and fencing
--------------------

In all cases but with an external distributed filesystems, the shared storage must be managed by a Pacemaker resource and the controllers must be able to fence each other, in order to guarantee that the backing filesystem will be accessed only by the active controller at any time. Fencing is hardware-dependent, and therefore is not managed by the filesystem post scripts. All fencing configuration must be done by the engineer.

For ``none`` and ``export``, all backing filesystem failover configuration must be done by the engineer.

For ``dev`` and ``drbd``, if the block devices are RAID arrays their creation must be done before the TrinityX installation, and the Pacemaker resources to assemble them on the active node must be configured by the engineer.

For ``export``, ``dev`` and ``drbd``, a Pacemaker resource to manage the NFS server will be installed. It will be colocated on the same controller as the floating IP resource. Note that in all cases where some Pacemaker resources are provided by the engineer, they most be ordered very carefully and the NFS resource must only run after all previous one (backend device, filesystem, etc) have completed.



Creation configuration options
------------------------------

The configuration options that are accepted by the HA storage post-scripts are the following:


``SHARED_FS_TYPE``

    The top-level configuration. Its possible values are the `Use cases`_.


``SHARED_FS_DEV_BACKEND``

    For ``dev`` and ``drbd``, the name of the block device that is to be used. Note that the name must be identical on both controllers.


``SHARED_FS_NO_FORMAT``

    For ``dev`` and ``drbd``, don't partition or format the new block device, assume that it is ready for use. For ``dev`` it will then behave in almost the same way as ``export``; the only difference being that for ``dev`` there will be a Pacemaker resource to mount the filesystem.

.. warning:: This will likely only work if the block device has been previously prepared by this post-script, i.e. if you're reinstalling the primary controller and don't want to lose data.


``SHARED_FS_FORMAT_OPTIONS``

    For ``dev`` and ``drbd``, additional options to pass to the format command. This is especially useful when the backing device requires additional parameters for optimal performance: RAID arrays, SSD, etc.

