# set -x -e
dist=0
NE=0
pth=""
CH2=/home/srdas/$pth/wd/Pfizer/ADC/templates/ch2.nii.gz
CH2=~sudas/DARPA/ch2.nii.gz
snapwbfn=../MICCAI-Challenge-2012-Label-Information.csv
snapwbfn=~sudas/bin/localization/ahead_joint/turnkey/data/WholeBrain/MICCAI-Challenge-2012-Label-Information.csv
> oldmni.txt
> newmni.txt
> compmni.txt
sub=$1
segwbT1=T00_${sub}_mprage/T00_${sub}_mprage_wholebrainseg.nii.gz
segMNI=~sudas/DARPA/MNI/T00_MNI_mprage/T00_MNI_mprage_wholebrainseg.nii.gz
DOROI=yes
export GOODDIST=2.0

function evalROI()
{
  n=$1
  line_num=$2
  mniline_old=$(grep "^$n " RAW_coords.txt.mni)
  mniline_new=$( cat electrode_coordinates_mni.csv | sed -n "${line_num}p")
  x_old=$(echo $mniline_old | awk '{print $2}')
  y_old=$(echo $mniline_old | awk '{print $3}')
  z_old=$(echo $mniline_old | awk '{print $4}')
  x_new=$(echo $mniline_new | awk -F, '{print $1}')
  y_new=$(echo $mniline_new | awk -F, '{print $2}')
  z_new=$(echo $mniline_new | awk -F, '{print $3}')
 
  T1line=$( cat electrode_coordinates_T1.csv | sed -n "${line_num}p")  
  x_T1=$(echo $T1line | awk -F, '{print $1}')
  y_T1=$(echo $T1line | awk -F, '{print $2}')
  z_T1=$(echo $T1line | awk -F, '{print $3}')
  T1loc=$(c3d $segwbT1 -interp NN -probe ${x_T1}x${y_T1}x${z_T1}mm  | awk '{print $NF}')
  oldMNIloc=$(c3d $segMNI -interp NN -probe ${x_old}x${y_old}x${z_old}mm  | awk '{print $NF}')
  newMNIloc=$(c3d $segMNI -interp NN -probe ${x_new}x${y_new}x${z_new}mm  | awk '{print $NF}')


  # Take the T1 label and find how far away are we from that ROI
  oldMNIdist=$(c3d $segMNI -thresh $T1loc $T1loc 1 0 -sdt -interp NN -probe ${x_old}x${y_old}x${z_old}mm  | awk '{print $NF}')
  newMNIdist=$(c3d $segMNI -thresh $T1loc $T1loc 1 0 -sdt -interp NN -probe ${x_new}x${y_new}x${z_new}mm  | awk '{print $NF}')

  T1ROI=$(cat $snapwbfn | grep "^${T1loc}," | cut -f 2 -d ",")
  oldMNIROI=$(cat $snapwbfn | grep "^${oldMNIloc}," | cut -f 2 -d ",")
  newMNIROI=$(cat $snapwbfn | grep "^${newMNIloc}," | cut -f 2 -d ",")
  
  if [ "$oldMNIROI" == "$T1ROI" ]; then
    oldComp=1
    oldCompdist=1
  else
    oldComp=0
    if [ "$( echo "${oldMNIdist#-} <= $GOODDIST " | bc )" == "1" ] ; then
      oldCompdist=1
    else
      oldCompdist=0
    fi
  fi
  if [ "$newMNIROI" == "$T1ROI" ]; then
    newComp=1
    newCompdist=1
  else
    newComp=0
    if [ "$( echo "${newMNIdist#-} <= $GOODDIST " | bc )" == "1" ] ; then
      newCompdist=1
    else
      newCompdist=0
    fi
  fi
  echo ${line_num} , $T1ROI, $oldMNIROI, $newMNIROI, $oldComp , $newComp, $oldMNIdist, $newMNIdist, $oldCompdist, $newCompdist  >> compmni.txt
}

while read line ; do
  n=$(echo $line | awk '{print $1}')
  name=$(echo $line | awk '{print $2}')
  name_num=$(echo $name | sed -e 's/[^0-9]//g')
  name_str=${name%${name_num}}
  name_num=$(expr $name_num + 0)
  newname=${name_str}${name_num}
  mniline_old=$(grep "^$n " RAW_coords.txt.mni)
  x_old=$(echo $mniline_old | awk '{print $2}')
  y_old=$(echo $mniline_old | awk '{print $3}')
  z_old=$(echo $mniline_old | awk '{print $4}')
  line_num=$(nl VOX_coords_mother.txt | grep -P "$newname\t" | awk '{print $1}')
  if [ -z $line_num ]; then
    continue;
  else
    mniline_new=$( cat electrode_coordinates_mni.csv | sed -n "${line_num}p") 
    x_new=$(echo $mniline_new | awk -F, '{print $1}')
    y_new=$(echo $mniline_new | awk -F, '{print $2}')
    z_new=$(echo $mniline_new | awk -F, '{print $3}')
    thisdist=$(echo "sqrt(($x_old - $x_new)^2 +  ($y_old - $y_new)^2 + ($z_old - $z_new)^2)" | bc -l )
    dist=$(echo "$dist + $thisdist" | bc -l)
    NE=$(expr $NE + 1)
    echo $n $newname $thisdist 
    echo $x_old $y_old $z_old $line_num >> oldmni.txt
    echo $x_new $y_new $z_new $line_num >> newmni.txt
    if [ -n $DOROI ]; then
      evalROI $n $line_num 
    fi
  fi
done < jacksheet.txt
c3d $CH2 -scale 0 -landmarks-to-spheres oldmni.txt 3 -o oldmni_electrodelabels.nii.gz
c3d $CH2 -scale 0 -landmarks-to-spheres newmni.txt 3 -o newmni_electrodelabels.nii.gz
dist=$(echo "$dist/$NE" | bc -l )
echo $dist 
