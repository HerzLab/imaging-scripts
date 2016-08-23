#!/bin/bash
#$ -S /bin/bash
 set -x

# Common stuff
IMROOT=~sudas/bin/imagemagick
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$IMROOT/lib
export PATH=$PATH:$IMROOT/bin
ROOT=~/DARPA/long
export ROOT
SFSEG=sfseg


# This code removes straddler PRC/ERC voxels
function cleanup_prc()
{
  in=$1
  out=$2

  INFO=$(c3d $in -thresh 9 inf 1 0 -dilate 0 1x1x0vox  -o $TMPDIR/temp.nii.gz -info)
  NS=$(echo $INFO | sed -e "s/.*dim = .//g" -e "s/.;.*bb.*//g" | awk -F ',' '{print $3}')
  slicecmd=$(for((i=0;i<$NS;i++)); do echo "-push X -slice z $i -voxel-sum "; done)
  c3d $TMPDIR/temp.nii.gz -popas X $slicecmd | grep Voxel | awk '{print $3}' > $TMPDIR/counts.txt
  NNZ=$(cat $TMPDIR/counts.txt | grep -v '^0$' | wc -l)
  MEDIAN=$(cat $TMPDIR/counts.txt | grep -v '^0$' | sort -n | tail -n $((NNZ/2)) | head -n 1)
  CUTOFF=$((MEDIAN / 4))
  RULE=$(cat $TMPDIR/counts.txt | awk "{print NR-1,int(\$1 < $CUTOFF)}")
  c3d $in $TMPDIR/temp.nii.gz -copy-transform -cmv -replace $RULE -popas M $in -as X \
    -thresh 9 inf 1 0 -push M -times -scale -1 -shift 1 \
    -push X -times -o $out
  NLEFT=$(cat $TMPDIR/counts.txt | awk "\$1 > $CUTOFF {k++} END {print k}")
  echo $NLEFT
#  for((;;)); do
#  sleep 999999999
#  done
}

# Generate the statistics for the subject (similar to what's in the ASHS qc dir)
function genstats()
{
  in=$1
  c3d $in -dup -lstat > $TMPDIR/stat.txt

  namelist=$(echo CA1 CA2 CA3 DG SUB ERC BA35 BA36 PHC CA HIPP)
  list=$(echo 1 2 4 3 8 10 11 12 13)

  VOLS=""
  for i in $list; do
    THISVOL=$(cat $TMPDIR/stat.txt | sed -e 's/  */ /g' -e 's/^ *\(.*\) *$/\1/' | grep "^$i " | awk '{print $7}')
    THISNSLICE=$(cat $TMPDIR/stat.txt | sed -e 's/  */ /g' -e 's/^ *\(.*\) *$/\1/' | grep "^$i " | awk '{print $10}')
    THISNVOL=$(echo $THISVOL/$THISNSLICE | bc -l)
    VOLS="$VOLS, $THISVOL, $THISNSLICE, $THISNVOL"
  done
  VOLS=${VOLS#,}


  # Add CA1/2/3
  c3d $in -replace 2 1 4 1 -dup -lstat > $TMPDIR/stat.txt
  for i in 1; do
    THISVOL=$(cat $TMPDIR/stat.txt | sed -e 's/  */ /g' -e 's/^ *\(.*\) *$/\1/' | grep "^$i " | awk '{print $7}')
    THISNSLICE=$(cat $TMPDIR/stat.txt | sed -e 's/  */ /g' -e 's/^ *\(.*\) *$/\1/' | grep "^$i " | awk '{print $10}')
    THISNVOL=$(echo $THISVOL/$THISNSLICE | bc -l)
    VOLS="$VOLS, $THISVOL, $THISNSLICE, $THISNVOL"
  done

  # Add CA/DG for HIPP
  c3d $in -replace 2 1 4 1 3 1 -dup -lstat > $TMPDIR/stat.txt
  for i in 1; do
    THISVOL=$(cat $TMPDIR/stat.txt | sed -e 's/  */ /g' -e 's/^ *\(.*\) *$/\1/' | grep "^$i " | awk '{print $7}')
    THISNSLICE=$(cat $TMPDIR/stat.txt | sed -e 's/  */ /g' -e 's/^ *\(.*\) *$/\1/' | grep "^$i " | awk '{print $10}')
    THISNVOL=$(echo $THISVOL/$THISNSLICE | bc -l)
    VOLS="$VOLS, $THISVOL, $THISNSLICE, $THISNVOL"
  done

  echo $VOLS
  # echo $VOLS | sed -e "s/ /,/g"
}

# Make PNG montage
function make_png()
{
  id=$1
  side=$2
  tp=$3
  MRI=$ROOT/$id/$tp/${SFSEG}/tse_native_chunk_${side}.nii.gz
  SEG=cleanup/${id}_${tp}_seg_${side}.nii.gz
  LABELS=~sudas/bin/localization/mtl_itksnaplabelfile.txt

  if [ -f cleanup/png/${id}_${tp}_${side}_qa.png ]; then
    # return
    :
  fi

  # Generate coronal slices
  NSLICE=5
  for ((i=1; i<=$NSLICE; i++)); do

    PCT=$(echo $i $NSLICE | awk '{ print $1 * 100.0 / ($2 + 1) }')

    c3d $MRI -stretch 0 98% 0 255 -clip 0 255 -popas GG \
      $SEG -trim 40x40x0mm -as SS \
      -push GG -reslice-identity -push SS \
      -foreach -slice z ${PCT}% -flip xy -endfor \
      -popas S -popas G \
      -push G -type uchar -o $TMPDIR/cor_${id}_${side}_gray_${i}.png \
      -push S -oli $LABELS 0.5 -omc $TMPDIR/cor_${id}_${side}_seg_${i}.png

  done

  # Generate sagittal slices
  NSLICE=2
  for ((i=1; i<=$NSLICE; i++)); do

    PCT=$(echo $i $NSLICE | awk '{ print $1 * 100.0 / ($2 + 1) }')

    c3d $MRI -stretch 0 98% 0 255 -clip 0 255 -popas GG \
      $SEG -trim 0x40x40mm -resample 100x100x500% -as SS \
      -push GG -int 0 -reslice-identity -push SS \
      -foreach -slice x ${PCT}% -flip xy -endfor \
      -popas S -popas G \
      -push G -type uchar -o $TMPDIR/sag_${id}_${side}_gray_${i}.png \
      -push S -oli $LABELS 0.5 -omc $TMPDIR/sag_${id}_${side}_seg_${i}.png

  done

  montage \
    -tile 7x -geometry +5+5 \
    $TMPDIR/*_${id}_${side}_gray_*.png  $TMPDIR/*_${id}_${side}_seg_*.png \
    $TMPDIR/${id}_${side}_qa.png

  montage -label '%f' $TMPDIR/${id}_${side}_qa.png -geometry +1+1 \
    cleanup/png/${id}_${tp}_${side}_qa.png
}

# Clean up an individual subject
function cleanup_subject()
{
  id=$1
  tp=$2
  rm -rf cleanup/stats/stats_${tp}_${id}_whole.txt
  local statline
  statline="$id"
  for side in left right; do
    seg=$ROOT/$id/$tp/${SFSEG}/bootstrap/fusion/lfseg_corr_nogray_${side}.nii.gz
    cleanup_prc $seg \
    cleanup/${id}_${tp}_seg_${side}.nii.gz 
  
    if [ "$side" == "left" ]; then
      THICK=$(c3d cleanup/${id}_${tp}_seg_left.nii.gz -info-full | grep Spacing | sed -e "s/[a-zA-Z:,]//g" -e "s/\]//" -e "s/\[//" | awk '{print $3}')
      statline="$statline,$THICK"
    fi
    make_png $id $side $tp 
    statline="${statline},$(genstats cleanup/${id}_${tp}_seg_${side}.nii.gz )"
  done
  echo $statline >> cleanup/stats/stats_${tp}_${id}_whole.txt
}

# Clean up an individual subject
function cleanup_head()
{
  id=$1
  tp=$2
  rm -rf cleanup/stats/stats_${tp}_${id}_head.txt
  local statline
  statline="$id"
  for side in left right; do
    segwhole=$ROOT/$id/$tp/${SFSEG}/bootstrap/fusion/lfseg_corr_nogray_${side}.nii.gz
    atlastype=$(getatlas $segwhole)
    seg=hbt/${id}_${tp}/lfseg_corr_nogray_${side}_head.nii.gz
    cleanup_prc $seg \
    cleanup/${id}_${tp}_seg_${side}_head.nii.gz $atlastype

    if [ "$side" == "left" ]; then
      THICK=$(c3d $seg -info-full | grep Spacing | sed -e "s/[a-zA-Z:,]//g" -e "s/\]//" -e "s/\[//" | awk '{print $3}')
      statline="$statline,$THICK"
    fi
    statline="${statline},$(genstats cleanup/${id}_${tp}_seg_${side}_head.nii.gz $atlastype)"
  done
  echo $statline >> cleanup/stats/stats_${tp}_${id}_head.txt
}

function measure_body()
{
  id=$1
  tp=$2
  rm -rf cleanup/stats/stats_${tp}_${id}_body.txt
  local statline
  statline="$id"
  for side in left right; do
    segwhole=$ROOT/$id/$tp/${SFSEG}/bootstrap/fusion/lfseg_corr_nogray_${side}.nii.gz
    atlastype=$(getatlas $segwhole)
    seg=hbt/${id}_${tp}/lfseg_corr_nogray_${side}_body.nii.gz

    if [ "$side" == "left" ]; then
      THICK=$(c3d $seg -info-full | grep Spacing | sed -e "s/[a-zA-Z:,]//g" -e "s/\]//" -e "s/\[//" | awk '{print $3}')
      statline="$statline,$THICK"
    fi
    statline="${statline},$(genstats $seg $atlastype)"
  done
  echo $statline >> cleanup/stats/stats_${tp}_${id}_body.txt
}

function measure_tail()
{
  id=$1
  tp=$2
  rm -rf cleanup/stats/stats_${tp}_${id}_tail.txt
  local statline
  statline="$id"
  for side in left right; do
    segwhole=$ROOT/$id/$tp/${SFSEG}/bootstrap/fusion/lfseg_corr_nogray_${side}.nii.gz
    atlastype=$(getatlas $segwhole)
    seg=hbt/${id}_${tp}/lfseg_corr_nogray_${side}_tail.nii.gz

    if [ "$side" == "left" ]; then
      THICK=$(c3d $seg -info-full | grep Spacing | sed -e "s/[a-zA-Z:,]//g" -e "s/\]//" -e "s/\[//" | awk '{print $3}')
      statline="$statline,$THICK"
    fi
    statline="${statline},$(genstats $seg $atlastype)"
  done
  echo $statline >> cleanup/stats/stats_${tp}_${id}_tail.txt
}



function get_qa()
{
ROOT=~/wd/ADNI2/long

if [ $# -lt 4 ]; then
  echo Usage: get_qa RID qafile csvfile
  return 1
fi

RID=$1
qafile=$2
csvfile=$3
tp=$4

subject=${RID##*_}

qa=$(grep $RID $qafile | awk '{print $2}')


imfile=$(readlink $ROOT/$RID/$(readlink  $ROOT/$RID/${tp}_${RID}_tse.nii.gz))

xx=${imfile##*_I}
imageid=${xx%High*}
imageline=$(grep $imageid $csvfile)

Ringing=$(echo $imageline | cut -f 9 -d ",")
Motion=$(echo $imageline | cut -f 12 -d ",")
CNR=$(echo $imageline | cut -f 14 -d ",")
SNR=$(echo $imageline | cut -f 15 -d ",")
Comm=$(echo $imageline | cut -f 17 -d ",")

# Not doing 1-4 visual QA score anymore so drop $qa
# dataline="$Ringing, $Motion, $CNR, $SNR, $Comm, $qa"
dataline="$Ringing, $Motion, $CNR, $SNR, $Comm"
echo "$dataline"

}

# Clean up the names for the analysis
function cleanup_names()
{
  HEADER="ID,TP,ICV,Extent,Slice_Thickness"

  list=$(echo CA1 CA2 CA3 DG SUB ERC BA35 BA36 PHC CA HIPP)

  for side in left right; do
    for sf in $list; do
      HEADER="$HEADER,${side}_${sf}_vol,${side}_${sf}_ns,${side}_${sf}_nvol"
    done
  done
  HEADER="$HEADER,${sf}_AR"
  echo $HEADER > stats_lr_cleanup.csv

  for fn in $(ls cleanup/stats/); do

    id=$(cat cleanup/stats/$fn | head -n 1 | awk -F ',' '{print $1}')
    tp=$(echo $fn | cut -f 2 -d "_")
    extent=$(echo $fn | cut -f 4 -d "_" | cut -f 1 -d ".")

    # Get the ICV value
    ICV=$(cat $ROOT/${id}/$tp/${SFSEG}/final/${id}_icv.txt | awk '{print $2}')
    
    newline="$id,$tp,$ICV,$extent"

    cat cleanup/stats/$fn | sed -e "s/$id/$newline/g" | tee -a stats_lr_cleanup.csv

  done
}

# MAIN
function main()
{
#rm -rf cleanup
mkdir -p cleanup/dump
mkdir -p cleanup/png
mkdir -p cleanup/stats

IDS=($(cat sublist.txt))
for ((i=0;i<${#IDS[*]};i++)); do
  fn=${IDS[i]}
  tp=T00
 
  echo $fn
  sub=$fn

    export tp
    # if [ -f cleanup/stats/stats_${tp}_${fn}.txt ]; then
    # if [ -f cleanup/stats/stats_${tp}_${sub}.txt ]; then
    if [ -f cleanup/png/${sub}_${tp}_right_qa.png -a  -f cleanup/png/${sub}_${tp}_left_qa.png ]; then
      echo "file exists"
      qsub -V -cwd -o cleanup/dump -j y -N "sfcleanup_${sub}_${tp}" $0 cleanup_subject $sub $tp
    else
      # qsub -V -cwd -o cleanup/dump -j y -N "sfcleanup_${fn}_${tp}" $0 cleanup_subject $fn $tp
      qsub -V -cwd -o cleanup/dump -j y -N "sfcleanup_${sub}_${tp}" \
        $0 cleanup_subject $sub $tp
    fi
done 

  qsub -V -cwd -o cleanup/dump -j y -hold_jid "sfcleanup_*" -sync y -b y sleep 1
  echo "calling cleanup_names"
  cleanup_names 
}

if [[ ! $1 ]]; then
  main
elif [[ $1 = "cleanup_subject" ]]; then 
  TMPDIR=$(mktemp -d)
  export TMPDIR
  cleanup_subject $2 $3
#  cleanup_head $2 $3
#  measure_body $2 $3
#  measure_tail $2 $3
  rm -rf $TMPDIR
elif [[ $1 == "make_png" ]]; then
  TMPDIR=$(mktemp -d)
  export TMPDIR
  echo $TMPDIR
  make_png $2 $3 $4 $5
  rm -rf $TMPDIR
fi
