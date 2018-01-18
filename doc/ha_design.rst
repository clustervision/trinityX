
TrinityX HA design and implementation
=====================================

Introduction
------------

The TrinityX installation playbooks can set up the controller, or the controller pair, either as a regular stand-alone system, or as part of a High-Availability pair with failover of services between the two controllers of the pair.

In the stand-alone setup (also called non-HA in the TrinityX documentation), the various services are set up in a very straightforward way. The configuration will be similar to what can be achieved by setting up the services by hand, and it should not present any surprise to an experienced systems administrator.

When the ``ha`` variable in ``group_vars/all`` is set to ``true``, the TrinityX playbook .i.e ``controller.yml`` will set up an HA controller pair. Please note that installation playbook will only need to run once on the controller selected to become primary, the other controller will also be setup in parallel.

This document will cover the design and implementation of the HA configuration in TrinityX.

.. note:: In the following paragraphs we will reference the standard (or core) configuration. This is the base configuration that is set up by the TrinityX playbooks. As such, any later manual changes, are not covered by this document.

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

- IPMI based fencing is configured.

This is not a very good configuration in itself, as it is difficult to impossible to detect a split brain situation with only two nodes; a quorum device or a third node is required. That extra configuration is highly dependant on the hardware available for a given deployment, and is left to be done by the engineer.



Pacemaker
---------

The management of computing resources is done by `Pacemaker <http://wiki.clusterlabs.org/wiki/Pacemaker>`_. Pacemaker relies on Corosync to determine the availability of nodes within an HA cluster (same definition as for Corosync), and follows a set of rules and constraints to determine where to run sets of resources.

The TrinityX standard configuration makes the following assumptions:

- there are only two nodes on which the resources can run;

- the hardware of those nodes is identical (at least as far as the device names presented by the operating system);


The resources defined in Pacemaker are separated into two broad groups, which are called primary and secondary. The node on which the resources of the primary group are running at any given time has the primary role, the other one has the secondary role.

.. note:: Although the terms are identical, the primary role and the primary installation (and their respective secondary counterparts) are different. The *primary installation* is simply the one that happens on the node chose to have the *primary role*, and during which the configuration of the shared hardware resources is done. The *primary role* is an arbitraty name for the node that is currently running the essential services. After the installation is done the node with the primary role might change, as a failover can happen and the nodes switch roles.


The resources defined by the TrinityX installer are grouped together in resource groups. Resource groups are:

- colocated: all resources in a given group run on the same node;

- serialized: the resources start in that specific order and stop in reverse order; any failure of a resource prevents the subsequent ones from running.

There are two core groups: ``Trinity``, which defines the primary role, and ``Trinity-secondary`` which defines the secondary role. Two other groups attached to the core ``Trinity`` group: ``Trinity-fs`` and ``trinity-stack``. One Master/Slave sets: ``Trinity-drbd``. And lastly: a clone set ``ibmon-clone`` and fencing resources ``fence-controllerX``.

The exact number of resources defined depends on the storage model chosen by the user.


Resources
~~~~~~~~~

The full list of resources that may be created for the TrinityX base HA configuration is the following::

    01  Resource Group: Trinity
    02      primary                        (ocf::pacemaker:Dummy)
    03      trinity-ip                     (ocf::heartbeat:IPaddr2)

    04  Resource Group: Trinity-secondary
    05      secondary                      (ocf::pacemaker:Dummy)

    06  Resource Group: Trinity-fs
    07      fs (ocf::pacemaker:Dummy)
    08      wait-for-device                (ocf::heartbeat:Delay)
    09      trinity-fs                     (ocf::heartbeat:Filesystem)
    10      fs-ready                       (ocf::pacemaker:Dummy)

    11  Resource Group: Trinity-stack
    12      stack                          (ocf::pacemaker:Dummy)
    13      named                          (systemd:named)
    14      openldap                       (systemd:slapd)
    15      mariadb                        (systemd:mariadb)
    16      slurmdbd                       (systemd:slurmdbd)
    17      slurmctld                      (systemd:slurmctld)
    18      nginx                          (systemd:nginx)
    19      mongod                         (systemd:mongod)
    20      xinetd                         (systemd:xinetd)
    21      dhcpd                          (systemd:dhcpd)
    22      lweb                           (systemd:lweb)
    23      ltorrent                       (systemd:ltorrent)
    24      httpd                          (systemd:httpd)
    25      snmptrapd                      (systemd:snmptrapd)
    26      zabbix-server                  (systemd:zabbix-server)

    27  Master/Slave Set: Trinity-drbd [DRBD]

    28  Clone Set: ibmon-clone [ibmon]

    29  fence-controller1                  (stonith:fence_ipmilan)
    30  fence-controller2                  (stonith:fence_ipmilan)


Notes:

- The filesystem resources (#08, which is only a delay to make sure that the kernel has caught up with the new device, and #09, which mounts the underlying filesystem) only exist for use cases where a separate filesystem is created for the TrinityX directory tree: ``dev`` and ``drbd``.

- The DRBD master-slave set (#27) is only created when the ``drbd`` use case is selected. Due to its architecture, DRBD can only be managed through a master-slave resource. That resource includes two instances, the master which will always run on a node, and a slave which will run if another node is available.

- The dummy resources are there for practical reasons. It's not possible to insert a new resource at the very beginning of a group, only at the end or after an existing resource in that group. The dummy resources (which do nothing at all) are there so that other resources can be inserted just after them, which is as good as being the first one in the group.

- The dummy resource #10 serves as an anchor for resources that require the TrinityX directory tree. With the ``dev`` and ``drbd`` use cases, the corresponding shared filesystem resources will be inserted before that one. All resources inserted after this anchor will be able to use the directory tree, regardless of the storage use case.

- The resource group Trinity-stack (#11-26) has monitoring disabled so that a service failing in this group does not trigger a failover or any pacemaker operation.


Constraints
~~~~~~~~~~~

The location and starting order of those resources is managed through Pacemaker constraints.

As mentioned earlier, groups have implicit constraints: they are both colocated an serialized. This allows for a very intuitive understanding of what happens inside of each group.


A few additional constraints are defined to locate and order groups between themselves::

    00  Location Constraints:
    01    Resource: Trinity
            Constraint: location-Trinity Rule: score=-INFINITY Expression: ethmonitor-ib0 ne 1
    02    Resource: fence-controller1 Disabled on: controller1 (score:-INFINITY)
    03    Resource: fence-controller2 Disabled on: controller2 (score:-INFINITY)

    04  Ordering Constraints:
    05    start Trinity then start Trinity-secondary (kind:Mandatory)
    06    start Trinity then start Trinity-fs (kind:Mandatory)
    07    start Trinity-fs then start Trinity-stack (kind:Mandatory)
    08    start Trinity then start DRBD-master (kind:Mandatory)
    09    start DRBD-master then start Trinity-fs (kind:Mandatory)
    10    start Trinity-fs then start Trinity-secondary (kind:Mandatory)
    11    promote DRBD-master then start wait-for-device (kind:Mandatory)

    12  Colocation Constraints:
    13    Trinity-secondary with Trinity (score:-INFINITY)
    14    Trinity-fs with Trinity (score:INFINITY)
    15    Trinity-stack with Trinity (score:INFINITY)
    16    DRBD-master with Trinity (score:INFINITY) (rsc-role:Master) (with-rsc-role:Started)


Notes:

- The two essential constraints, that are always present, are #05 and #13. #05 is a constraint which serializes the two groups. It means that ``Trinity-secondary`` will only start after ``Trinity`` has started successfully. As most, if not all, secondary resources depend on services that are started in the primary group, this is again the most intuitive strategy.

- #13 is a colocation constraint, which says that ``Trinity-secondary`` cannot run on the same node as ``Trinity``, and that ``Trinity`` comes first. In other words: pick a node to run the primary, and if there is another one available, run the secondary on it, otherwise don't run the secondary. This is the rule that allows for failover of the primary resources, and makes sure that primary services are always up.

- #14-16 means that the primary group serves as an anchor for all other services that must run on the primary controller.

- #11 is there to make sure that the device-related resources (``wait-for-device`` and ``trinity-fs``) only start after the promotion of the DRBD resource, which is to say, after it becomes master on the local node. This is needed due to the way Pacemaker starts resources, and the difference between starting and promoting a resource.

- #02-03 ensure that fencing resources start on opposite nodes in order for fencing to function properly if the need for it arises.


Databases
---------

In TrinityX HA installs, all databases (OpenLDAP, MariaDB and MongoDB) are managed by pacemaker and are part of the trinity-stack resource group. They all rely on the underlying DRBD replication to ensure that data is being constantly synchronized between the two controllers.


HA-pair management
------------------

A fully configured TrinityX HA cluster will automatically perform a failover upon a critical failure. There are however a few guidelines that should be kept in mind when managing the cluster. These include bringing a failing secondary controller up, bringing the cluster up from a cold state (a state in which both the primary and secondary controllers were down such us a power failure) or recovering the new secondary node after a successful failover.

Upon a failure of the secondary node or a successful failover the system adminstraors should be notified in order for them to either fix the issues on the secondary node in the first case, or to recover the new secondary node in the second case. Otherwise, if these failures remain unhandled, they will interfere with the proper execution of a failover in a case where the primary controller encounters another issue.

As such, the monitoring system should include checks to monitor the state of the HA cluster.

.. note:: TrinityX does not configue pacemaker and corosync to start when a controller starts up. It is left at the discrection of the sysadmin to manually start it up using ``pcs cluster start`` on the newly booted controller.


Booting the controllers
~~~~~~~~~~~~~~~~~~~~~~~

When booting the cluster from a cold state (all nodes down) special care should be taken in order to chose which node will serve as the primary controller.

When booting the cluster, the first resource group that comes up is ``Trinity`` which includes the floating IP, then pacemaker will try to start ``Trinity-drbd``. In cases where the node on which the resources are being started was the previous primary node (before the cold boot), the cluster will continue booting up successfully. If, however, this node had the secondary role before the cold boot, the cluster can hit a special case: The node that is now being promoted to the primary role may or may not have the latest state of the cluster. Namely, its DRBD state might be behind that of the node that pacemaker decided to load as secondary.

To avoid such a situation it is crucial that a sysadmin starts the cluster from the node that last had the primary role.

The sysadmin can proceed to boot the cluster by running the following command::

    pcs cluster start --all



Maintenance 
~~~~~~~~~~~ 

During the lifetime of the cluster a sysadmin might need to change configuration files, update packages or restart services. Doing so, however can have a negative impact on the cluster as it might trigger a failover. To avoid such behaviour and temporarily prevent pacemaker from interfering with the state of the cluster it is advised that the maintenance mode be activated before applying any changes. 
 
This way, the admins can take full control of the cluster to perform any required operations without having to worry about the state of the cluster. maintenance mode in pacemaker can be enabled by running the following command:: 
 
    pcs property set maintenance-mode=true 
 
It is expected that this mode be deactivated once the maintenance operations are completed and that the cluster is brought up to the same state where it was before activating the mode. Maintenance mode can then be deactivated by running the following command::
 
    pcs property set maintenance-mode=false 
 
 

Conclusion
----------

With few carefuly chosen resources and constraints, the TrinityX HA configuration reaches all the design goals that were specified earlier:

- It is correct (barring bugs in the underlying software), as proven by repetitive testing of failover between controller nodes;

- It is generic, as it doesn't include resources that manage specific types of hardware, yet leaves room and includes documentation for the engineers to add those resources when deploying TrinityX;

- It is as simple and intuitive as possible, with very few constraints and clearly delimited primary and secondary roles. It is also extensible very easily, as there are few existing rules and constraints to be aware of.


When deploying a TrinityX HA pair, what is left for the engineer to do are the hardware-specific tasks:

- Add an external Corosync quorum device;

- If necessary in the ``dev`` storage use case, add a resource to assemble a RAID array and insert it before ``wait-for-device`` in the primary ``Trinity`` group.

