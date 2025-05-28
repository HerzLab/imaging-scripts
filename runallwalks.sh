RAM=/oceanus/collab/herz-lab/raw_data/kahana/subjects/
#for dd in $RAM/*; do 
 # ID=${dd##*/}
  # for ID in $(cat mniqa.txt michal_mni_list.txt | grep ok | grep -v _| grep -v lesion | grep -v again | cut -c 1-6 | xargs); do
  for ID in $(cat ~/DARPA/run/scripts/allfirstmontage.txt); do
  export RAMROOT=$RAM/$ID/imaging 
  # if [ -s $RAMROOT/$ID/T00_${ID}_tse.nii.gz ]; then 
  if [ -s $RAMROOT/$ID/T00_${ID}_mprage/T00_${ID}_mprage_wholebrainseg.nii.gz ]; then 
    echo $ID yes;
    if [ ! -f $RAMROOT/electrode_path_t1.txt ]; then
      ./runpipeline.sh walkt1 $ID
    else
      cp electrode_path_t1.txt electrode_path_t1bkp.txt
      ./runpipeline.sh walkt1 $ID
      :
    fi
  else  
    rm electrode_path_t1.txt
    echo $ID no; 
    :
  fi; 
done
exit
for i in /oceanus/collab/herz-lab/raw_data/kahana/subjects/R*/imaging/R*/electrode_path_t1.txt; do sub=`echo $i | cut -f 5 -d "/"`; if [ -f /oceanus/collab/herz-lab/raw_data/kahana/subjects/$sub/imaging/$sub/T00_${sub}_mprage/T00_${sub}_mprage_wholebrainseg.nii.gz ]; then cat $i >> all_electrode_paths_t1.txt; fi; done
