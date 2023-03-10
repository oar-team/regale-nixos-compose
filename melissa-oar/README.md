# Introduction

This composition proposes an environment with Melissa and OAR. [NAS Parallel Benchmarks](https://www.nas.nasa.gov/software/npb.html) are provided and compiled with gcc in MPI and OpenMP variants.

# Main Steps
See main [README](../README.md) for more information about setting.

## Build
```bash
oarsub -I
cd regale-nixos-compose/melissa-oar
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

# terminate job
exit # or Ctrl-D

```
