#!/bin/bash 
# set -x

mail_result() {
    if [ #? == 0 ] ;then
      result='was successful'
    else
       result='failed'
    fi
    message="Whole-brain segmentation for subject ${1} ${result}"
    echo $message | mail -s "Whole-brain segmentation" -r ${USER}@rhino2.psych.upenn.edu ${2}
}


if [ -z $RAMROOT ]; then
  echo "Please define RAMROOT to point to the top level image analysis directory"
  exit 1
fi

if [ $# != 1 ]; then
  echo Usage: $0 [-M email_address] SubjectID
  exit 1
fi

while getopts ":M:" opt; do
    case ${opt} in
    M )
        shift $((OPTIND-1))
        mail_str="mail_result ${1} ${OPTARG}"
        ;;
    \?) ;;
    \:) ;;
    esac
done

suff=""
# Subject id passed on the command line
sid=$1

# ASHS_ROOT=~sudas/bin/localization/ashs-fastashs
# ATLAS=~sudas/bin/localization/ashs_atlases/mtlatlas-ashs-fast
ASHS_ROOT=~sudas/bin/localization/ashs
ATLAS=~sudas/bin/localization/ashs_atlases/mtlatlas
export ASHS_ROOT

IDS=($sid)


for ((i=0;i<${#IDS[*]};i++)); do
  id=${IDS[i]}
  tp=T00
  scan=$tp
  # for scan in T00 T01; do
    WDIR=$RAMROOT/${id}/${scan}/sfseg

    MPRAGE=${RAMROOT}/${id}/${scan}_${id}_mprage.nii.gz
    TSE=${RAMROOT}/${id}/${scan}_${id}_tse.nii.gz

    # rm -rf $WDIR
    if [ -f $TSE ]; then
      #if [ ! -f $WDIR/final/${id}_right_lfseg_corr_nogray.nii.gz ]; then
       if [ TRUE ]; then
      WAIT=TRUE
      while [ "$WAIT" == "TRUE" ]; do
        Njobs=`qstat | grep ad  | wc -l`
        if [ $Njobs -lt 20 ]; then
          WAIT=FALSE
          echo $Njobs jobs running, will run subject $id
        else
          echo $Njobs jobs running, will wait subject $id
          sleep 60
        fi
      done
      echo "Running ashs: $id $tp"
      mkdir -p $WDIR/dump

#     qsub -q RAM.q -j y -o $WDIR/dump -cwd -V -N ad"$(echo ${id} | sed -e 's/_S_//g')" \
      { $ASHS_ROOT/bin/ashs_main.sh \
        -Q -q "-q RAM.q -l h_vmem=10.1G,s_vmem=10G" \
        -N -a $ATLAS -s 0-7 -d -T -I $id -g $MPRAGE -f $TSE -w $WDIR ; eval ${mail_str};} &

# -N
# -Q -q "-l h_vmem=7.1G,s_vmem=7G" \

      else
        echo "Output file exists: $id $tp"
      fi
    else
      echo "Image $TSE not present: $id $tp"
    fi

done
