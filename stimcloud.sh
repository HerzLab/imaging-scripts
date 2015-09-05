CH2=~sudas/DARPA/ch2.nii.gz
# Initialize
c3d $CH2 -scale 0 -o stimcontacts_mni.nii.gz
cat StimulatedElectrodes.csv | sed -n '2,$p' | while read line; do
  echo $line
  sub=$(echo $line | cut -f 1 -d ",")
  contact=$(echo $line | cut -f 2 -d ",")
  mnifn=/data10/RAM/subjects/$sub/imaging/autoloc/electrodelabels_and_coordinates_mni_mid.csv
  unset mniline
  mniline=$(grep "$contact" $mnifn )
  if [ -z $mniline ]; then
    echo "$sub $contact not found"
  else
    echo "$sub $contact exists"
    echo mniline is $mniline
    grep "$contact" $mnifn  | awk -F "," '{print $3,$4,$5,$7}' > lmMNI_mid.txt
    c3d $CH2 -scale 0 -landmarks-to-spheres lmMNI_mid.txt 2 -o thiscontact.nii.gz
    c3d stimcontacts_mni.nii.gz thiscontact.nii.gz -thresh 1 inf 1 0 -add -o stimcontacts_mni.nii.gz
  fi
done

