mkdir -p vols
for i in $(cat all_electrode_paths_NonDartmouth.txt | cut -f 1 -d "," | uniq); do 
  c3d data/$i/imaging/autoloc/T00_${i}_segmentation.nii.gz -dup -lstat > stats.txt
  sed 's/.*/&d/' line-numbers-to-delete-file | sed -f - stats.txt | awk '{print $7}' > vols/${i}_sfvols.txt
done

paste vols/*txt > allsfvols.txt
