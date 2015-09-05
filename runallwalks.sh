RAM=/data10/RAM/subjects
#for dd in $RAM/*; do 
 # ID=${dd##*/}
  # for ID in R1002P R1027J R1014D R1008J R1006P R1011P R1026D R1024E; do
  for ID in R1014D R1008J R1006P R1011P R1026D R1024E ; do
  export RAMROOT=$RAM/$ID/imaging 
  if [ -s $RAMROOT/$ID/T00_${ID}_tse.nii.gz ]; then 
    echo $dd yes;
    if [ ! -f $RAMROOT/electrode_path.txt ]; then
      ./runpipeline.sh walk $ID
    else
      cp electrode_path.txt electrode_path_bkp08052015.txt
      ./runpipeline.sh walk $ID
      :
    fi
  else  
    echo $dd no; 
    :
  fi; 
done
