#!/bin/bash
#$ -S /bin/bash
# Walk along the contacts of an electrode to estimate proportion of
# subregions traversed
id=$1
segmtl=T00_${id}_segmentation.nii.gz
snapmtlfn=~sudas/bin/localization/mtl_itksnaplabelfile.txt
VOXFN=VOX_coords_mother.txt
COORDSFILE=electrode_coordinates_T2.csv
# VOXFN=testvox.txt
# COORDSFILE=testcoords.txt
# cp electrode_path.txt electrode_path_bkp08052015.txt
# for i in  */electrode_coordinates_T2.csv; do cd $(dirname $i); ../walk_electrode.sh > electrode_path.txt ; cd ..;done
scale=4;
N=1
prevname=XXX
prevROI=XXX
newElectrode=1
debug=false
inROI=0
while read line; do
  elname=$(echo $line | awk '{print $1}')
  lineT2=$(cat $COORDSFILE | sed -n "${N}p")
  T2x=$(echo $lineT2 | cut -f 1 -d ",")
  T2y=$(echo $lineT2 | cut -f 2 -d ",")
  T2z=$(echo $lineT2 | cut -f 3 -d ",")
  elname_num=$(echo $elname | sed -e 's/[^0-9]//g')
  elname_str=${elname%${elname_num}}
  loc=${T2x}x${T2y}x${T2z}mm
  mlabel=$(c3d $segmtl -interp NN -probe $loc | awk '{print $NF}')
  # Is this the first contact of a new electrode ?
  if [ "$elname_str" != "$prevname" ]; then 
    # Do we have unfinished business ? 
    # Did we start walking a new electrode but never closed out an ROI path in the previous one ?
    if [ $inROI == 1 ]; then
      lsegment=$(echo "scale=$scale; sqrt(($Entry_x - $Exit_x)^2 + ($Entry_y - $Exit_y)^2 + ($Entry_z - $Exit_z)^2)" | bc -l)
      echo $id , $prevname , $prevROI , $Entry , $Exit , $lsegment
    fi
    # Unless it's the first contact of the first electrode, it will be the shallowest of the previous one.
    # Therefore, set the shallow point
    if [ $N != 1 ]; then
      echo $id , $prevname , Shallowest , $T2prevx , $T2prevy , $T2prevz , N/A , N/A , N/A , N/A
    fi
    # Reset all states and set the Deepest point
    echo $id , $elname_str , Deepest , N/A , N/A , N/A , $T2x , $T2y , $T2z , N/A 
    inROI=0
    prevROI=""
    # Are we inside the image yet ?
    #if [ ! -z $mlabel ]; then
    #  ROI=$(cat $snapmtlfn | sed -e 's/^[ \t]*//'  | grep "^${mlabel} " | sed -r 's/[^\"]*([\"][^\"]*[\"][,]?)[^\"]*/\1 /g')
    #  inROI=1
    #  Entry="$T2x,$T2y,$T2z"
    #  Entry_x=$T2x; Entry_y=$T2y; Entry_z=$T2z
    #else
    #  :
    #fi
  # This is a contact for an electrode we are already traversing.
  # Hence, we now need to parameterize this segment
  else
    # Prameterize segment
    diffX=$(echo "$T2x - $T2prevx" | bc -l)
    diffY=$(echo "$T2y - $T2prevy" | bc -l)
    diffZ=$(echo "$T2z - $T2prevz" | bc -l)
    length=$(echo "sqrt(${diffX}^2 + ${diffY}^2 + ${diffZ}^2)" | bc -l)
    Nstep=$(echo "$length 1" | awk '{print int( ($1/$2) + 1 )}')
    # echo $diffX $diffY $length $Nstep
    for ((i=0;i<${Nstep};i++)); do
        segment_x=$(echo "scale=$scale; $T2prevx + (${i}/$Nstep)*$diffX " | bc -l)
        segment_y=$(echo "scale=$scale; $T2prevy + (${i}/$Nstep)*$diffY " | bc -l)
        segment_z=$(echo "scale=$scale; $T2prevz + (${i}/$Nstep)*$diffZ " | bc -l)
        loc=${segment_x}x${segment_y}x${segment_z}mm
        mlabel=$(c3d $segmtl  -interp NN -probe $loc | awk '{print $NF}')
        # echo ${segment_x} , ${segment_y} , ${segment_z}
        # Now let's figure out what's going on at this point
        # We were either already within an ROI or not
        # Also, we are either within the image or not we have to check both
        if [ -z $mlabel ] ; then
          if [ $inROI == 1 ]; then
            # This is unusual, we have gone outside the image while we were walking an ROI
            if $debug; then echo inROI outImage; fi;
            # This means we have to end the walk here and reset the ROI
            lsegment=$(echo "scale=$scale; sqrt(($Entry_x - $Exit_x)^2 + ($Entry_y - $Exit_y)^2 + ($Entry_z - $Exit_z)^2)" | bc -l)
            echo $id , $elname_str , $prevROI , $Entry , $Exit , $lsegment
            # We are no longer in an ROI
            inROI=0
          else
            if $debug ; then echo outROI outImage; fi;
            # We were not in an ROI and we are outside the brain, just keep going
            :
          fi
          inROI=0
        else
          # What is the ROI ?
          ROI=$(cat $snapmtlfn | sed -e 's/^[ \t]*//'  | grep "^${mlabel} " | sed -r 's/[^\"]*([\"][^\"]*[\"][,]?)[^\"]*/\1 /g')
          if [ $inROI == 1 ]; then
            # We were already in some ROI
            if $debug; then echo inROI inImage $ROI; fi;
            # Was the ROI same as the one we just walked into ?
            if [ "$ROI" == "$prevROI" ]; then
              # Keep going, nothing has changed, just update the Exit
              Exit=${segment_x},${segment_y},${segment_z}
              Exit_x=$segment_x; Exit_y=$segment_y; Exit_z=$segment_z
            else
              # We reached a different ROI than last time
              # This means we have to write an entry to the walking table
              # Compute the distance traversed through the ROI
              lsegment=$(echo "scale=$scale; sqrt(($Entry_x - $Exit_x)^2 + ($Entry_y - $Exit_y)^2 + ($Entry_z - $Exit_z)^2)" | bc -l)
              echo $id , $elname_str , $prevROI , $Entry , $Exit , $lsegment
              # This also marks the beginning of the next piece so set Entry
              Entry=${segment_x},${segment_y},${segment_z}
              Entry_x=$segment_x; Entry_y=$segment_y; Entry_z=$segment_z
              Exit=${segment_x},${segment_y},${segment_z}
              Exit_x=$segment_x; Exit_y=$segment_y; Exit_z=$segment_z
              # This ROI becomes the new one
              prevROI=$ROI
            fi
          else
            if $debug; then echo outROI inImage $ROI; fi
            # We are inside the brain but we were previously not in an ROI
            # This means we have encountered a new ROI
            # This ROI becomes the new one, set entry point
            Entry=${segment_x},${segment_y},${segment_z}
            Entry_x=$segment_x; Entry_y=$segment_y; Entry_z=$segment_z
            prevROI=$ROI
          fi
          inROI=1
        fi
    done
  fi
  T2prevx=$T2x; T2prevy=$T2y; T2prevz=$T2z; prevname=$elname_str;
  N=$(expr $N + 1) 
done < <(cat $VOXFN) > electrode_path.txt
# Do we have unfinished business ? 
# Did we start walking a new electrode but never closed out an ROI path in the previous one ?
if [ $inROI == 1 ]; then
  lsegment=$(echo "scale=$scale; sqrt(($Entry_x - $Exit_x)^2 + ($Entry_y - $Exit_y)^2 + ($Entry_z - $Exit_z)^2)" | bc -l)
  echo $id , $elname_str , $prevROI , $Entry , $Exit , $lsegment >> electrode_path.txt
fi
echo $id , $prevname , Shallowest , $T2prevx , $T2prevy , $T2prevz , N/A , N/A , N/A , N/A >> electrode_path.txt
