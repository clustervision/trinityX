Hints and tips for SLURM
========================

Basic operations
~~~~~~~~~~~~~~~~

Slurm is an open source, fault-tolerant, and highly scalable cluster management and job scheduling system for large and small Linux clusters. Good starting point to learn more about SLURM is official site::

    https://slurm.schedmd.com/quickstart.html

Paired with munge (for secure communication) SLURM provides scheduling facilities in TrinityX. It allows to use cluster simultaneously for multiple users without affecting each other jobs. The simplest way of getting access to node in SLURM is to issue the following::

    $ srun --nodelist=node001 hostname
    node001.cluster

List of all available nodes and partitions can be inspected in ``sinfo`` output.

In this quick example node001 was allocated, ssh client  connected to node001 and ``hostname`` command was issued on node001. Another way of running commands is to allocate resources first and then execte srun::

    $ sallocate --nodelist=node001,node002
    $ srun hostname
    node001.cluster
    node002.cluster

During the allocation status of the nodes can be viewed in ``squeue`` output::

    $ squeue
    JOBID PARTITION     NAME        USER ST       TIME  NODES NODELIST(REASON)
     3439      defq     bash   cvsupport  R       0:02      2 node[001-002]

In most of the cases output above means that nodes are being exclusively 'owned' by user and no other job or user within SLURM will be not unable to use these nodes to compute their jobs. However it might be not true if SLURM cluster is configured in shared mode.

If SLURM is unable to allocate resources it put requestir to a waiting line::

    $ salloc --nodelist=node001,node002
    salloc: Pending job allocation 3440
    salloc: job 3440 queued and waiting for resources

    $ squeue
    JOBID PARTITION     NAME        USER ST       TIME  NODES NODELIST(REASON)
     3440      defq     bash   cvsupport PD       0:00      2 (Resources)

``ST`` column show the status of job allocation. For example ``R`` is for running and ``PD`` is for pending. Other codes can be found in ``man squeue``.

Specifying the list of the nodes for jobs is not a good practice, as you need to be sure nodes are available. Better approach is to specify partition to run and amount of nodes::

    $ srun --partition=defq --nodes=2 hostname
    node004.cluster
    node005.cluster

Partitions is a way to organize nodes in cluster. Usually all nodes in partition is homogeneous, i.e. have the same hardware configuration, same software installed and have access to same resources, like shared filesystems.

Using sbatch
~~~~~~~~~~~~

``srun`` and ``salloc`` comandsa are great if it needs to run interactive jobs. For long-running tasks ``sbatch`` comes into play. ``sbatch`` allows to submit job file into the queuing system. Job file usually is the ordinary shell script file with directives for SLURM. Directives are starting with ``#SBATCH`` and usually located in the beginning of the job file. You can submit job file without any directives and SLURM will consider some defaults: i.e. sallocate single node, put job to default partition, etc. Usually it is worth to change such behaviour. Here is the example of basic script::

    #!/bin/bash
    #SBATCH --partition=defq
    #SBATCH --nodes=2
    hostname

To submit job put content above to ``test01.job`` file and simpy run::

    $ sbatch test01.job

Please note that you might not have defq partition confugured in your cluster. Please check ``sinfo`` output.

After job finishes output of the job will appear in your home directory. It  will be called ``slurm-3443.out`` where 3443 is a job number.
If job failed for some reason, file ``slurm-3443.err`` will be created. First file - ``.out`` - contains STDOUT from job script, and ``.err`` have STDERR content. You can customize path and name of these files::

    #SBATCH --output=/path/to/store/outputs/myjob-%J.out
    #SBATCH --error=/path/to/store/outputs/myjob-%J.err

Where job number will be substituted instead of %J variable. For more variables please have a look to ``man sbatch``.

By default job assumes that current working direrctory is a home dir of the user. You can customize it, specifying ``--workdir=``::

    #SBATCH --workdir=/new/home/dir/

In addition you can specify number of nodes, dependencies, starting time and change many other tunables. All of them are described in ``man sbatch``.

Variables in job scripts
~~~~~~~~~~~~~~~~~~~~~~~~

During job execution SLURM provides several environmental variables. It might be handy for logging purposes of job can tune its behaviour based on them::

    #!/bin/bash
    #SBATCH --partition=defq
    #SBATCH --nodes=2

    echo "Job is running on ${SLURM_JOB_NUM_NODES} nodes"
    echo "Allocated nodes are: ${SLURM_JOB_NODELIST}"

Output will contain::

    $ cat slurm-3444.out
    Job is running on 2 nodes
    Allocated nodes are: node[001-002]

In addition more than 100 variables are available. For reference, please run ``man sbatch``.


Srun and mpirun in job scripts
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Usually you don't need to use srun in job scripts. Spawning multiple copies of binary is usually performed by mpi library. To get the idea of how things are working in sbatch context you can can check of the following output::

    #!/bin/bash
    #SBATCH --partition=defq
    #SBATCH --nodes=2

    echo "======= hostname: ======="
    hostname
    echo "======= srun hostname: ======="
    srun hostname
    echo "======= mpirun hostname: ======="
    module load openmpi/2.0.1
    mpirun hostname

Please note that ``module load`` line might differ in your environment.

And the output will be similar to::

    $ cat slurm-3447.out
    ======= hostname: =======
    node001.cluster
    ======= srun hostname: =======
    node001.cluster
    node002.cluster
    ======= mpirun hostname: =======
    node001.cluster
    node001.cluster
    node001.cluster
    node001.cluster
    node002.cluster
    node002.cluster
    node002.cluster
    node002.cluster

The number of mpirun hostnames depends of the number of cores in the nodes.

Running MPI application. Example
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To be concrete, let's take MPI Hello Word from `MPI Tutorial <http://mpitutorial.com/tutorials/mpi-hello-world>`_ and put it to mpi-hello.c::

	#include <mpi.h>
	#include <stdio.h>

	int main(int argc, char** argv) {
		// Initialize the MPI environment
		MPI_Init(NULL, NULL);

		// Get the number of processes
		int world_size;
		MPI_Comm_size(MPI_COMM_WORLD, &world_size);

		// Get the rank of the process
		int world_rank;
		MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

		// Get the name of the processor
		char processor_name[MPI_MAX_PROCESSOR_NAME];
		int name_len;
		MPI_Get_processor_name(processor_name, &name_len);

		// Print off a hello world message
		printf("Hello world from processor %s, rank %d"
			   " out of %d processors\n",
			   processor_name, world_rank, world_size);

		// Finalize the MPI environment.
		MPI_Finalize();
	}

Now we need to compile application with one of the MPI version you have installed on your cluster::

    $ module load openmpi/2.0.1
    $ mpicc -o mpi-hello.bin mpi-hello.c

Create job file::

    #!/bin/bash
    #SBATCH --partition=defq
    #SBATCH --nodes=2

    module load openmpi/2.0.1
    mpirun mpi-hello.bin

And run it::

    $ sbatch test03.job

In output file you will see something like::

    Hello world from processor node001.cluster, rank 2 out of 4 processors
    Hello world from processor node001.cluster, rank 1 out of 4 processors
    Hello world from processor node001.cluster, rank 0 out of 4 processors
    Hello world from processor node001.cluster, rank 3 out of 4 processors
    Hello world from processor node002.cluster, rank 1 out of 4 processors
    Hello world from processor node002.cluster, rank 3 out of 4 processors
    Hello world from processor node002.cluster, rank 0 out of 4 processors
    Hello world from processor node002.cluster, rank 2 out of 4 processors

You are done. Here you created and run our first MPI application on HPC cluster.
