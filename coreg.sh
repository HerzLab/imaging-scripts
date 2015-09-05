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

export ANTSPATH=~sudas/bin/ants/
export PATH=~sudas/bin:$PATH
reg=${ANTSPATH}antsRegistration
dim=3

oldcwd=$PWD
cd $RAMROOT/${1}
export PATH=$ANTSPATH:~sudas/bin:$PATH

f=T00_${1}_mprage.nii.gz
m=T00_${1}_tse.nii.gz
if [ -f T00_${1}_tse.nii.gz ]; then
    $reg -d $dim  \
      -m Mattes[  $f, $m , 1 , 32, random , 0.1 ] \
      -t Rigid[ 0.2 ] \
      -c [1000x1000x1000,1.e-7,20]  \
      -s 4x2x0  \
      -f 4x2x1 -l 1 \
      -r [ $f, $m, 1 ] \
      -a 1 \
      -o [ T00_tse_to_T00_mprageANTs , T00_tse_to_T00_mprageANTs.nii.gz, T00_tse_to_T00_mprageANTs_inverse.nii.gz ]
    ~sudas/bin/ConvertTransformFile 3 T00_tse_to_T00_mprageANTs0GenericAffine.mat \
        T00_tse_to_T00_mprageANTs0GenericAffine_RAS.mat --hm
fi

f=T00_${1}_mprage.nii.gz
m=T01_${1}_CT.nii.gz
    $reg -d $dim  \
      -m Mattes[  $f, $m , 1 , 32, random , 0.1 ] \
      -t Rigid[ 0.2 ] \
      -c [1000x1000x1000,1.e-7,20]  \
      -s 4x2x0  \
      -r [ $f, $m, 1 ] \
      -f 4x2x1 -l 1 \
      -a 1 \
      -o [ T01_CT_to_T00_mprageANTs , T01_CT_to_T00_mprageANTs.nii.gz, T01_CT_to_T00_mprageANTs_inverse.nii.gz ]
~sudas/bin/ConvertTransformFile 3 T01_CT_to_T00_mprageANTs0GenericAffine.mat \
        T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat --hm
#c3d_affine_tool  T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat  -itk T00/sfseg/flirt_t2_to_t1/flirt_t2_to_t1_ITK.txt -inv  -mult -o T01_CT_to_T00_tseANTs_RAS.mat -inv -o T01_CT_to_T00_tseANTs_RAS_inv.mat
# Use ANTs for T1-T2
c3d_affine_tool  T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat T00_tse_to_T00_mprageANTs0GenericAffine_RAS.mat -inv  -mult \
  -o T01_CT_to_T00_tseANTs_RAS.mat -oitk T01_CT_to_T00_tseANTs_RAS_itk.txt \
  -inv -o T01_CT_to_T00_tseANTs_RAS_inv.mat -oitk T01_CT_to_T00_tseANTs_RAS_inv_itk.txt


# Change for Penn subjects
c3d T00/sfseg/final/${1}_left_lfseg_corr_nogray.nii.gz T00/sfseg/final/${1}_right_lfseg_corr_nogray.nii.gz -add -o T00_${1}_segmentation.nii.gz
c3d T00_${1}_mprage.nii.gz -resample 250% -as A T00/hippseg/hippo_spm/sbn_work_hipp_L/hipp_hires_seg.nii.gz -interp NN -reslice-identity \
  -push A T00/hippseg/hippo_spm/sbn_work_hipp_R/hipp_hires_seg.nii.gz -interp NN -reslice-identity -add  -trim 5mm -o T00/hippseg/hippo_spm/T00_${1}_sbnseg.nii.gz 
c3d T00/hippseg/hippo_spm/T00_${1}_sbnseg.nii.gz T00_${1}_mprage.nii.gz -reslice-identity -o T00/hippseg/hippo_spm/T00_${1}_medres.nii.gz
#c3d T00/sfseg/final/TLE05_S1_left_lfseg_corr_nogray.nii.gz T00/sfseg/final/TLE05_S1_right_lfseg_corr_nogray.nii.gz -add -o T00_${1}_segmentation.nii.gz
c3d T00_${1}_tse.nii.gz T01_${1}_CT.nii.gz -reslice-matrix T01_CT_to_T00_tseANTs_RAS.mat -o T01_${1}_CT_to_T00_tseANTs.nii.gz
c3d T00_${1}_tse.nii.gz -resample 100x100x500% -o T00_${1}_tse_highres.nii.gz T01_${1}_CT.nii.gz -reslice-matrix T01_CT_to_T00_tseANTs_RAS.mat -o T01_${1}_CT_to_T00_tseANTs_highres.nii.gz
c3d T01_${1}_CT.nii.gz T00_${1}_tse.nii.gz -reslice-matrix T01_CT_to_T00_tseANTs_RAS_inv.mat -o T00_${1}_tse_to_T01_CTANTs.nii.gz
c3d T00_${1}_segmentation.nii.gz -int NN -resample 100x100x500% -o T00_${1}_segmentation_highresNN.nii.gz
c3d T01_${1}_CT_to_T00_tseANTs_highres.nii.gz -popas A T00_${1}_segmentation.nii.gz -split -foreach -smooth 0.5vox -insert A 1 -reslice-identity -endfor -merge \
  -o T00_${1}_segmentation_highres.nii.gz
#c3d T01_${1}_CT.nii.gz -popas A T00/sfseg/final/TLE05_S1_left_lfseg_corr_nogray.nii.gz T00/sfseg/final/TLE05_S1_right_lfseg_corr_nogray.nii.gz -add -o T00_${1}_segmentation.nii.gz \
c3d T01_${1}_CT.nii.gz -popas A T00/sfseg/final/${1}_left_lfseg_corr_nogray.nii.gz T00/sfseg/final/${1}_right_lfseg_corr_nogray.nii.gz -add -o T00_${1}_segmentation.nii.gz \
  -split -foreach -smooth 0.5vox -insert A 1 -reslice-matrix T01_CT_to_T00_tseANTs_RAS_inv.mat -endfor -merge \
  -o T00_${1}_segmentation_to_T01_CT.nii.gz


c3d_affine_tool  T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat  -inv -o T01_CT_to_T00_mprageANTs0GenericAffine_RAS_inv.mat
c3d T01_${1}_CT.nii.gz  T00_${1}_mprage/T00_${1}_mprage_wholebrainseg.nii.gz -interp NN -reslice-matrix T01_CT_to_T00_mprageANTs0GenericAffine_RAS_inv.mat -o T00_${1}_mprage_wholebrainseg_to_T01_CT.nii.gz
c3d T01_${1}_CT.nii.gz  T00/hippseg/hippo_spm/T00_${1}_sbnseg.nii.gz -interp NN -reslice-matrix T01_CT_to_T00_mprageANTs0GenericAffine_RAS_inv.mat -o T00_${1}_sbnseg_to_T01_CT.nii.gz

#ANTS

if [ -f T01_${1}_mprage.nii.gz ]; then
  f=T01_${1}_mprage.nii.gz
  m=T01_${1}_CT.nii.gz
    $reg -d $dim  \
      -m Mattes[  $f, $m , 1 , 32, random , 0.1 ] \
      -t Rigid[ 0.2 ] \
      -c [1000x1000x1000,1.e-7,20]  \
      -s 4x2x0  \
      -f 4x2x1 -l 1 \
      -r [ $f, $m, 1 ] \
      -a 1 \
      -o [ T01_CT_to_T01_mprageANTs , T01_CT_to_T01_mprageANTs.nii.gz, T01_CT_to_T01_mprageANTs_inverse.nii.gz ]
  ~sudas/bin/ConvertTransformFile 3 T01_CT_to_T01_mprageANTs0GenericAffine.mat \
        T01_CT_to_T01_mprageANTs0GenericAffine_RAS.mat --hm


  c3d_affine_tool  T01_CT_to_T01_mprageANTs0GenericAffine_RAS.mat  -inv -o T01_CT_to_T01_mprageANTs0GenericAffine_RAS_inv.mat

fi
cd $oldcwd
