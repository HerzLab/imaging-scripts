#!/bin/bash
set -x
sub=$1
#pth=cfndata/picsl/srdas
#pth=""
#:<<COMM
#fn=/data10/RAM/subjects/$sub/tal/VOX_coords_mother.txt
#if [ -f $fn ]; then
#  cp $fn VOX_coords_mother.txt
#
#fi
#fn=~gorniak/$sub/VOX_coords_mother.txt
#if [ -f $fn ]; then 
#  cp $fn VOX_coords_mother.txt
#fi
#COMM
export PATH=/oceanus/collab/herz-lab/processing_code/bin:$PATH
doall=1
fn=VOX_coords_mother.txt
CT=T01_${sub}_CT.nii.gz
segmtlT2=T00_${sub}_segmentation.nii.gz
segwb=T00_${sub}_mprage_wholebrainseg_to_T01_CT.nii.gz
segmtl=T00_${sub}_segmentation_to_T01_CT.nii.gz
segwbT1=T00_${sub}_mprage/T00_${sub}_mprage_wholebrainseg.nii.gz
snapwbfn=/oceanus/collab/herz-lab/processing_code/bin/localization/ahead_joint/turnkey/data/WholeBrain/MICCAI-Challenge-2012-Label-Information.csv
snapmtlfn=/oceanus/collab/herz-lab/processing_code/bin/localization/ashs_atlases/mtlatlas/snap/snaplabels.txt
snapelfnbase=/oceanus/collab/herz-lab/processing_code/bin/localization/electrode_snaplabel_color.txt
TEMPLATE=/oceanus/collab/herz-lab/processing_code/bin/localization/NickOasisTemplate/T_template0.nii.gz
RDIR=/oceanus/collab/herz-lab/processing_code/bin/localization/template_to_NickOasis
faffine=$RDIR/ch22t0GenericAffine.mat
fwarp=$RDIR/ch22t1Warp.nii.gz
finversewarp=$RDIR/ch22t1InverseWarp.nii.gz
CH2=/oceanus/collab/herz-lab/processing_code/bin/localization/ch2.nii.gz

# Code for drawing sphere with -sdt and reporting percent of subfields within that
# c3d T00_R1026D_tseelectrodelabels_spheres.nii.gz -thresh 37 37 1 0 -sdt -thresh -1 1 1 0 -o testblob.nii.gz -as A T00_R1026D_segmentation.nii.gz -times -insert A 1 -lstat

#mkdir -p backup_for_electrode_cloud
#cp * backup_for_electrode_cloud
echo "hostname is $(hostname)"

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
  el=$(cat $fn | sed -n "${i}p" | awk '{print $1}'); 
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
  x=$(expr ${elxs[i]}  )
  if [ -f flippedCT.flag ]; then
    x=$(expr 512 - ${elxs[i]}  )
  fi
  y=$(expr ${elys[i]}  )
  z=$(expr ${elzs[i]}  )


  # Add voxel coordinates to a file so that we can transform to physical coordinates later
  echo $x $y $z >> vox_coords.txt

  # Color the voxel at each electrode location identified in voxtool according to the electrode number  
  if [ $doel == 1 ]; then
    c3d T01_${sub}_electrodelabels.nii.gz T01_${sub}_electrodelabels.nii.gz \
      -cmv -thresh $z $z 1 0 -popas Z -thresh $y $y 1 0 -popas Y -thresh $x $x 1 0 -push Y -push Z -times -times \
      -scale $(expr $i + 1 ) \
      -add -o T01_${sub}_electrodelabels.nii.gz 
  fi
  

  # Probe in CT space
  # TODO We should probe in T1/T2 space
  loc=${x}x${y}x${z}vox

  mlabel=$(c3d $segmtl -probe $loc | awk '{print $NF}')
  mlname=$(cat $snapmtlfn | sed -e 's/^[ \t]*//'  | grep "^${mlabel} " | sed -r 's/[^\"]*([\"][^\"]*[\"][,]?)[^\"]*/\1 /g')
  label=$(c3d $segwb -probe $loc | awk '{print $NF}')
  lname=$(cat $snapwbfn | grep "^${label}," | cut -f 2 -d ",")
  if [[ $lname == *Clear\ Label* ]]; then
    lname="Not in segmented brain"
  fi
  if [[ $mlname == *Clear\ Label* ]]; then
    alname=$lname
  else
    alname=${lname}/${mlname}
  fi

  echo $el, $mlabel, $mlname >> mtllabels.csv
  echo $el, $label, $lname >> wholebrainlabels.csv
  echo $el, $label, $alname>> electrodelabels.csv


done

if [ -z ${SDIR} ]; then
    SDIR=$(dirname $0 )
fi

sub=$1
fn=T01_${sub}_CT.nii

${SDIR}/rastransform.py vox_coords.txt ${fn}.gz electrode_coordinates.csv


# Generate coordinates from voxel labels -- not doing this
# /oceanus/collab/herz-lab/processing_code/bin/ants/ImageMath 3 electrode_coordinates.csv LabelStats T01_${sub}_electrodelabels.nii.gz T01_${sub}_electrodelabels.nii.gz

# Change to T1, T2 and template spaces
/oceanus/collab/herz-lab/processing_code/bin/ants/antsApplyTransformsToPoints -d 3 -i electrode_coordinates.csv -o electrode_coordinates_T1.csv \
  -t [T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt,1]
/oceanus/collab/herz-lab/processing_code/bin/ants/antsApplyTransformsToPoints -d 3 -i electrode_coordinates.csv -o electrode_coordinates_T2.csv \
  -t T01_CT_to_T00_tseANTs_RAS_inv_itk.txt
/oceanus/collab/herz-lab/processing_code/bin/ants/antsApplyTransformsToPoints -d 3 -i electrode_coordinates.csv -o electrode_coordinates_mni.csv \
  -t [T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt,1] -t [T00/thickness/${sub}TemplateToSubject0GenericAffine.mat,1]\
  -t T00/thickness/${sub}TemplateToSubject1InverseWarp.nii.gz -t [$faffine,1] -t $finversewarp
# Change from ITK to Nifti coordinates and get rid of header
cat electrode_coordinates.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3, $4, $5, $6, $7, $8}' OFS=',' > test.csv
mv test.csv electrode_coordinates.csv
cat electrode_coordinates_mni.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3, $4, $5, $6, $7, $8}' OFS=',' > test.csv
mv test.csv electrode_coordinates_mni.csv
cat electrode_coordinates_T2.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3, $4, $5, $6, $7, $8}' OFS=',' > test.csv
mv test.csv electrode_coordinates_T2.csv
cat electrode_coordinates_T1.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3, $4, $5, $6, $7, $8}' OFS=',' > test.csv
mv test.csv electrode_coordinates_T1.csv

# Add electrode names to electrode_coordinates_T1.csv for FS conversion


# Draw spheres around electrode locations
cat electrode_coordinates_T1.csv | awk -F "," '{print $1,$2,$3,NR}' > lmT1.txt
c3d T00_${sub}_mprage.nii.gz -scale 0 -landmarks-to-spheres lmT1.txt 2 -o T00_${sub}_mprageelectrodelabels_spheres.nii.gz
cat electrode_coordinates_T2.csv | awk -F "," '{print $1,$2,$3,NR}' > lmT2.txt
c3d T00_${sub}_tse.nii.gz -scale 0 -landmarks-to-spheres lmT2.txt 2 -o T00_${sub}_tseelectrodelabels_spheres.nii.gz
cat electrode_coordinates.csv | awk -F "," '{print $1,$2,$3,NR}' > lmCT.txt
c3d T01_${sub}_CT.nii.gz -scale 0 -landmarks-to-spheres lmCT.txt 2 -o T01_${sub}_CTelectrodelabels_spheres.nii.gz
cat electrode_coordinates_mni.csv | awk -F "," '{print $1,$2,$3,NR}' > lmMNI.txt
c3d $CH2 -scale 0 -landmarks-to-spheres lmMNI.txt 2 -o T00_${sub}_MNIelectrodelabels_spheres.nii.gz 

# Save electrode coordinates in CT space and move on to computing midpoints
cp electrode_coordinates.csv electrode_coordinates_CT.csv
  
# Electrode coordinate file with midpoint pairs
> electrode_coordinates_mid.csv
> electrodenames_mid.csv

> electrode_coordinates_mid_native.csv
> electrodenames_mid_native.csv
> electrode_coordinates_native.csv
> electrodenames_native.csv

# Format of LabelStats output
# x,y,z,t,label,mass,volume,count
elxmm=($(cat electrode_coordinates.csv | awk -F , '{print $1}')) 
elymm=($(cat electrode_coordinates.csv | awk -F , '{print $2}')) 
elzmm=($(cat electrode_coordinates.csv | awk -F , '{print $3}')) 
elt=($(cat electrode_coordinates.csv | awk -F , '{print $4}')) 
ellabel=($(cat electrode_coordinates.csv | awk -F , '{print $5}')) 
elmass=($(cat electrode_coordinates.csv | awk -F , '{print $6}')) 
elvol=($(cat electrode_coordinates.csv | awk -F , '{print $7}')) 
elcount=($(cat electrode_coordinates.csv | awk -F , '{print $8}')) 

# Also get the coordinates in T1 and T2 
elxmmT1=($(cat electrode_coordinates_T1.csv | awk -F , '{print $1}')) 
elymmT1=($(cat electrode_coordinates_T1.csv | awk -F , '{print $2}')) 
elzmmT1=($(cat electrode_coordinates_T1.csv | awk -F , '{print $3}')) 
eltT1=($(cat electrode_coordinates_T1.csv | awk -F , '{print $4}')) 
elxmmT2=($(cat electrode_coordinates_T2.csv | awk -F , '{print $1}')) 
elymmT2=($(cat electrode_coordinates_T2.csv | awk -F , '{print $2}')) 
elzmmT2=($(cat electrode_coordinates_T2.csv | awk -F , '{print $3}')) 
eltT2=($(cat electrode_coordinates_T2.csv | awk -F , '{print $4}')) 

scale=4;

# Generate midpoint coordinates
# For each contact identified in voxtool
for ((i=0;i<${#elnames[*]};i++)); do
  el=${elnames[i]}
  x=${elxmm[i]} 
  y=${elymm[i]}
  z=${elzmm[i]}
  t=${elt[i]}
  label=${ellabel[i]}
  mass=${elmass[i]}
  vol=${elvol[i]}
  count=${elcount[i]}
  xT1=${elxmmT1[i]} 
  yT1=${elymmT1[i]}
  zT1=${elzmmT1[i]}
  tT1=${eltT1[i]}
  xT2=${elxmmT2[i]} 
  yT2=${elymmT2[i]}
  zT2=${elzmmT2[i]}
  tT2=${eltT2[i]}


  # Probe in native space
  loc=${x}x${y}x${z}mm
  locT1=${xT1}x${yT1}x${zT1}mm
  locT2=${xT2}x${yT2}x${zT2}mm

  mlabel=$(c3d $segmtlT2 -interp NN -probe $locT2 | awk '{print $NF}')
  mlname=$(cat $snapmtlfn | sed -e 's/^[ \t]*//'  | grep "^${mlabel} " | sed -r 's/[^\"]*([\"][^\"]*[\"][,]?)[^\"]*/\1 /g')
  wlabel=$(c3d $segwbT1 -interp NN -probe $locT1 | awk '{print $NF}')
  lname=$(cat $snapwbfn | grep "^${wlabel}," | cut -f 2 -d ",")
  if [[ $lname == *Clear\ Label* ]]; then
    lname="Not in segmented brain"
  fi
  if [[ $mlname == *Clear\ Label* || -z $mlname ]]; then
    alname=$lname
  else
    alname=${lname}/${mlname}
  fi
  echo ${x}, ${y}, ${z}, ${t}, ${label}, ${mass}, ${volume}, ${count}  >> electrode_coordinates_native.csv
  echo ${el}, $alname >> electrodenames_native.csv

  if [ $i != 0 ]; then
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
      midx=$(echo "scale=$scale; ( $(printf %.4f $x) + $(printf %.4f $prevx)) / 2.0" | bc -l)
      midy=$(echo "scale=$scale; ( $(printf %.4f $y) + $(printf %.4f $prevy)) / 2.0" | bc -l)
      midz=$(echo "scale=$scale; ( $(printf %.4f $z) + $(printf %.4f $prevz)) / 2.0" | bc -l)
      midt=$(echo "scale=$scale; ( $(printf %.4f $t) + $(printf %.4f $prevt)) / 2.0" | bc -l)
      midlabel=$(expr ${#elnames[*]} + ${i})
      midmass=$mass
      midvol=$vol
      midcount=1
      midxT1=$(echo "scale=$scale; ( $(printf %.4f $xT1) + $(printf %.4f $prevxT1)) / 2.0" | bc -l)
      midyT1=$(echo "scale=$scale; ( $(printf %.4f $yT1) + $(printf %.4f $prevyT1)) / 2.0" | bc -l)
      midzT1=$(echo "scale=$scale; ( $(printf %.4f $zT1) + $(printf %.4f $prevzT1)) / 2.0" | bc -l)
      midtT1=$(echo "scale=$scale; ( $(printf %.4f $tT1) + $(printf %.4f $prevtT1)) / 2.0" | bc -l)
      midxT2=$(echo "scale=$scale; ( $(printf %.4f $xT2) + $(printf %.4f $prevxT2)) / 2.0" | bc -l)
      midyT2=$(echo "scale=$scale; ( $(printf %.4f $yT2) + $(printf %.4f $prevyT2)) / 2.0" | bc -l)
      midzT2=$(echo "scale=$scale; ( $(printf %.4f $zT2) + $(printf %.4f $prevzT2)) / 2.0" | bc -l)
      midtT2=$(echo "scale=$scale; ( $(printf %.4f $tT2) + $(printf %.4f $prevtT2)) / 2.0" | bc -l)
    
      # Probe in CT space
      loc=${midx}x${midy}x${midz}mm
      locT1=${midxT1}x${midyT1}x${midzT1}mm
      locT2=${midxT2}x${midyT2}x${midzT2}mm

      mlabel=$(c3d $segmtlT2 -interp NN -probe $locT2 | awk '{print $NF}')
      mlname=$(cat $snapmtlfn | sed -e 's/^[ \t]*//'  | grep "^${mlabel} " | sed -r 's/[^\"]*([\"][^\"]*[\"][,]?)[^\"]*/\1 /g')
      wlabel=$(c3d $segwbT1 -interp NN -probe $locT1 | awk '{print $NF}')
      lname=$(cat $snapwbfn | grep "^${wlabel}," | cut -f 2 -d ",")
      if [[ $lname == *Clear\ Label* ]]; then
        lname="Not in segmented brain"
      fi
      if [[ $mlname == *Clear\ Label* ]]; then
        alname=$lname
      else
        alname=${lname}/${mlname}
      fi

      echo ${midx}, ${midy}, ${midz}, ${midt}, ${midlabel}, ${midmass}, ${midvol}, ${midcount}  >> electrode_coordinates_mid.csv
      echo ${midel}, $alname >> electrodenames_mid_native.csv
    fi
    
  fi
  prevel=${elnames[i]}
  prevx=${elxmm[i]} 
  prevy=${elymm[i]}
  prevz=${elzmm[i]}
  prevt=${elt[i]}
  prevlabel=${ellabel[i]}
  prevmass=${elmass[i]}
  prevvol=${elvol[i]}
  prevcount=${elcount[i]}
  prevxT1=${elxmmT1[i]} 
  prevyT1=${elymmT1[i]}
  prevzT1=${elzmmT1[i]}
  prevtT1=${eltT1[i]}
  prevxT2=${elxmmT2[i]} 
  prevyT2=${elymmT2[i]}
  prevzT2=${elzmmT2[i]}
  prevtT2=${eltT2[i]}

done
    
paste -d "," electrodenames_native.csv electrode_coordinates_native.csv > electrodenames_coordinates_native.csv
paste -d ","  electrodenames_coordinates_native.csv electrode_coordinates_T1.csv > electrodenames_coordinates_native_and_T1.csv
paste -d "," electrodenames_mid_native.csv electrode_coordinates_mid.csv > electrodenames_coordinates_mid.csv
cp electrode_coordinates_mid.csv electrode_coordinates_mid_CT.csv

# Add electrode names on some files
cat electrodenames_native.csv | cut -f 1 -d "," > namesonly.csv
if [ -f T00/thickness/${sub}CorticalThicknessNormalizedToTemplate.nii.gz ]; then
  paste -d "," namesonly.csv electrode_coordinates_mni.csv > electrodenames_coordinates_mni.csv
fi

# Change from Nifti to ITK coordinates for antsApplyTransformsToPoints
cat electrode_coordinates_mid.csv | awk -F',' '{print -1*$1, -1*$2, $3, $4, $5, $6, $7, $8}' OFS=',' > test.csv
mv test.csv electrode_coordinates_mid.csv


echo "x,y,z,t,label,mass,volume,count" > test.csv
cat  electrode_coordinates_mid.csv >> test.csv
mv test.csv electrode_coordinates_mid.csv

# Change to T1, T2 and template spaces
/oceanus/collab/herz-lab/processing_code/bin/ants/antsApplyTransformsToPoints -d 3 -i electrode_coordinates_mid.csv -o electrode_coordinates_T1_mid.csv \
  -t [T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt,1] 
/oceanus/collab/herz-lab/processing_code/bin/ants/antsApplyTransformsToPoints -d 3 -i electrode_coordinates_mid.csv -o electrode_coordinates_T2_mid.csv \
  -t T01_CT_to_T00_tseANTs_RAS_inv_itk.txt
/oceanus/collab/herz-lab/processing_code/bin/ants/antsApplyTransformsToPoints -d 3 -i electrode_coordinates_mid.csv -o electrode_coordinates_mni_mid.csv \
  -t [T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt,1] -t [T00/thickness/${sub}TemplateToSubject0GenericAffine.mat,1]\
  -t T00/thickness/${sub}TemplateToSubject1InverseWarp.nii.gz -t [$faffine,1] -t $finversewarp
# Change from ITK to Nifti coordinates
cat electrode_coordinates_mid.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3, $4, $5, $6, $7, $8}' OFS=',' > test.csv
mv test.csv electrode_coordinates_mid.csv
cat electrode_coordinates_mni_mid.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3, $4, $5, $6, $7, $8}' OFS=',' > test.csv
mv test.csv electrode_coordinates_mni_mid.csv
cat electrode_coordinates_T2_mid.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3, $4, $5, $6, $7, $8}' OFS=',' > test.csv
mv test.csv electrode_coordinates_T2_mid.csv
cat electrode_coordinates_T1_mid.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3, $4, $5, $6, $7, $8}' OFS=',' > test.csv
mv test.csv electrode_coordinates_T1_mid.csv

# TODO Make sure midpoint label numbers are correct for T2
cat electrode_coordinates_T1_mid.csv | awk -F "," '{print $1,$2,$3,$5}' > lmT1_mid.txt
c3d T00_${sub}_mprage.nii.gz -scale 0 -landmarks-to-spheres lmT1_mid.txt 2 -o T00_${sub}_mprageelectrodelabels_spheres_mid.nii.gz 
cat electrode_coordinates_T2_mid.csv | awk -F "," '{print $1,$2,$3,$5}' > lmT2_mid.txt
c3d T00_${sub}_tse.nii.gz -scale 0 -landmarks-to-spheres lmT2_mid.txt 2 -o T00_${sub}_tseelectrodelabels_spheres_mid.nii.gz 
cat electrode_coordinates_mid.csv | awk -F "," '{print $1,$2,$3,$5}' > lmCT_mid.txt
c3d T01_${sub}_CT.nii.gz -scale 0 -landmarks-to-spheres lmCT_mid.txt 2 -o T01_${sub}_CTelectrodelabels_spheres_mid.nii.gz 
cat electrode_coordinates_mni_mid.csv | awk -F "," '{print $1,$2,$3,$5}' > lmMNI_mid.txt
c3d $CH2 -scale 0 -landmarks-to-spheres lmMNI_mid.txt 2 -o T00_${sub}_MNIelectrodelabels_spheres_mid.nii.gz 

paste -d "," electrodenames_mid_native.csv electrode_coordinates_mni_mid.csv > electrodelabels_and_coordinates_mni_mid.csv
paste -d "," electrodenames_coordinates_mid.csv electrode_coordinates_T1_mid.csv > electrodenames_coordinates_native_and_T1_mid.csv

:<<'COMMMM'
    echo $x_new $y_new $z_new $line_num >> newmni.txt
    if [ -n $DOROI ]; then
      evalROI $n $line_num
    fi
  fi
done < jacksheet.txt
c3d $CH2 -scale 0 -landmarks-to-spheres oldmni.txt 3 -o oldmni_electrodelabels.nii.gz
c3d $CH2 -scale 0 -landmarks-to-spheres newmni.txt 3 -o newmni_electrodelabels.nii.gz
COMMMM

if [ -z $TMPDIR ]; then
  TMPDIR=$(mktemp -d)
fi
:<<'NODIL'
if [ ! -f T01_${sub}_electrodelabels_alldilated.nii.gz ]; then

for ((i=1;i<=${#elnames[*]};i++)); do
  c3d T01_${sub}_electrodelabels.nii.gz -thresh $i $i 1 0 -dilate 1 3x3x3vox \
    -o $TMPDIR/T01_${sub}_electrodelabels_$(printf %02d $i).nii.gz; 
done

for ((i=2;i<=${#elnames[*]};i++)); do 
  ii=$(printf %02d $i); 
  xx="$xx $TMPDIR/T01_${sub}_electrodelabels_${ii}.nii.gz -scale $ii -add"; 
done
c3d $TMPDIR/T01_${sub}_electrodelabels_01.nii.gz $xx -o T01_${sub}_electrodelabels_alldilated.nii.gz

fi
NODIL

rm -rf $TMPDIR