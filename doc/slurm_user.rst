Hints and tips for SLURM
========================

Basic operations
~~~~~~~~~~~~~~~~

Slurm is an open source, fault-tolerant, and highly scalable cluster management and job scheduling system for large and small Linux clusters. A good starting point to learn more about SLURM is the official site::

    https://slurm.schedmd.com/quickstart.html

Paired with munge (for secure communication), SLURM provides scheduling facilities in TrinityX. It allows use of the cluster simultaneously by multiple users without affecting each others' jobs. The simplest way of getting access to a node in SLURM is to issue the following::

    $ srun --nodelist=node001 hostname
    node001.cluster

A list of all available nodes and partitions can be inspected in ``sinfo`` output.

In this quick example, node001 was allocated, the ssh client connected to node001, and the ``hostname`` command was issued on node001. Another way of running commands is to allocate resources first and then execute srun::

    $ sallocate --nodelist=node001,node002
    $ srun hostname
    node001.cluster
    node002.cluster

During allocation, the status of nodes can be viewed in the ``squeue`` output::

    $ squeue
    JOBID PARTITION     NAME        USER ST       TIME  NODES NODELIST(REASON)
     3439      defq     bash   cvsupport  R       0:02      2 node[001-002]

In most cases, the output above means that nodes are exclusively 'owned' by a user and no other job or user within SLURM can use these nodes to compute their jobs. However, it might be not true if a SLURM cluster is configured in shared mode.

If SLURM is unable to allocate resources, it will queue the request to wait::

    $ salloc --nodelist=node001,node002
    salloc: Pending job allocation 3440
    salloc: job 3440 queued and waiting for resources

    $ squeue
    JOBID PARTITION     NAME        USER ST       TIME  NODES NODELIST(REASON)
     3440      defq     bash   cvsupport PD       0:00      2 (Resources)

The ``ST`` column shows the status of job allocation. For example, ``R`` is for running and ``PD`` is for pending. Other codes can be found in ``man squeue``.

Specifying the list of nodes for jobs is not good practice, as one must be sure the nodes are available. A better approach is to specify a partition to run and a quantity of nodes::

    $ srun --partition=defq --nodes=2 hostname
    node004.cluster
    node005.cluster

Partitioning is a method of organizing nodes in cluster. Usually all nodes in a given partition are homogeneous, i.e. have the same hardware configuration, same software installed, and access to the same resources, like shared filesystems.

Using sbatch
~~~~~~~~~~~~

``srun`` and ``salloc`` commands are useful when running interactive jobs. For long-running tasks, ``sbatch`` comes into play. ``sbatch`` allows a user to submit a job file into the queuing system. A job file is usually the ordinary shell script file with directives for SLURM. Directives start with ``#SBATCH`` and are usually located in the beginning of the job file. A job file may be submitted without any directives and SLURM will apply some defaults: i.e. allocate single node, put the job to a default partition, etc. Usually it is worthwhile to change such behaviour. Here is an example of a basic script::

    #!/bin/bash
    #SBATCH --partition=defq
    #SBATCH --nodes=2
    hostname

To submit a job, set content above to the ``test01.job`` file and simply run::

    $ sbatch test01.job

Please note that you might not have a defq partition configured in your cluster. Check the ``sinfo`` output.

After a job finishes, its output will appear in the home directory, titled ``slurm-3443.out``, in which 3443 is a job number.

If the job failed for some reason, the file ``slurm-3443.err`` will be created. The first file - ``.out`` - contains STDOUT from job script and ``.err`` has STDERR content. The path and name of these files can be customized::

    #SBATCH --output=/path/to/store/outputs/myjob-%J.out
    #SBATCH --error=/path/to/store/outputs/myjob-%J.err

The job number will be substituted instead of the %J variable. For more variables, please have a look at ``man sbatch``.

By default, a job assumes that the current working directory is a home dir of the user. It can be customized, specifying ``--workdir=``::

    #SBATCH --workdir=/new/home/dir/

In addition, you can specify the number of nodes, dependencies, starting time, and change many other tunables. All are described in ``man sbatch``.

Variables in job scripts
~~~~~~~~~~~~~~~~~~~~~~~~

During job execution, SLURM provides several environment variables. For logging purposes, it can be useful to tune a job to render those valuables in its output.::

    #!/bin/bash
    #SBATCH --partition=defq
    #SBATCH --nodes=2

    echo "Job is running on ${SLURM_JOB_NUM_NODES} nodes"
    echo "Allocated nodes are: ${SLURM_JOB_NODELIST}"

The output will contain::

    $ cat slurm-3444.out
    Job is running on 2 nodes
    Allocated nodes are: node[001-002]

In addition, more than 100 variables are available. For reference, please run ``man sbatch``.


Srun and mpirun in job scripts
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Usually, it is unnecessary to use srun in job scripts. Spawning multiple copies of a binary is usually performed by mpi library. To get an idea of how things are working in an sbatch context you can check on the following output::

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

Please note that the ``module load`` line might differ in your environment.

The output will be similar to::

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

The number of mpirun hostnames depends on the number of cores in the nodes.

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

Now, compile the application with one of the MPI versions installed on the cluster::

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

In the output file, something like the following will appear::

    Hello world from processor node001.cluster, rank 2 out of 4 processors
    Hello world from processor node001.cluster, rank 1 out of 4 processors
    Hello world from processor node001.cluster, rank 0 out of 4 processors
    Hello world from processor node001.cluster, rank 3 out of 4 processors
    Hello world from processor node002.cluster, rank 1 out of 4 processors
    Hello world from processor node002.cluster, rank 3 out of 4 processors
    Hello world from processor node002.cluster, rank 0 out of 4 processors
    Hello world from processor node002.cluster, rank 2 out of 4 processors

You are done! You have now created and run your first MPI application on the HPC cluster.
