#!/bin/bash 
# set -x

if [ -z $RAMROOT ]; then
  echo "Please define RAMROOT to point to the top level image analysis directory"
  exit 1
fi

if [ $# != 1 ]; then
  echo Usage: $0 SubjectID
  exit 1
fi

# Subject id passed on the command line
sid=$1

AHEAD_ROOT=~sudas/bin/localization/ahead_joint/turnkey

IDS=($sid)


for ((i=0;i<${#IDS[*]};i++)); do
  id=${IDS[i]}
  TP=T00

    MPRAGE_PREF=${TP}_${id}_mprage

      WAIT=TRUE
      while [ "$WAIT" == "TRUE" ]; do
        Njobs=`qstat | grep ah  | wc -l`
        if [ $Njobs -lt 20 ]; then
          WAIT=FALSE
          echo $Njobs jobs running, will run subject $id
        else
          echo $Njobs jobs running, will wait subject $id
          sleep 60
        fi
      done
      echo "Running ahead: $id $TP"
 
    subdir=$RAMROOT/$id
    mkdir -p $subdir/${TP}_${id}_mprage/dump

    #  qsub -l h_vmem=10.1G,s_vmem=10G -j y -o $subdir/${TP}_${i}_mprage/dump -V -N ah"$(echo ${i} | sed -e 's/_S_//g')" \
# /home/srdas/bin/ahead_joint/turnkey/bin/hippo_seg_WholeBrain_itkv4_v3.sh $subdir $subdir  ${TP}_${i}_mprage  /home/srdas/bin/ahead_joint/turnkey/data/WholeBrain 1 &
  $AHEAD_ROOT/bin/hippo_seg_WholeBrain_itkv4_v3.sh $subdir $subdir  $MPRAGE_PREF  $AHEAD_ROOT/data/WholeBrain 0 &
  sleep 1

done
