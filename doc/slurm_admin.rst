Basic administrative tasks in Slurm
===================================


Daemons and files
~~~~~~~~~~~~~~~~~

SLURM functionality in TrinityX relies on 3 daemons: munged, slurmctld and slurmdbd running on the controller. Every compute node has slurmd running.

    * ``munged`` is handling security communication between slurmd and slurmctld
    * ``slurmctld`` main service doing heavy-lifting of a proper job scheduling
    * ``slurmdbd`` SLURM accounting
    * ``slurmd`` daemon running on compute nodes and spawning user executables

In addition, ``slurmdbd`` must have the mysql daemon running to store accounting data.

By default, the SLURM config consists of several files located in ``/etc/slurm``, which is symlinked to ``/trinity/shared/etc/slurm``.

    * ``slurm.conf`` main config
    * ``slurm-nodes.conf`` nodes' definitions
    * ``slurm-partitions.conf`` definitions of queue
    * ``slurm-user.conf`` customizations
    * ``slurmdbd.conf`` configuration file of slurmdbd daemon

In addition, the ``mongod`` daemon relies on the corresponding config located at ``/etc/mongod.conf``.

TrinityX has several ``systemd`` customizations located in /etc/systemd/system::

    # ls /etc/systemd/system/{munge*,slurm*}
    /etc/systemd/system/munge.service.d:
    trinity.conf

    /etc/systemd/system/slurmctld.service.d:
    trinity.conf

    /etc/systemd/system/slurmdbd.service.d:
    trinity.conf

Log files can be found in ``/var/log/slurm`` on both controllers and compute nodes.

Commands
~~~~~~~~

The most popular commands from an administrator perspective are usually ``sinfo``, ``squeue``, and ``scontrol``.

    * ``sinfo`` show status of the nodes and queues
    * ``squeue`` list of jobs running on the cluster
    * ``scontrol`` manage SLURM configuration and state

For ``sinfo``, pay special attention to the "NODE STATE CODES" section in the man pages.

``scontrol`` allows SLURM to be reconfigured on the fly. For example, we can drain (bring it offline in SLURM for maintenance purposes) and un-drain the node in the following way::

    # sinfo
    PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
    defq*        up   infinite      1   idle node001

    # scontrol update node=node001 state=drain reason='Heavily broken'

    # sinfo
    PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
    defq*        up   infinite      1  drain node001

    # scontrol show node=node001
    NodeName=node001 Arch=x86_64 CoresPerSocket=1
       CPUAlloc=0 CPUErr=0 CPUTot=1 CPULoad=0.13
       AvailableFeatures=(null)
       ActiveFeatures=(null)
       Gres=(null)
       NodeAddr=node001 NodeHostName=node001 Port=0 Version=17.02
       OS=Linux RealMemory=100 AllocMem=0 FreeMem=4222 Sockets=1 Boards=1
       State=IDLE+DRAIN ThreadsPerCore=1 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
       Partitions=defq
       BootTime=2018-03-09T16:01:07 SlurmdStartTime=2018-03-09T16:03:08
       CfgTRES=cpu=1,mem=100M
       AllocTRES=
       CapWatts=n/a
       CurrentWatts=0 LowestJoules=0 ConsumedJoules=0
       ExtSensorsJoules=n/s ExtSensorsWatts=0 ExtSensorsTemp=n/s
       Reason=Heavily broken [root@2018-03-09T16:04:43]

To make the node available for user jobs::

    # scontrol update node=node001 state=undrain

With ``scontrol``, it is possible to check the status of the running jobs::

   # squeue
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
                 2      defq    sleep     root  R       0:07      1 node001

    # scontrol show job 2
    JobId=2 JobName=sleep
       UserId=root(0) GroupId=root(0) MCS_label=N/A
       Priority=1 Nice=0 Account=root QOS=normal
       JobState=RUNNING Reason=None Dependency=(null)
       Requeue=1 Restarts=0 BatchFlag=0 Reboot=0 ExitCode=0:0
       RunTime=00:00:13 TimeLimit=UNLIMITED TimeMin=N/A
       SubmitTime=2018-03-09T16:15:06 EligibleTime=2018-03-09T16:15:06
       StartTime=2018-03-09T16:15:06 EndTime=Unknown Deadline=N/A
       PreemptTime=None SuspendTime=None SecsPreSuspend=0
       Partition=defq AllocNode:Sid=controller1:18804
       ReqNodeList=(null) ExcNodeList=(null)
       NodeList=node001
       BatchHost=node001
       NumNodes=1 NumCPUs=1 NumTasks=1 CPUs/Task=1 ReqB:S:C:T=0:0:*:*
       TRES=cpu=1,node=1
       Socks/Node=* NtasksPerN:B:S:C=0:0:*:* CoreSpec=*
       MinCPUsNode=1 MinMemoryNode=0 MinTmpDiskNode=0
       Features=(null) DelayBoot=00:00:00
       Gres=(null) Reservation=(null)
       OverSubscribe=NO Contiguous=0 Licenses=(null) Network=(null)
       Command=sleep
       WorkDir=/trinity/shared/etc/slurm
       Power=


For more information about SLURM commands and slurm config please have a look at `official documentation <https://slurm.schedmd.com/documentation.html>`_
