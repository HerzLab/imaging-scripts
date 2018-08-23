#!/bin/bash 
 set -x

if [ -z $RAMROOT ]; then
  echo "Please define RAMROOT to point to the top level image analysis directory"
  exit 1
fi

USEMANUAL=false
if [ $# -lt 1 ]; then
  echo Usage: $0 SubjectID [ISREG] [MANUALTransformFile]
  exit 1
fi
if [ $# -eq 2 ]; then
  echo "Not doing registration"
  NOREG=true
else
  NOREG=false
fi
if [ $# -eq 3 ]; then
  echo "Using manual registration"
  NOREG=false
  USEMANUAL=true
  MANMAT=$3
fi

export ANTSPATH=~sudas/bin/ants/
export PATH=~sudas/bin:$PATH
reg=${ANTSPATH}antsRegistration
dim=3
segtype=corr_nogray
# segtype=heur


oldcwd=$PWD
cd $RAMROOT/${1}
export PATH=$ANTSPATH:~sudas/bin:$PATH
if $NOREG ; then
  :
else
:
  if $USEMANUAL; then
    c3d_affine_tool -itk $MANMAT -o T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat \
      -inv -o T01_CT_to_T00_mprageANTs0GenericAffine_RAS_inv.mat
    c3d T00_${1}_mprage.nii.gz T01_${1}_CT.nii.gz -reslice-matrix T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat -o T01_CT_to_T00_mprageANTs.nii.gz 
    c3d T01_${1}_CT.nii.gz T00_${1}_mprage.nii.gz -reslice-matrix T01_CT_to_T00_mprageANTs0GenericAffine_RAS_inv.mat -o T01_CT_to_T00_mprageANTs_inverse.nii.gz
  else


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
        -a 1 $mask \
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

:<<'NORUN'
  f=T00_${1}_mprage.nii.gz
  m=T01_${1}_CT.nii.gz
    $reg -d $dim  \
      -m Mattes[  $f, $m , 1 , 32, random , 0.1 ] \
      -t Rigid[ 0.2 ] \
      -c [1000x1000x1000,1.e-7,20]  \
      -s 4x2x0  \
      -r [snap.txt] \
      -f 4x2x1 -l 1 \
      -a 1 \
      -o [ T01_CT_to_T00_mprageANTs_extra , T01_CT_to_T00_mprageANTs_extra.nii.gz, T01_CT_to_T00_mprageANTs_inverse_extra.nii.gz ]

NORUN

# T1-T2 manual
# c3d_affine_tool composed.mat -o T00_tse_to_T00_mprageANTs0GenericAffine_RAS.mat -inv T00_tse_to_T00_mprageANTs0GenericAffine_RAS_inv.mat

# CT manual
#  c3d_affine_tool  composed.mat -inv -o T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat -inv -o T01_CT_to_T00_mprageANTs0GenericAffine_RAS_inv.mat

# c3d_affine_tool T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat -o T01_CT_to_T00_mprageANTs0GenericAffine_RAS_orig.mat -itk snap.txt -mult -o T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat \
#  -inv -o T01_CT_to_T00_mprageANTs0GenericAffine_RAS_inv.mat

# When we generate tx outside
#  c3d T00_${1}_mprage.nii.gz T01_${1}_CT.nii.gz -reslice-matrix T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat -o T01_CT_to_T00_mprageANTs.nii.gz 
#  c3d T01_${1}_CT.nii.gz T00_${1}_mprage.nii.gz -reslice-matrix T01_CT_to_T00_mprageANTs0GenericAffine_RAS_inv.mat -o T01_CT_to_T00_mprageANTs_inverse.nii.gz

# cp T01_CT_to_T00_mprageANTs_extraCollapsedComposite.h5 T01_CT_to_T00_mprageANTs_CollapsedComposite.h5
# cp T01_CT_to_T00_mprageANTs_extraCollapsedInverseComposite.h5 T01_CT_to_T00_mprageANTs_CollapsedInverseComposite.h5
# cp T01_CT_to_T00_mprageANTs_extra0GenericAffine.mat T01_CT_to_T00_mprageANTs_0GenericAffine.mat
# cp T01_CT_to_T00_mprageANTs_extra.nii.gz T01_CT_to_T00_mprageANTs.nii.gz
# cp T01_CT_to_T00_mprageANTs_inverse_extra.nii.gz T01_CT_to_T00_mprageANTs_inverse.nii.gz
  fi

fi
# Use ANTs for T1-T2
c3d_affine_tool  T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat T00_tse_to_T00_mprageANTs0GenericAffine_RAS.mat -inv  -mult \
  -o T01_CT_to_T00_tseANTs_RAS.mat -oitk T01_CT_to_T00_tseANTs_RAS_itk.txt \
  -inv -o T01_CT_to_T00_tseANTs_RAS_inv.mat -oitk T01_CT_to_T00_tseANTs_RAS_inv_itk.txt


# May change segtype for Penn subjects
c3d T00/sfseg/final/${1}_left_lfseg_${segtype}.nii.gz T00/sfseg/final/${1}_right_lfseg_${segtype}.nii.gz -add -o T00_${1}_segmentation.nii.gz
c3d T00_${1}_mprage.nii.gz -resample 250% -as A T00/hippseg/hippo_spm/sbn_work_hipp_L/hipp_hires_seg.nii.gz -interp NN -reslice-identity \
  -push A T00/hippseg/hippo_spm/sbn_work_hipp_R/hipp_hires_seg.nii.gz -interp NN -reslice-identity -add  -trim 5mm -o T00/hippseg/hippo_spm/T00_${1}_sbnseg.nii.gz 
c3d T00/hippseg/hippo_spm/T00_${1}_sbnseg.nii.gz T00_${1}_mprage.nii.gz -reslice-identity -o T00/hippseg/hippo_spm/T00_${1}_medres.nii.gz
#c3d T00/sfseg/final/TLE05_S1_left_lfseg_${segtype}.nii.gz T00/sfseg/final/TLE05_S1_right_lfseg_${segtype}.nii.gz -add -o T00_${1}_segmentation.nii.gz
c3d T00_${1}_tse.nii.gz T01_${1}_CT.nii.gz -reslice-matrix T01_CT_to_T00_tseANTs_RAS.mat -o T01_${1}_CT_to_T00_tseANTs.nii.gz
c3d T00_${1}_tse.nii.gz -resample 100x100x500% -o T00_${1}_tse_highres.nii.gz T01_${1}_CT.nii.gz -reslice-matrix T01_CT_to_T00_tseANTs_RAS.mat -o T01_${1}_CT_to_T00_tseANTs_highres.nii.gz
c3d T01_${1}_CT.nii.gz T00_${1}_tse.nii.gz -reslice-matrix T01_CT_to_T00_tseANTs_RAS_inv.mat -o T00_${1}_tse_to_T01_CTANTs.nii.gz
c3d T00_${1}_segmentation.nii.gz -int NN -resample 100x100x500% -o T00_${1}_segmentation_highresNN.nii.gz
c3d T01_${1}_CT_to_T00_tseANTs_highres.nii.gz -popas A T00_${1}_segmentation.nii.gz -split -foreach -smooth 0.5vox -insert A 1 -reslice-identity -endfor -merge \
  -o T00_${1}_segmentation_highres.nii.gz
#c3d T01_${1}_CT.nii.gz -popas A T00/sfseg/final/TLE05_S1_left_lfseg_${segtype}.nii.gz T00/sfseg/final/TLE05_S1_right_lfseg_${segtype}.nii.gz -add -o T00_${1}_segmentation.nii.gz \
c3d T01_${1}_CT.nii.gz -popas A T00/sfseg/final/${1}_left_lfseg_${segtype}.nii.gz T00/sfseg/final/${1}_right_lfseg_${segtype}.nii.gz -add -o T00_${1}_segmentation.nii.gz \
  -split -foreach -smooth 0.5vox -insert A 1 -reslice-matrix T01_CT_to_T00_tseANTs_RAS_inv.mat -endfor -merge \
  -o T00_${1}_segmentation_to_T01_CT.nii.gz

if [ -f T00_${1}_mprage_brainBrainExtractionBrain/T00_${1}_mprage_brainBrainExtractionBrain_wholebrainseg.nii.gz ]; then
  mkdir -p T00_${1}_mprage
  cp T00_${1}_mprage_brainBrainExtractionBrain/T00_${1}_mprage_brainBrainExtractionBrain_wholebrainseg.nii.gz  T00_${1}_mprage/T00_${1}_mprage_wholebrainseg.nii.gz
fi

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

  f=T00_${1}_mprage.nii.gz
  m=T01_${1}_mprage.nii.gz
    $reg -d $dim  \
      -m Mattes[  $f, $m , 1 , 32, random , 0.1 ] \
      -t Rigid[ 0.2 ] \
      -c [1000x1000x1000,1.e-7,20]  \
      -s 4x2x0  \
      -f 4x2x1 -l 1 \
      -r [ $f, $m, 1 ] \
      -a 1 \
      -o [ T01_mprage_to_T00_mprageANTs , T01_mprage_to_T00_mprageANTs.nii.gz, T01_mprage_to_T00_mprageANTs_inverse.nii.gz ]
  ~sudas/bin/ConvertTransformFile 3 T01_mprage_to_T00_mprageANTs0GenericAffine.mat \
        T01_mprage_to_T00_mprageANTs0GenericAffine_RAS.mat --hm

fi

:<<'NOCOORD'
# Save out coordinates now if VOX_coords_mother is available
fn=VOX_coords_mother.txt
if [ -f $fn ]; then
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
    # Change to handle digits in the electrode name
    elname_num=${el##*[A-Z]}
    elname_str=${el%${elname_num}}
    prevelname_num=$(echo $prevel | sed -e 's/[^0-9]//g')
    # Change to handle digits in the electrode name
    prevelname_num=${prevel##*[A-Z]}
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


sub=$1
fn=T01_${sub}_CT.nii

${SDIR}/rastransform.py vox_coords.txt. ${fn}.gz electrode_coordinates.csv

# Change to T1 space
~sudas/bin/ants/antsApplyTransformsToPoints -d 3 -i electrode_coordinates.csv -o electrode_coordinates_T1.csv \
  -t [T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt,1]
fi
NOCOORD


cd $oldcwd
