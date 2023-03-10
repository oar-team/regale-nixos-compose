# Introduction

This composition proposes an environment with EAR and OAR. [NAS Parallel Benchmarks](https://www.nas.nasa.gov/software/npb.html) are provided and compiled with gcc in MPI and OpenMP variants.

# Main Steps
See main [README](../README.md) for more information about setting.

## Build
```bash
oarsub -I
cd regale-nixos-compose/ear
nxc build
```

## Deploy
Nodes requirements: **5 nodes**
```bash
export $(oarsub -l cluster=1/nodes=5,walltime=2:0 "$(nxc helper g5k_script) 2h" | grep OAR_JOB_ID)
nxc start -m ./OAR.$OAR_JOB_ID.stdout -W
nxc connect
```
**Note:** *cluster=1* in the oarsub request allows to   
**Remainder:** *nxc connect* is based on tmux look at its manual for usefull key bindings.

## Use
### 
```bash
#
# On frontend
#
su user1
cd

# interactive job
oarsub -I -l nodes=2

# launch NAS Parallel Benchmark CG
mpirun --hostfile $OAR_NODEFILE -mca pls_rsh_agent oarsh -mca btl tcp,self \
    -x LD_PRELOAD=${EAR_INSTALL_PATH}/lib/libearld.so \
    -x OAR_EAR_LOAD_MPI_VERSION=ompi \
    -x OAR_EAR_LOADER_VERBOSE=4 \
    -x OAR_STEP_NUM_NODES=$(uniq $OAR_NODEFILE | wc -l) \
    -x OAR_JOB_ID=$OAR_JOB_ID \
    -x OAR_STEP_ID=0 \
    cg.C.mpi

# terminate job
exit # or Ctrl-D

# passive job
# use ear-mpirun script which executes essentially the same above mpirun command
oarsub -l nodes=2 "ear-mpirun cg.C.mpi"

# After some lapse of time
ereport
eacct

# On server
# to explore the database
# on server
#
mysql -D ear
select * from Jobs;
select * from Applications;
select * from Signatures;
```
