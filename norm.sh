#!/bin/bash
#$ -S /bin/bash
#./ProcessADNISubject.sh $OUTDIR/../../${tp}_${sub}_mprage.nii.gz $OUTDIR/ $sub

sub=$1
FILE=$PWD/T00_${sub}_mprage.nii.gz
OUT_DIR=$PWD/T00/thickness/
mkdir -p $OUTDIR
BASENAME=`basename $FILE .nii.gz` 
TEMPLATE_DIR=~sudas/bin/localization/NickOasisTemplate
export ANTSPATH=~sudas/bin/localization/ants_avants_Dec162013/

${ANTSPATH}antsCorticalThickness.sh -d 3 \
  -a $FILE \
  -e ${TEMPLATE_DIR}/T_template0.nii.gz \
  -m ${TEMPLATE_DIR}/T_template0ProbabilityMask.nii.gz \
  -p ${TEMPLATE_DIR}/Priors2/priors%d.nii.gz \
  -f ${TEMPLATE_DIR}/T_template0ExtractionMask.nii.gz \
  -t ${TEMPLATE_DIR}/T_template0SkullStripped.nii.gz \
  -w 0.25  \
  -o ${OUT_DIR}${sub}
#  -t ${TEMPLATE_DIR}template_brain.nii.gz \
#  -t ${TEMPLATE_DIR}template.nii.gz \

