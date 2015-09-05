#!/bin/bash
set -x
sub=$1
stg=$2
pth=cfndata/picsl/srdas
pth=""
:<<COMM
fn=/data10/RAM/subjects/$sub/tal/VOX_coords_mother.txt
if [ -f $fn ]; then
  cp $fn VOX_coords_mother.txt
fi
fn=/home2/gorniak/$sub/VOX_coords_mother.txt
if [ -f $fn ]; then 
  cp $fn VOX_coords_mother.txt
fi
COMM
export PATH=~sudas/bin:$PATH
doall=1
fn=VOX_coords_mother.txt
CT=T01_${sub}_CT.nii.gz
segmtlT2=T00_${sub}_segmentation.nii.gz
segwb=T00_${sub}_mprage_wholebrainseg_to_T01_CT.nii.gz
segmtl=T00_${sub}_segmentation_to_T01_CT.nii.gz
segwbT1=T00_${sub}_mprage/T00_${sub}_mprage_wholebrainseg.nii.gz
snapwbfn=~sudas/bin/localization/ahead_joint/turnkey/data/WholeBrain/MICCAI-Challenge-2012-Label-Information.csv
snapmtlfn=~sudas/bin/localization/ashs_atlases/mtlatlas/snap/snaplabels.txt
snapelfnbase=~sudas/bin/localization/electrode_snaplabel_color.txt
TEMPLATE=~sudas/bin/localization/NickOasisTemplate/T_template0.nii.gz
RDIR=~sudas/bin/localization/template_to_NickOasis
faffine=$RDIR/ch22t0GenericAffine.mat
fwarp=$RDIR/ch22t1Warp.nii.gz
finversewarp=$RDIR/ch22t1InverseWarp.nii.gz

# Code for drawing sphere with -sdt and reporting percent of subfields within that
# c3d T00_R1026D_tseelectrodelabels_spheres.nii.gz -thresh 37 37 1 0 -sdt -thresh -1 1 1 0 -o testblob.nii.gz -as A T00_R1026D_segmentation.nii.gz -times -insert A 1 -lstat

if [ $stg  == 1 ]; then

# Transform whole brain segmentation into CT space
if [ ! -f  T00_${sub}_mprage_wholebrainseg_to_T01_CT.nii.gz ] || [ $doall == 1 ]; then
  c3d T01_${sub}_CT.nii.gz  T00_${sub}_mprage/T00_${sub}_mprage_wholebrainseg.nii.gz -interp NN -reslice-matrix T01_CT_to_T00_mprageANTs0GenericAffine_RAS_inv.mat -o T00_${sub}_mprage_wholebrainseg_to_T01_CT.nii.gz
  c3d_affine_tool T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat -oitk T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt
fi
if [ ! -f T01_CT_to_T00_tseANTs_RAS_inv_itk.txt ] || [ $doall == 1 ]; then
  c3d_affine_tool  T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat T00_tse_to_T00_mprageANTs0GenericAffine_RAS.mat -inv  -mult \
    -o T01_CT_to_T00_tseANTs_RAS.mat -oitk T01_CT_to_T00_tseANTs_RAS_itk.txt \
    -inv -o T01_CT_to_T00_tseANTs_RAS_inv.mat -oitk T01_CT_to_T00_tseANTs_RAS_inv_itk.txt
fi

# Get the electrode information from voxtool output
elnames=($(cat $fn | awk '{print $1}')) 
elxs=($(cat $fn | awk '{print $2}')) 
elys=($(cat $fn | awk '{print $3}')) 
elzs=($(cat $fn | awk '{print $4}')) 

if [ ! -f electrode_snaplabel.txt ] || [ $doall == 1 ]; then
# Make SNAP label file for electrodes 
cp $snapelfnbase tmp.txt
for ((i=1;i<=${#elnames[*]};i++)); do
  el=$(cat VOX_coords_mother.txt | sed -n "${i}p" | awk '{print $1}'); 
  cat tmp.txt | sed -e "s/\"Label ${i}\"/\"${el}\"/g" > tmp1.txt; 
  mv tmp1.txt tmp.txt;
  if [ $i != 1 ]; then
    elname_num=$(echo $el | sed -e 's/[^0-9]//g')
    elname_str=${el%${elname_num}}
    prevelname_num=$(echo $prevel | sed -e 's/[^0-9]//g')
    prevelname_str=${prevel%${prevelname_num}}
    if [ "$elname_str" == "$prevelname_str" ]; then
      midel="$prevel - $el"
      midlabel=$(echo "${#elnames[*]} + ${i} -1 " | bc -l )
      cat tmp.txt | sed -e "s/\"Label ${midlabel}\"/\"${midel}\"/g" > tmp1.txt; 
      mv tmp1.txt tmp.txt;
    fi
  fi
  prevel=$el
done
mv tmp.txt electrode_snaplabel.txt
fi

# Initialize the label files
# Label files from ASHS MTL segmentation
> mtllabels.csv
# Label files from whole brain segmentation
> wholebrainlabels.csv
# Label files combining MTL and whole brain segmentations
> electrodelabels.csv
> vox_coords.txt

doel=0
# Initialize image with electrode labels at voxels from voxtool output
#:<<'COMM'
if [ ! -f T01_${sub}_electrodelabels.nii.gz ] || [ $doall == 1 ]; then
  doel=1
  # c3d $CT -dup -scale -1 -add -o T01_${sub}_electrodelabels.nii.gz
fi

#**************************not doing old style***********
doel=0
# For each contact identified in voxtool
for ((i=0;i<${#elnames[*]};i++)); do
  el=${elnames[i]}
  x=$(expr ${elxs[i]} - 1 )
  if [ -f flippedCT.flag ]; then
    x=$(expr 512 - ${elxs[i]} - 1 )
  fi
  y=$(expr ${elys[i]} - 1 )
  z=$(expr ${elzs[i]} - 1 )


  # Add voxe