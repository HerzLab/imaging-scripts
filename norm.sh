#!/bin/bash
#$ -S /bin/bash
#./ProcessADNISubject.sh $OUTDIR/../../${tp}_${sub}_mprage.nii.gz $OUTDIR/ $sub
set -x

sub=$1
FILE=$PWD/T00_${sub}_mprage.nii.gz
OUT_DIR=$PWD/T00/thickness/
mkdir -p $OUT_DIR
BASENAME=`basename $FILE .nii.gz` 
TEMPLATE_DIR=/oceanus/collab/herz-lab/processing_code/bin/localization/NickOasisTemplate
export ANTSPATH=/oceanus/collab/herz-lab/processing_code/bin/localization/ants_avants_Dec162013/
RDIR=/oceanus/collab/herz-lab/processing_code/bin/localization/template_to_NickOasis
faffine=$RDIR/ch22t0GenericAffine.mat
fwarp=$RDIR/ch22t1Warp.nii.gz
finversewarp=$RDIR/ch22t1InverseWarp.nii.gz
CH2=/oceanus/collab/herz-lab/processing_code/bin/localization/ch2.nii.gz


if [ ! -f $OUT_DIR/${sub}CorticalThicknessNormalizedToTemplate.nii.gz ]; then
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
fi

if [ ! -f $OUT_DIR/${sub}CorticalThicknessNormalizedToTemplate.nii.gz ]; then
  echo "$sub MNI normalization and thickness pipeline incomplete.."
  exit 1
else
  echo "$sub MNI normalization and thickness pipeline done"
fi

