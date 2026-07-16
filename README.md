# SLURM-tools
*Author: [Marco A. Villena](https://www.marcoavillena.com/)*

In this repository, you can find some tools designed to easily track and manage the submitted jobs in SLURM.

## JOB EXPLORER

Interactive helper script to explore and manage your Slurm jobs from the terminal.

### Overview

`jobexplorer.sh` provides an interactive and friendly menu to inspect, monitor, and cancel Slurm jobs, as well as to query job history and user job statistics.  
It is intended for users of clusters managed by Slurm and uses ANSI colors for improved readability in a terminal.

> [!NOTE]
> Certain functions in this script may work differently or be blocked by HPC administrators. Therefore, you may need to make some modifications to the code yourself. The *HPCNAME* variable is used to distinguish between different versions of this script for each HPC.

### Features

The main menu shows the following options:

1. **Display status of your jobs**: Shows a detailed list of your current jobs as a table showing the following columns: *job ID, job name, state, used time, account, and reason*.
2. **Check in loop**: Shows similar information to the previous option, but periodically refreshing it. The user can define the time elapsed in seconds.
3. **Cancel a job**: Allows the cancellation of one specific job from the job-submitted list.
4. **Cancel all jobs**: Cancels all submitted jobs.
5. **Jobs folders**: Prints a table with job ID, job name and working directory of your queued jobs. 
6. **Jobs record**: Runs `sacct -u $USER` to show the accounting records of your jobs (finished and running).
7. **Job statistic**: Shows a detailed list of your jobs including node list with `squeue -u $USER -l -O obid,jobarrayid,name,state,timeused,nodelist`. Prompts for a job ID and calls `sstat <jobid>` to display runtime statistics for that job.
8. **Partition options >>**
   1. **Partitions available**: Show the partitions avaialble for your user.
   2. **Partition load (aprox.)**: Shows the load of each partition of the HPC.
   3. **User and partititon**: Show the information related to the number of jobs submitted in each partition by each user.
   4. **User and jobs (slow)**: Shows a summary of the queue of the cluster. Counts, for each user, the number of jobs in the states *RUNNING*, *PENDING*, *COMPLETING*, and groups all other states into *OTHER*.
9. **Tools >>**
   1. **Submission file generator (*beta*)**: Tool for helping to create submission files.
   2. **Search for tool in module list**: Look for the name of a tool in the module available list.
   3. **No kick-out**: Toy to prevent the system from closing the connection due to inactivity.

### Requirements

- Bash shell.  
- Slurm client commands available in PATH: `squeue`, `scancel`, `sacct`, `sacctmgr`, `sstat`, `sinfo`.  
- A terminal that supports ANSI escape sequences for colors (optional but recommended).

The script assumes a typical Slurm environment where the current user is identified by `$USER`.

### Installation suggestions

1. Create a new folder called `jobexplorer` to a directory of your choice. For example `$HOME/bin/jobexplorer`.
2. Copy all files from this repository in that folder.
3. Make it executable: ```chmod +x *.sh```
4. Add to `.bashrc` file the following variable and reload the file:
   1. ```echo 'export JOBEXPLORERPATH="$HOME/bin/jobexplorer"' >> ~/.bashrc```
   2. ```echo 'export MYEMAIL="mavillena@ugr.es"' >> ~/.bashrc```
   3. ```source ~/.bashrc```
5. Create a new alias in your .bashrc file (or equivalent) for this new tool. For example ```alias explorer="sh JOBEXPLORERPATH/jobexplorer.sh"```
6. Fill out the file `partitions.info` with the information related to the partitions of the HPC you are using.

## NOKICKOUT

Small toy utility script to periodically update terminal activity and avoid idle disconnections if the cluster has a limit on the connection time without activity.

### Overview

`nokickout.sh` prints a timestamp at fixed intervals or runs an animation, continuously refreshing the terminal.
This behavior can help keep interactive sessions alive on systems that disconnect inactive terminals and can be used to display simple animated frames.

### Features
- In the **default mode**, periodic timestamp printing in the terminal using the *Europe/Madrid* time zone.
- In the **Animation mode**,  an animation is shown as an infinite loop on the screen. This mode required the folder *frames*.

### Usage

* **Basic mode (default)**: Without arguments (`sh nokickout.sh`).
* **Animation mode**: With the *-w* option (`sh nokickout.sh -w`).

### Requirements
- Bash shell.
- A terminal that supports ANSI escape sequences for color.
- For *Animation mode*: a directory called *frames* containing all frames from the animation.
   - The frame files hace extension *.frm.
   - These file are text files with each frame of the animation using ASCII images.

### Installation suggestions
1. Copy `nokickout.sh` to a directory of your choice, for example, `$HOME/bin`.
2. Copy the `frame` folder to the same directory.
2. Make it executable: ```chmod +x nokickout.sh```.
3. Create a new alias in your *.bashrc* file (or equivalent) for this new tool. For example ```alias nokickout="sh $HOME/bin/nokickout.sh"```.
