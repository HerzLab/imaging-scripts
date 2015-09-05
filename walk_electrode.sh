# Walk along the contacts of an electrode to estimate proportion of
# subregions traversed
id=$(basename $PWD)
segmtl=T00_${id}_segmentation.nii.gz
snapmtlfn=../snaplabels.txt
VOXFN=VOX_coords_mother.txt
COORDSFILE=electrode_coordinates_T2.csv
# VOXFN=testvox.txt
# COORDSFILE=testcoords.txt

# for i in  */electrode_coordinates_T2.csv; do cd $(dirname $i); ../walk_electrode.sh > electrode_path.txt ; cd ..;done
scale=4;
N=1
prevname=XXX
prevROI=XXX
newElectrode=1
inROI=0
while read line; do
  echo N=$N
  elname=$(echo $line | awk '{print $1}')
  lineT2=$(cat $COORDSFILE | sed -n "${N}p")
  T2x=$(echo $lineT2 | cut -f 1 -d ",")
  T2y=$(echo $lineT2 | cut -f 2 -d ",")
  T2z=$(echo $lineT2 | cut -f 3 -d ",")
  # echo $elname $T2x $T2y $T2z
  elname_num=$(echo $elname | sed -e 's/[^0-9]//g')
  elname_str=${elname%${elname_num}}
  if [ $newElectrode == 1 ]; then
    loc=${T2x}x${T2y}x${T2z}mm
    mlabel=$(c3d $segmtl -interp NN -probe $loc | awk '{print $NF}')
    ROI=$(cat $snapmtlfn | sed -e 's/^[ \t]*//'  | grep "^${mlabel} " | sed -r 's/[^\"]*([\"][^\"]*[\"][,]?)[^\"]*/\1 /g')
    Entry="$T2x,$T2y,$T2z" 
    Entry_x=$T2x; Entry_y=$T2y; Entry_z=$T2z
    newElectrode=0
    echo newElectrode $Entry label=$mlabel ROI=$ROI
  fi
  if [ "$elname_str" == "$prevname" ]; then
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
        echo segment $Entry $Exit label=$mlabel ROI=$ROI
        if [ -z $mlabel ]; then
          if [ $inROI == 1 ]; then
            lsegment=$(echo "scale=$scale; sqrt(($Entry_x - $segment_x)^2 + ($Entry_y - $segment_y)^2 + ($Entry_z - $segment_z)^2)" | bc -l)
            echo $id , $elname_str , $prevROI , $Entry , ${segment_x} , ${segment_y} , ${segment_z} , $lsegment other
          fi
          inROI=0
        else
          ROI=$(cat $snapmtlfn | sed -e 's/^[ \t]*//'  | grep "^${mlabel} " | sed -r 's/[^\"]*([\"][^\"]*[\"][,]?)[^\"]*/\1 /g')
          # echo "mlabel=$mlabel ROI=$ROI"
          if [ "$ROI" != "$prevROI" ] && [ "$prevROI" != "XXX" ]; then
            lsegment=$(echo "scale=$scale; sqrt(($Entry_x - $Exit_x)^2 + ($Entry_y - $Exit_y)^2 + ($Entry_z - $Exit_z)^2)" | bc -l)
            echo $id , $elname_str , $prevROI , $Entry , $Exit , $lsegment in
            Entry=${segment_x},${segment_y},${segment_z}
            Entry_x=$segment_x; Entry_y=$segment_y; Entry_z=$segment_z
          else
            if [ "$prevROI" == "XXX" ]; then
              Entry=${segment_x},${segment_y},${segment_z}
              Entry_x=$segment_x; Entry_y=$segment_y; Entry_z=$segment_z
            fi  
            Exit=${segment_x},${segment_y},${segment_z}
            Exit_x=$segment_x; Exit_y=$segment_y; Exit_z=$segment_z

          fi
          prevROI=$ROI;
          inROI=1
        fi
    done

  else
    if [ $N != 1 ]; then
      newElectrode=1
      if [ $inROI == 1 ]; then
        lsegment=$(echo "scale=$scale; sqrt(($Entry_x - $T2prevx)^2 + ($Entry_y - $T2prevy)^2 + ($Entry_z - $T2prevz)^2)" | bc -l)
        echo $id , $prevname , $prevROI , $Entry , $T2prevx , $T2prevy , $T2prevz , $lsegment out
      fi
      echo $id , $prevname , Shallowest , $T2prevx , $T2prevy , $T2prevz , N/A , N/A , N/A , N/A
    fi
    echo $id , $elname_str , Deepest , N/A , N/A , N/A , $T2x , $T2y , $T2z , N/A
  fi
  T2prevx=$T2x; T2prevy=$T2y; T2prevz=$T2z; prevname=$elname_str;
  N=$(expr $N + 1)
done < <(cat $VOXFN) > electrode_path.txt
echo $id , $prevname , Shallowest , $T2prevx , $T2prevy , $T2prevz , N/A , N/A , N/A , N/A >> electrode_path.txt
