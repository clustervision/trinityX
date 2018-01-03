
TrinityX HA design and implementation
=====================================

Introduction
------------

The TrinityX installation post scripts can set up the controller, or controller pair, either as a regular stand-alone system, or as part of a High-Availability pair with failover of services between the two controller of the pairs.

In the stand-alone setup (also called non-HA in the TrinityX documentation), the various services are set up in a very straightforward way. The configuration will be similar to what can be achieved by setting up the services by hand, and it should not present any surprise to an experienced systems administrator.

When the ``HA`` option is set to ``1`` in the configuration file, the TrinityX configuration script will set up an HA controller pair. Technically the installation script will need to run twice, once on each controller, but it is referred to as a single installation. The configuration is then a bit more complex, and may require a reference and documentation to understand how it is set up.

This document will cover the design and implementation of the HA configuration in TrinityX.

.. note:: In the following paragraphs we will reference the standard (or core) configuration. This is the base configuration that is set up in the critical section of the configuration process (refer to the configuration file ``controller-HA.cfg`` for the contents of the critical section). Other post scripts and manual configuration applied later may change that base configuration. Those post scripts are independant, and the exact combination of post scripts applied to the systems depends on customer requirements. As such, they may have different goals. Those additional post scripts, or any later manual change, are not covered by this document.

.. note:: This document assumes that the reader is already familiar with the storage configuration options of a new TrinityX installation. Please refer to the :ref:`ps_controller_storage` for more details.



Design goals
------------

The goals of the standard TrinityX HA configuration are the following:

- Correctness

  Above all else, the configuration must be correct. It must behave as designed, and barring any bug in the underlying software, must provide failover for all the services included.

- Genericity

  As the configuration will be deployed on very different systems, both in hardware design and in the software that will eventually run on them, it must be as generic as possible. Amongst other things, it most not make hidden assumptions about the software or hardware, nor can it place hidden constraints on the software or hardware design.

- Simplicity

  While a TrinityX system it typically deployed by experienced engineers, it may be managed by administrators unfamiliar with the peculiarities of HA administration. The configuration must be as simple as possible, to make its understanding easier and to limit the potential of errors through ease of use and administration.



Corosync and fencing
--------------------

`Corosync <https://corosync.github.io/corosync/>`_ is the group communication system used to keep track of the machines present in the cluster. It is used to detect node and communication failure, and passes that information up to Pacemaker for further action.

.. note:: The term "cluster" used in the context of Corosync means the group of machines known to Corosync, and for which failover is required. It does not mean the whole cluster with compute nodes, storage, etc. Typically a Corosync cluster will include the HA pair (or group of machines that can run the resources), and possibly one or more quorum devices, which are used for better determination of node failure in order to avoid split brain scenarios.

The TrinityX Corosync configuration is extremely basic:

- the Corosync cluster includes only the two controllers;

- the cluster is a generic cluster, not a 2-node only cluster;

- quorum is disabled;

- no fencing devices are configured.

This is not a very good configuration in itself, as it is not complete. It's difficult to impossible to detect a split brain situation with only two nodes; a quorum device or a third node is required. That extra configuration is highly dependant on the hardware available for a given deployment, and is left to be done by the engineer. The same logic applies to the fencing devices (BMCs, PDUs, etc).



Pacemaker
---------

The management of computing resources is done by `Pacemaker <http://wiki.clusterlabs.org/wiki/Pacemaker>`_. Pacemaker relies on Corosync to determine the availability of nodes within an HA cluster (same definition as for Corosync), and follows a set of rules and constraints to determine where to run sets of resources.

The TrinityX standard configuration makes the following assumptions:

- there are only two nodes on which the resources can run;

- the hardware of those nodes is identical (at least as far as the device names presented by the operating system);

- one node will be configured before the second one (those are called primary installation, resp. secondary installation).


The resources defined in Pacemaker are separated into two broad groups, which are called primary and secondary. The node on which the resources of the primary group are running at any given time has the primary role, the other one has the secondary role.

.. note:: Although the terms are identical, the primary role and the primary installation (and their respective secondary counterparts) are different. The *primary installation* is simply the one that happens first, and during which the configuration of the shared hardware resources is done. The *primary role* is an arbitraty name for the node that is currently running the essential services. Immediately after the primary installation, that first configured node will have the primary role. This will change after the secondary installation is done, as a failover can happen and the nodes switch roles.


The resources defined by the TrinityX installer are grouped together in resource groups. Resource groups are:

- colocated: all resources in a given group run on the same node;

- serialized: the resources start in that specific order and stop in reverse order; any failure of a resource prevents the subsequent ones from running.

There are two core groups: ``Trinity``, which defines the primary role, and ``Trinity-secondary`` which defines the secondary role. Three other groups attached to the core ``Trinity`` group: ``Trinity-fs``, ``Slurm`` and ``Luna``. Two Master/Slave sets: ``Trinity-drbd`` and ``Trinity-galera``. And two more resources that do not belong to any group or set: ``named`` and ``zabbix-server``

The exact number of resources defined depends on the storage model chosen by the user.


Resources
~~~~~~~~~

The full list of resources that may be created for the TrinityX base HA configuration is the following::

    01  Resource Group: Trinity
    02      primary          (ocf::heartbeat:Dummy)
    03      trinity-ip       (ocf::heartbeat:IPaddr2)

    04  Resource Group: Trinity-secondary
    05      secondary                   (ocf::heartbeat:Dummy)
    06      trinity-nfs-client-local    (ocf::heartbeat:Filesystem)    # only with export, dev and drbd
    07      trinity-nfs-client-images   (ocf::heartbeat:Filesystem)    # only with export, dev and drbd
    08      trinity-nfs-client-shared   (ocf::heartbeat:Filesystem)    # only with export, dev and drbd
    09      trinity-nfs-client-home     (ocf::heartbeat:Filesystem)    # only with export, dev and drbd

    10  Resource Group: Trinity-fs
    11      wait-for-device     (ocf::heartbeat:Delay)         # only with dev and drbd
    12      trinity-fs          (ocf::heartbeat:Filesystem)    # only with dev and drbd
    13      fs-ready            (ocf::heartbeat:Dummy)
    14      trinity-nfs-server  (ocf::heartbeat:nfsserver)     # only with export, dev and drbd

    15  Master/Slave Set: Trinity-drbd [DRBD]        # only with drbd
    16  Master/Slave Set: Trinity-galera [Galera]

    17  named                   (systemd:named)
    18  zabbix-server           (systemd:zabbix-server)

    19  Resource Group: Slurm
    20      slurmdbd            (systemd:slurmdbd)
    21      slurmctld           (systemd:slurmctld)

    22  Resource Group: Luna
    23      mongod-arbiter      (systemd:mongod-arbiter)
    24      dhcpd               (systemd:dhcpd)
    25      nginx               (systemd:nginx)
    26      lweb                (systemd:lweb)
    27      ltorrent            (systemd:ltorrent)


Notes:

- The NFS resources (server #14, clients #06-09) are not created when the ``none`` storage use case is selected.

- The filesystem resources (#11, which is only a delay to make sure that the kernel has caught up with the new device, and #12, which mounts the underlying filesystem) only exist for use cases where a separate filesystem is created for the TrinityX directory tree: ``dev`` and ``drbd``.

- The DRBD master-slave set (#15) is only created when the ``drbd`` use case is selected. Due to its architecture, DRBD can only be managed through a master-slave resource. That resource includes two instances, the master which will always run on a node, and a slave which will run if another node is available.

- The dummy resources #02 and #05 are there for practical reasons. It's not possible to insert a new resource at the very beginning of a group, only at the end or after an existing resource in that group. The dummy resources (which do nothing at all) are there so that other resources can be inserted just after them, which is as good as being the first one in the group.

- The dummy resource #13 serves as an anchor for resources that require the TrinityX directory tree. With the ``dev`` and ``drbd`` use cases, the corresponding shared filesystem resources will be inserted before that one. All resources inserted after this anchor will be able to use the directory tree, regardless of the storage use case.

- The resource group Luna (#22-27) has monitoring disabled so that a service failing in this group does not trigger a failover or any pacemaker operations.


Constraints
~~~~~~~~~~~

The location and starting order of those resources is managed through Pacemaker constraints.

As mentioned earlier, groups have implicit constraints: they are both colocated an serialized. This allows for a very intuitive understanding of what happens inside of each group.


A few additional constraints are defined to locate and order groups between themselves::

    01  Ordering Constraints:
    02    promote Trinity-drbd then start wait-for-device (kind:Mandatory)  # only with drbd
    03    promote Trinity-galera then start Slurm         (kind:Mandatory)
    04    promote Trinity-galera then start zabbix-server (kind:Mandatory)
    05    start trinity-fs then start Slurm               (kind:Mandatory)
    06    start trinity-fs then start zabbix-server       (kind:Mandatory)
    07    start trinity-fs then start named               (kind:Mandatory)
    08    start trinity-fs then start Luna                (kind:Mandatory)
    
    09    Resource Sets:
    10      set Trinity Trinity-secondary
    11      set Trinity Trinity-drbd Trinity-fs Trinity-secondary           # only with drbd
    
    12  Colocation Constraints:
    13    Trinity-secondary with Trinity (score:-INFINITY)
    14    Trinity-drbd      with Trinity (score:INFINITY) (rsc-role:Master) (with-rsc-role:Started)  # only with drbd
    15    Trinity-galera    with Trinity (score:INFINITY) (rsc-role:Master) (with-rsc-role:Started)
    16    Trinity-fs        with Trinity (score:INFINITY)
    17    named             with Trinity (score:INFINITY)
    18    zabbix-server     with Trinity (score:INFINITY)
    19    Slurm             with Trinity (score:INFINITY)
    20    Luna              with Trinity (score:INFINITY)


Notes:

- The two essential constraints, that are always present, are #10 and #13. #10 is a resource set, which serializes the two groups. It means that ``Trinity-secondary`` will only start after ``Trinity`` has started successfully. As most, if not all, secondary resources depend on services that are started in the primary group, this is again the most intuitive strategy.

- #13 is a colocation constraint, which says that ``Trinity-secondary`` cannot run on the same node as ``Trinity``, and that ``Trinity`` comes first. In other words: pick a node to run the primary, and if there is another one available, run the secondary on it, otherwise don't run the secondary. This is the rule that allows for failover of the primary resources, and makes sure that primary services are always up.

- Due to its existence as a master-slave resource, DRBD requires a few additional rules. #11 is a superset of #10, which says that DRBD must start first. As a lot of primary services depend on the availability of the shared storage, this makes sense. The #10 constraint will be satisfied if #11 is; in effect #10 can be deleted on DRBD setups without negative effect.

- #14-20 means that the primary group serves as an anchor for all other services that must run on the primary controller. In effect, that node becomes the DRBD master node (#14) as well as the Galera master node (#15). We don't need another colocation rule for the DRBD/Galera slave and the secondary node, as the implicit rule of the master-slave set (the slave must be on another node) and #13 guarantee that they will end up on the same node, in a 2-node system.

- #02 is there to make sure that the device-related resources (``wait-for-device`` and ``trinity-fs``) only start after the promotion of the DRBD resource, which is to say, after it becomes master on the local node. This is needed due to the way Pacemaker starts resources, and the difference between starting and promoting a resource.



OpenLDAP
--------

In TrinityX HA installs, OpenLDAP is not managed as a pacemaker resource. It uses instead its builtin mirroring system.

Both controllers have an openldap server that can accept both writes and reads and that can mirror the writes to the other controller. However, in practice only the server running on the primary controller does receive write requests since it is the server that listens on the floating IP of the HA cluster.

OpenLDAP server is managed by systemd and a failure does not result in a failover. It should however result in a notification being sent to the admins. This part should be taken care of by the monitoring system.



HA-pair management
------------------

A fully configured TrinityX HA cluster will automatically perform a failover upon a critical failure. There are however a few guidelines that should be kept in mind when managing the cluster. These include bringing a failing secondary controller up, bringing the cluster up from a cold state (a state in which both the primary and secondary controllers were down such us a power failure) or recovering the new secondary node after a successful failover.

Upon a failure of the secondary node or a successful failover the system adminstraors should be notified in order for them to either fix the issues on the secondary node in the first case, or to recover the new secondary node in the second case. Otherwise, if these failures remain unhandled, they will interfere with the proper execution of a failover in a case where the primary controller encounters an issue.

As such, the monitoring system should include checks to monitor the state of the HA cluster.

.. note:: TrinityX does not configue pacemaker and corosync to start when a controller starts up. It is left at the discrection of the sysadmin to manually start it up using ``pcs cluster start`` on the newly booted controller.


Booting the controllers
~~~~~~~~~~~~~~~~~~~~~~~

When booting the cluster from a cold state (all nodes down) special care should be taken in order to chose which node will serve as the primary controller.

TrinityX comes preconfigured with a Galera based MariaDB cluster. This means that all controllers can serve as a write destination for any SQL write requests. But for the purposes of TrinityX we have adapted the pacemaker resource agent from a multi-master resource to a master-slave resource, and we exclusively use the floating IP of the cluster for any database requests. This effectively transforms the galera cluster into a synchronously replicated master/slave setup.

When booting the cluster, the first resource group that comes up is ``Trinity`` which includes the floating IP, then pacemaker will try to start ``Trinity-galera`` and ``Trinity-drbd``. In cases where the node on which the resources are being started was the previous primary node (before the cold boot), the cluster will continue booting up successfully. If, however, this node had the secondary role before the cold bootthe cluster can hit a special case. The node that is now being promoted to the primary role may or may not have the latest state of the cluster. Namely, its galera replication sequence number might be lower than the one on the node that pacemaker decided to load as secondary.

To avoid such a situation it is crucial that a sysadmin verifies the state of each node before trying to start the pacemaker cluster. To do so, a sysadmin can run the following commands to obtain the sequence number of each node::

    # First we can try retrieving the number from galera's state file

    cat /var/lib/mysql/grastate.dat | sed -n 's|^seqno.\s*\(.*\)\s*$|\1|p'

    # If the above number is '-1' then we will have to load the mariadb server to get the sequence number

    mysqld --datadir=/var/lib/mysql --user=mysql --wsrep-recover |& sed -n 's|.*WSREP:\s*[R|r]ecovered\s*position.*:\(.*\)\s*$|\1|p'


Once the sequence number of each node is recovered, the sysadmin can proceed to boot the cluster by running the following commands on the node that has the highest galera sequence number::

    pcs cluster start --all
    crm_attribute -l reboot --name "Galera-bootstrap" -v "true"

.. note:: The second command must be run immediatly after the first one in order for it to take effect.


Maintenance 
~~~~~~~~~~~ 

During the lifetime of the cluster a sysadmin might need to change configuration files, update packages or restart services. Doing so, however can have a negative impact on the cluster as it might trigger a failover. To avoid such behaviour and temporarily prevent pacemaker from interfering with the state of the cluster it is advised that the maintenance mode be activated before applying any changes. 
 
This way, the admins can take full control of the cluster to perform any required operations without having to worry about the state of the cluster. maintenance mode in pacemaker can be enabled by running the following command:: 
 
    pcs property set maintenance-mode=true 
 
It is expected that this mode be deactivated once the maintenance operations are completed and that the cluster is brought up to the same state where it was before activating the mode. maintenance mode can be deactivated by running the following command:: 
 
    pcs property set maintenance-mode=false 
 
 

Conclusion
----------

With few carefuly chosen resources and constraints, the TrinityX HA configuration reaches all the design goals that were specified earlier:

- it is correct (barring bugs in the underlying software), as proven by repetitive testing of failover between controller nodes;

- it is generic, as it doesn't include resources that manage specific types of hardware, yet leaves room and includes documentation for the engineers to add those resources when deploying TrinityX;

- it is as simple and intuitive as possible, with very few constraints and clearly delimited primary and secondary roles. It is also extensible very easily, as there are few existing rules and constraints to be aware of.


When deploying a TrinityX HA pair, what is left for the engineer to do are the hardware-specific tasks:

- add an external Corosync quorum device;

- add fencing resources and validate the fencing configuration;

- if necessary in the ``dev`` storage use case, add a resource to assemble a RAID array and insert it before ``wait-for-device`` in the primary ``Trinity`` group.

