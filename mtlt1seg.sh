#!/bin/bash 
 set -x

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


export HIPPOSPM_ROOT=~sudas/bin/scripts/scripts/hippospm/bash
MATLABROOT=/usr/global/matlabR2011b
export PATH=~sudas/bin:$PATH
export LD_LIBRARY_PATH=/home1/sudas/lib64:/home1/sudas/libs/icclibs:/home1/sudas/libs:$LD_LIBRARY_PATH

IDS=($sid)


for ((i=0;i<${#IDS[*]};i++)); do
  id=${IDS[i]}
  tp=T00
  scan=$tp

  SEGR=$RAMROOT/$id/$tp/hippseg/${tp}_${id}_hippseg_R.nii.gz
  SEGL=$RAMROOT/$id/$tp/hippseg/${tp}_${id}_hippseg_L.nii.gz


    BASELINE=$RAMROOT/$id/${tp}_${id}_mprage.nii.gz
    WORK=$RAMROOT/$id/$tp/hippseg

    SEGBOTH=$RAMROOT/$id/$tp/hippseg/${tp}_${id}_mprage/${tp}_${id}_mprage_wholebrainseg.nii.gz
    if [ -f $SEGBOTH ]; then 
      c3d $SEGBOTH -as A -thresh 1 1 1 0 -o $SEGL -push A -thresh 2 2 1 0 -o $SEGR
      $HIPPOSPM_ROOT/hippo_spm_main.sh \
        -g $BASELINE \
        -m $MATLABROOT \
        -e $HIPPOSPM_ROOT/dummyepi \
        -w $WORK \
        -I $i \
        -k bold \
        -p $SEGR \
        -j $SEGL \
        -s 0-2 -o &
    else
      echo "Segmentation $SEGBOTH not present: $id $tp"
      exit 1
    fi


done
