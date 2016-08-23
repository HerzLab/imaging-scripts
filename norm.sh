#!/bin/bash
#$ -S /bin/bash
#./ProcessADNISubject.sh $OUTDIR/../../${tp}_${sub}_mprage.nii.gz $OUTDIR/ $sub


sub=$1
FILE=$PWD/T00_${sub}_mprage.nii.gz
OUT_DIR=$PWD/T00/thickness/
mkdir -p $OUT_DIR
BASENAME=`basename $FILE .nii.gz` 
TEMPLATE_DIR=~sudas/bin/localization/NickOasisTemplate
export ANTSPATH=~sudas/bin/localization/ants_avants_Dec162013/
RDIR=~sudas/bin/localization/template_to_NickOasis
faffine=$RDIR/ch22t0GenericAffine.mat
fwarp=$RDIR/ch22t1Warp.nii.gz
finversewarp=$RDIR/ch22t1InverseWarp.nii.gz
CH2=~sudas/DARPA/ch2.nii.gz


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

cd $OUT_DIR/../..
fn_mono=/data/eeg/$sub/tal/VOX_coords_mother_dykstra.txt
fn_bi=/data/eeg/$sub/tal/VOX_coords_mother_dykstra_bipolar.txt
fn=updated_vox_coords.txt

cat $fn_mono $fn_bi > $fn


elnames=($(cat $fn | awk '{print $1}'))
elxs=($(cat $fn | awk '{print $2}'))
elys=($(cat $fn | awk '{print $3}'))
elzs=($(cat $fn | awk '{print $4}'))

cat $fn | awk '{print $1}' > updated_names.txt

> flipped_${fn}

for ((i=0;i<${#elnames[*]};i++)); do
  el=${elnames[i]}
  x=$(expr ${elxs[i]}  )
  if [ -f flippedCT.flag ]; then
    x=$(expr 512 - ${elxs[i]}  )
  fi
  y=$(expr ${elys[i]}  )
  z=$(expr ${elzs[i]}  )


  # Add voxel coordinates to a file so that we can transform to physical coordinates later
  echo $x $y $z >> flipped_${fn}

done

sub=$1
fn=T01_${sub}_CT.nii
c3d ${fn}.gz -o ${fn}
echo "x,y,z,t,label,mass,volume,count" > flipped_updated_electrode_coordinates.csv
MATLAB_ROOT=/usr/global/matlabR2011b
#$ -v LM_LICENSE_FILE=/usr/global/lmgrd-R2015a/licenses/network.lic.rhino2
$MATLAB_ROOT/bin/matlab $MATOPT -nodisplay <<MAT
  addpath ~sudas/bin/spm5
  addpath ~sudas/bin/localization/matlab
  coords=importdata('flipped_updated_vox_coords.txt');
  coords=coords';
  pcoords=map_coords(coords,'${fn}');
  V=spm_vol('${fn}');
  voxvol=abs(prod(diag(V.mat)));
  fd=fopen('flipped_updated_electrode_coordinates.csv', 'a');
  for i=1:size(pcoords, 2)
    fprintf(fd, '%f,%f,%f,%d,%d,%d,%f,%d', -pcoords(1, i), -pcoords(2, i), pcoords(3, i),0, i, i, voxvol, 1);
    fprintf(fd, '\n');
  end
  fclose(fd);
  exit
MAT
rm -f ${fn}
if [ ! -f T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt ]; then
  c3d_affine_tool T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat -oitk T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt
fi

~sudas/bin/ants/antsApplyTransformsToPoints -d 3 -i flipped_updated_electrode_coordinates.csv -o flipped_updated_electrode_coordinates_mni.csv \
  -t [T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt,1] -t [T00/thickness/${sub}TemplateToSubject0GenericAffine.mat,1]\
  -t T00/thickness/${sub}TemplateToSubject1InverseWarp.nii.gz -t [$faffine,1] -t $finversewarp
cat flipped_updated_electrode_coordinates_mni.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3}' OFS=',' > test.csv
mv test.csv flipped_updated_electrode_coordinates_mni.csv

paste -d "," updated_names.txt flipped_updated_electrode_coordinates_mni.csv > monopolar_bipolar_updated_mni.csv

