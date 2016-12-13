
Controller storage post-scripts documentation
=============================================

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
``STDCFG_TRIX_HOME``    Home directories                    ``/trinity/home``       RW                      RW
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
``SHARED_FS_CTRL2_IP``

    For ``drbd`` only, the IPs to use for replication and synchronization. This allows the DRBD traffic to use a separate network, preferably a direct cable between the two controllers. If not set, the main ``STDCFG_CTRL1_IP`` and ``STDCFG_CTRL2_IP`` will be used.

.. warning:: Make sure that the interfaces set with those IPs are trusted interfaces in firewalld (i.e. wide open), or that at least port ``7789`` is open.


``SHARED_FS_DRBD_WAIT_FOR_SYNC``

    For ``drbd`` only: if set, wait for full synchronization of the secondary disk before continuing with the TrinityX setup. That will take some time, but is enabled by default and it recommended.


``SHARED_FS_NO_FORMAT``

    For ``dev`` and ``drbd``, don't partition or format the new block device, assume that it is ready for use. For ``dev`` it will then behave in almost the same way as ``export``; the only difference being that for ``dev`` there will be a Pacemaker resource to mount the filesystem.

.. warning:: This will likely only work if the block device has been previously prepared by this post-script, i.e. if you're reinstalling the primary controller and don't want to lose data.


``SHARED_FS_FORMAT_OPTIONS``

    For ``dev`` and ``drbd``, additional options to pass to the format command. This is especially useful when the backing device requires additional parameters for optimal performance: RAID arrays, SSD, etc.




NFS exports
-----------

In most cases, parts or the whole of the TrinityX root tree will be exported via NFS to the secondary controller and the compute nodes. Except when using the ``none`` use case (in which all data is supposed to be available automagically on both controllers), at least the export of the local folder to the secondary controller is required.

All exports (and the matching mounts on the secondary controller and the compute nodes) are controlled by individual configuration flags, that enable or disable them. Using those flags together with non-standard paths for some of the subfolders of the TrinityX tree, allows for mixed models where part of the tree may be shared over NFS, while other parts can be on an external distributed FS, for example.

For non-HA setups, the flags for ``NFS_EXPORT_SHARED`` and ``NFS_EXPORT_HOME`` are used in the same way as for an HA setup. Both ``NFS_EXPORT_LOCAL`` and ``NFS_EXPORT_IMAGES`` are masked and reset to ``0``, as both of those exports exist for data shared between controllers in HA setups only.

The floowing flags are currently supported:

======================= =================== =================== =================== =================== ===================
Flag name               ``none``            Default ``export``  Default ``dev``     Default ``drbd``    Non-HA mask
======================= =================== =================== =================== =================== ===================
``NFS_EXPORT_LOCAL``    0                   1                   1                   1                   0
``NFS_EXPORT_IMAGES``   0                   1                   1                   1                   0
``NFS_EXPORT_SHARED``   0                   1                   1                   1                   -
``NFS_EXPORT_HOME``     0                   1                   1                   1                   -
======================= =================== =================== =================== =================== ===================

.. note:: Refer to the `Overview`_ for the scope of the export of each of those directories.

.. note:: The installer will set those flags to the values above based on the shared FS use case selected in the configuration file. They only need to be redefined when the required setup differs from the defaults.

.. note:: The ``none`` use case skips the NFS server setup entirely. The ``NFS_EXPORT_*`` variables have no effect, and will all be reset to ``0``.

.. warning:: ``NFS_EXPORT_LOCAL`` is expected to be enabled for installation of the secondary controller. If disabled, the directory must be available locally on the secondary controller before the TrinityX secondary setup starts.


Additional configuration options for the NFS server are:

``NFS_RPCCOUNT``

    Number of NFS server threads to start. Default is 8 if unset. The best number depends on the amount of nodes and traffic.

``NFS_ENABLE_RDMA``

    Make the NFS server listen to the nfsrdma port (20049) for NFS-over-RDMA. This does not remove the ability to use the regular TCP proto, and is safe to enable on RDMA-supporting hardware.

.. note:: To make use of that feature, you need hardware that support RDMA in a way or another: iWARP, InfiniBand, RoCE for example. It will not work on regular Ethernet cards without HW support.

.. note:: Enabling this feature will automatically configure the compute images to use RDMA instead of TCP. This can be changed in the images by setting ``Proto=tcp`` in ``/etc/nfsmount.conf``.

.. warning:: This applies to the controllers too. As the secondary installer will try to fetch the required information from the primary via NFS, NFS must be working over RDMA if that option is selected. This implies that all drivers and support software must be installed on the systems before beginning the TrinityX configuration.



Examples
--------

Home on an external distributed FS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The most common modification will probably to have the users' home directories on an external distributed FS (Lustre / GPFS / BeeGFS), while everything else is exported from the controllers via NFS.

Let's assume that this is an HA setup, and we have an external JBOD for all the controllers' shared data (everything but the homes). The configuration file would include::

    # Change the default path of the homes. That's required because:
    #   - /trinity will be the mount point of the RAID array
    #   - the RAID array will be managed by Pacemaker
    #   - having the distributed FS mounted in a subdir of the RAID array would
    #     force it to be managed by Pacemaker too
    # And well, we don't want that. It's independant from HA. So:

    STDCFG_TRIX_HOME=/my/new/path/outside/slash/trinity
    
    SHARED_FS_TYPE=dev
    SHARED_FS_DEVICE=/dev/<path to RAID block device>
    SHARED_FS_FORMAT_OPTIONS=<as required by the array>
    
    # only one change to the default exports, the rest is fine
    NFS_EXPORT_HOME=0

.. note:: Remember that the same configuration file must be used for both primary and secondary installations. So if the configuration file is modified on the primary controller before installation, make sure to copy it over to the secondary and use it for the secondary install.


The installation procedures would be as follows:


**PRIMARY INSTALLATION**

#. Install CentOS 7 Minimal, the networking drivers (especially if using RDMA) and the distributed FS drivers.

#. Set up the mount of the distributed FS to the path that you specified in ``STDCFG_TRIX_HOME``. As this is independant from all failover roles, it's better to leave that out of Pacemaker.

#. Assemble and configure the RAID array on top of the JBOD.

#. Configure the controllers with the TrinityX configuration tool. The home directory will be left unexported.

#. Now that Pacemaker is configured, add the resource to assemble the RAID array in the ``Trinity`` group just before the ``wait-for-dev`` delay. You will need to stop all resources after the point of insertion, as well as the array itself beforehand, as Pacemaker will be in charge of it. With the standard out-of-the-box configuration, this would look like::

    pcs cluster disable wait-for-device
    
    # stop and take apart your array
    
    pcs resource create trinity-dev <standard:provider:type> [resource_options] [op monitor interval=123s] --group Trinity --after trinity-primary
    
    # the resource will start automatically, check that the RAID array is fine and assembled
    
    pcs resource enable wait-for-device


**SECONDARY INSTALLATION**

#. Install CentOS 7 Minimal, the networking drivers (especially if using RDMA) and the distributed FS drivers.

#. Set up the mount of the distributed FS to the path that you specified in ``STDCFG_TRIX_HOME``.

#. Configure the controllers with the TrinityX configuration tool. The home directory will not be imported via NFS.


**COMPUTE IMAGES**

#. Create a compute image.

#. Inside a chroot, add the networking drivers and the distributed FS drivers.

#. Set up the mount of the distributed FS to the path that you specified in ``STDCFG_TRIX_HOME``.



Adding a block device later
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Another possibility is that for a number of reasons, the RAID array that will back ``/trinity`` may not yet be ready for use when installing TrinityX. That's not much of a problem, as it will be easy to add it later on. One method is by simply reusing the exiting post scripts, which has the advantage of setting up a perfectly standard TrinityX configuration, identical to a normal, non-delayed setup.

Let's assume that you are using the standard paths, and are doing an HA setup. Let's also assume that for now, ``/trinity`` will live on the local hard drive.

#. Edit your configuration file to select the ``export`` use case, which will do everything but set up a filesystem::

    SHARED_FS_TYPE=export

#. If you know it already, provide the name of the block device that will be used later on. It won't be used right now, the only interest in setting it early is that it will be copied over to ``trinity.sh``. That can be skipped for now if you don't know it yet. Example::

    SHARED_FS_DEVICE=/dev/md0

#. Proceed with the installation. At the end, the files and directories and the cluster resources will look like this::

    # crm_resource -L
     Resource Group: Trinity
         trinity-primary    (ocf::heartbeat:Dummy): Started
         trinity-nfs-server (ocf::heartbeat:nfsserver): Started
         trinity-ip (ocf::heartbeat:IPaddr2):   Started
     Resource Group: Trinity-secondary
         trinity-secondary  (ocf::heartbeat:Dummy): Stopped
    
    # ls -ahlpd /trinity /etc/trinity.*
    -rw-------. 1 root root   52 Dec 12 15:16 /etc/trinity.local.sh
    lrwxrwxrwx. 1 root root   26 Dec 12 15:18 /etc/trinity.sh -> /trinity/shared/trinity.sh
    drwxr-xr-x. 6 root root 4.0K Dec 12 15:16 /trinity/

   Note that other services may have been added by later post-scripts.

#. The primary controller is now operational, and you can start using it.

#. When the backing block device is finally ready, plan for a downtime of the controller and stop all activity on the cluster.

#. Edit **``/etc/trinity.sh``** (which has precedence over the configuration file) to make sure that it includes the correct device name, and change the ``SHARED_FS_TYPE`` to select the ``dev`` resource. If necessary, add formatting options for the XFS filesystem::

    SHARED_FS_TYPE=dev
    SHARED_FS_DEVICE=/dev/md0
    SHARED_FS_FORMAT_OPTIONS=...

#. Stop all resources after ``trinity-primary``, as they depend on the ``/trinity`` directory. With the resources listed above, this will be::

    # pcs resource disable trinity-nfs-server
    
    # crm_resource -L
     Resource Group: Trinity
         trinity-primary    (ocf::heartbeat:Dummy): Started
         trinity-nfs-server (ocf::heartbeat:nfsserver): Stopped (disabled)
         trinity-ip (ocf::heartbeat:IPaddr2):   Stopped
     Resource Group: Trinity-secondary
         trinity-secondary  (ocf::heartbeat:Dummy): Stopped

#. Move the existing ``/trinity`` directory to another location, and fix the symlink for ``trinity.sh``::

    # mv /trinity /trinity.orig
    
    # ln -fs /trinity.orig/shared/trinity.sh /etc/trinity.sh 
    
    # ls -ahlpd /etc/trinity.sh 
    lrwxrwxrwx. 1 root root 31 Dec 12 15:50 /etc/trinity.sh -> /trinity.orig/shared/trinity.sh

#. Run the configuration script again, but only for the ``shared-storage`` post script. Make sure that you specify the correct name of the configuration file that you were using for the original installation::

    # ./configure.sh --config controller-HA.cfg filesystem/shared-storage

#. Check that the device has been formatted, is mounted and the cluster resources are up::

    # mount | grep trinity
    /dev/md0p1 on /trinity type xfs (rw,relatime,seclabel,attr2,inode64,noquota)
    
    # crm_resource -L
     Resource Group: Trinity
         trinity-primary    (ocf::heartbeat:Dummy): Started
         wait-for-device    (ocf::heartbeat:Delay): Started
         trinity-fs (ocf::heartbeat:Filesystem):    Started
         trinity-nfs-server (ocf::heartbeat:nfsserver): Stopped (disabled)
         trinity-ip (ocf::heartbeat:IPaddr2):   Stopped
     Resource Group: Trinity-secondary
         trinity-secondary  (ocf::heartbeat:Dummy): Stopped

#. Move all the contents of the original ``/trinity`` to the new one, and adjust the ``/etc/trinity.sh`` symlink again::

    # rsync -ravW /trinity.orig/ /trinity/
    
    # ln -fs /trinity/shared/trinity.sh /etc/trinity.sh

#. Re-enable the NFS server and the subsequent resources::

    # pcs resource enable trinity-nfs-server
    
    # crm_resource -L
     Resource Group: Trinity
         trinity-primary    (ocf::heartbeat:Dummy): Started
         wait-for-device    (ocf::heartbeat:Delay): Started
         trinity-fs (ocf::heartbeat:Filesystem):    Started
         trinity-nfs-server (ocf::heartbeat:nfsserver): Started
         trinity-ip (ocf::heartbeat:IPaddr2):   Started
     Resource Group: Trinity-secondary
         trinity-secondary  (ocf::heartbeat:Dummy): Stopped
    
    # showmount -e
    Export list for hactrl1.cluster:
    /trinity/home   *
    /trinity/shared (everyone)
    /trinity/images hactrl.cluster,hactrl2.cluster,hactrl1.cluster
    /trinity/local  hactrl.cluster,hactrl2.cluster,hactrl1.cluster

#. Resume normal cluster operations. When ready, delete the outdated ``/trinity.orig`` directory.


.. warning:: Remember that you will have to add a resource for the RAID array assembly, and insert it in the ``Trinity`` group before the ``wait-for-device`` resource. This is highly hardware-specific, and therefore not managed by TrinityX.

