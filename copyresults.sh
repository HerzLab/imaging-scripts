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
sub=$1

thisd=$PWD
cd $RAMROOT/$sub

mkdir -p $RAMROOT/$sub/wholebrainseg
mkdir -p $RAMROOT/$sub/T2native
mkdir -p $RAMROOT/$sub/CTnative
mkdir -p $RAMROOT/$sub/T2highres
ln -sf ../mtllabels.csv ../wholebrainlabels.csv ../T00_${sub}_mprage.nii.gz ../T00_${sub}_mprage/T00_${sub}_mprage_wholebrainseg.nii.gz ../T00_${sub}_mprage_wholebrainseg_to_T01_CT.nii.gz ../T01_CT_to_T00_mprageANTs_inverse.nii.gz ../T01_${sub}_CT.nii.gz ../electrodelabels_and_coordinates_mni_mid.csv ../T00_${sub}_mprageelectrodelabels_spheres.nii.gz ../T00_${sub}_mprageelectrodelabels_spheres_mid.nii.gz $RAMROOT/${sub}/wholebrainseg
ln -sf ../T00_${sub}_segmentation_highres.nii.gz   ../T00_${sub}_tse_highres.nii.gz ../T00_${sub}_segmentation_highresNN.nii.gz  ../T01_${sub}_CT_to_T00_tseANTs_highres.nii.gz $RAMROOT/${sub}/T2highres
ln -sf ../T01_${sub}_CT.nii.gz ../T00_${sub}_segmentation_to_T01_CT.nii.gz ../T00_${sub}_tse_to_T01_CTANTs.nii.gz  ../T01_${sub}_CTelectrodelabels_spheres.nii.gz ../electrode_snaplabel.txt ../electrode_coordinates.csv ../T01_${sub}_CTelectrodelabels_spheres_mid.nii.gz $RAMROOT/${sub}/CTnative
ln -sf ../T00_${sub}_segmentation.nii.gz ../T00_${sub}_tse.nii.gz ../T01_${sub}_CT_to_T00_tseANTs.nii.gz ../electrode_coordinates_T2.csv ../T00_${sub}_tseelectrodelabels_spheres.nii.gz ../T00_${sub}_tseelectrodelabels_spheres_mid.nii.gz $RAMROOT/${sub}/T2native

cd $thisd
