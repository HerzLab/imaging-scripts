set -x
CH2=~sudas/DARPA/ch2.nii.gz
RDIR=~sudas/bin/localization/template_to_NickOasis
faffine=$RDIR/ch22t0GenericAffine.mat
fwarp=$RDIR/ch22t1Warp.nii.gz
finversewarp=$RDIR/ch22t1InverseWarp.nii.gz
CH2=~sudas/DARPA/ch2.nii.gz

tsub=R1291M_1
tdir=/data10/RAM/subjects/$tsub/imaging/autoloc
# Initialize
c3d $CH2 -scale 0 -o ${tsub}_stimcontacts_mni.nii.gz
cp ${tsub}_stimcontacts_mni.nii.gz ${tsub}_stimdeltarec_mni.nii.gz
c3d $tdir/T00_${tsub}_mprage.nii.gz -scale 0 -o ${tsub}_stimcontacts_target_T1.nii.gz
cp ${tsub}_stimcontacts_target_T1.nii.gz ${tsub}_stimdeltarec_target_T1.nii.gz
c3d $tdir/T01_${tsub}_CT.nii.gz -scale 0 -o ${tsub}_stimcontacts_target_CT.nii.gz
cp ${tsub}_stimcontacts_target_CT.nii.gz ${tsub}_stimdeltarec_target_CT.nii.gz

fn=StimulatedElectrodes.csv
fn=closedloop_stimlocations.csv
# fn=teststim.csv
N=0
echo $(cat $fn | sed -n '1p'),MNI_x,MNI_y,MNI_z,T1_x,T1_y,T1_z,CT_x,CT_y,CT_z,FS_x,FS_y,FS_z > ${tsub}_allcoords.csv
cat $fn | sed -n '2,$p' | grep R1033D | while read line; do
  echo $line
  sub=$(echo $line | cut -f 1 -d ",")
  contact=$(echo $line | cut -f 2 -d ",")
  task=$(echo $line | cut -f 3 -d ",")
  deltarec=$(echo $line | cut -f 4 -d ",")
  enhance=$(echo $line | cut -f 5 -d ",")
  if [ "$enhance" == "FALSE" ]; then
    mask=1
  else
    mask=5
  fi
  mnifn=/data10/RAM/subjects/$sub/imaging/autoloc/electrodelabels_and_coordinates_mni_mid.csv
  unset mniline
  mniline=$(grep "$contact" $mnifn )
  if [ "$mniline" == "" ]; then
    echo "$sub $contact not found"
  else
    echo "$sub $contact exists"
    echo mniline is $mniline
    grep "$contact" $mnifn  | awk -F "," '{print $3,$4,$5,$7}' > ${tsub}_lmMNI_mid.txt

    outline="${line},$(grep "$contact" $mnifn  | awk -F "," '{print $3,$4,$5}' OFS=',')"

    # Take the contacts into a target subject's space
    echo "x,y,z,t,label,mass,volume,count" > ${tsub}_test.csv
    # Change from Nifti to ITK coordinates
    grep "$contact" $mnifn | awk -F',' '{print -1*$3, -1*$4, $5, $6, $7, $8, $9, $10}' OFS=',' >> ${tsub}_test.csv
    mv ${tsub}_test.csv ${tsub}_electrode_coordinates_mni_mid.csv
    
    c3d_affine_tool $tdir/T01_CT_to_T00_mprageANTs0GenericAffine_RAS.mat -oitk ${tsub}_T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt 
    # Change to T1, and CT space
    ~sudas/bin/ants/antsApplyTransformsToPoints -d 3 -i ${tsub}_electrode_coordinates_mni_mid.csv -o ${tsub}_electrode_coordinates_mni_mid_tsub_CT.csv \
      -t $fwarp -t $faffine \
      -t $tdir/T00/thickness/${tsub}TemplateToSubject1Warp.nii.gz -t $tdir/T00/thickness/${tsub}TemplateToSubject0GenericAffine.mat \
      -t ${tsub}_T01_CT_to_T00_mprageANTs0GenericAffine_RAS_itk.txt
    ~sudas/bin/ants/antsApplyTransformsToPoints -d 3 -i ${tsub}_electrode_coordinates_mni_mid.csv -o ${tsub}_electrode_coordinates_mni_mid_tsub_T1.csv \
      -t $fwarp -t $faffine \
      -t $tdir/T00/thickness/${tsub}TemplateToSubject1Warp.nii.gz -t $tdir/T00/thickness/${tsub}TemplateToSubject0GenericAffine.mat 
    # Change from ITK to Nifti coordinates
    cat ${tsub}_electrode_coordinates_mni_mid_tsub_CT.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3, $5}'  > ${tsub}_lmMNI_mid_tsub_CT.txt
    cat ${tsub}_electrode_coordinates_mni_mid_tsub_T1.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3, $5}'  > ${tsub}_lmMNI_mid_tsub_T1.txt

    tsub_T1_coords=$(cat ${tsub}_electrode_coordinates_mni_mid_tsub_T1.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3}' OFS=',')
    tsub_CT_coords=$(cat ${tsub}_electrode_coordinates_mni_mid_tsub_CT.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3}' OFS=',')
    outline="${outline},${tsub_T1_coords},${tsub_CT_coords}" 
    echo "$(echo $tsub_T1_coords | sed -e 's/,/ /g') 1" | tr -s ' ' '\n' > ${tsub}_vector.txt

MATLAB_ROOT=/usr/global/matlabR2011b
#$ -v LM_LICENSE_FILE=/usr/global/lmgrd-R2015a/licenses/network.lic.rhino2
$MATLAB_ROOT/bin/matlab $MATOPT -nodisplay <<MAT
  addpath ~sudas/bin/spm5
  addpath ~sudas/bin/localization/matlab
  coords=importdata('${tsub}_vector.txt')
  fd=fopen('${tsub}_fsvector.txt', 'w');
  [status,Norig]=system(strcat('mri_info --vox2ras /data/eeg/freesurfer/subjects/','${tsub}','/mri/orig.mgz'))
  [status,Torig]=system(strcat('mri_info --vox2ras-tkr /data/eeg/freesurfer/subjects/','${tsub}','/mri/orig.mgz'))
  fscoords=str2num(Torig)*inv(str2num(Norig))*coords;
  fprintf(fd, '%f,%f,%f\n',fscoords(1),fscoords(2),fscoords(3));
  fclose(fd);
  exit
MAT

    fscoords=$(cat ${tsub}_fsvector.txt)
    outline="${outline},${fscoords}"

    echo deltarec is $deltarec
    # Make MNI space spheres
    c3d $CH2 -scale 0 -landmarks-to-spheres ${tsub}_lmMNI_mid.txt 2 -o ${tsub}_thiscontact.nii.gz
    echo $(grep "$contact" $mnifn  | awk -F "," '{print $3,$4,$5}') $deltarec > ${tsub}_lmMNI_mid.txt
    c3d $CH2 -scale 0 -landmarks-to-spheres ${tsub}_lmMNI_mid.txt 2 -o ${tsub}_thiscontact_deltarec.nii.gz
    c3d ${tsub}_stimcontacts_mni.nii.gz ${tsub}_thiscontact.nii.gz -thresh 1 inf 1 0 -scale $mask -add -o ${tsub}_stimcontacts_mni.nii.gz
    c3d ${tsub}_stimdeltarec_mni.nii.gz ${tsub}_thiscontact_deltarec.nii.gz  -add -o ${tsub}_stimdeltarec_mni.nii.gz

    
    # Make target CT space spheres
    c3d $tdir/T01_${tsub}_CT.nii.gz -scale 0 -landmarks-to-spheres ${tsub}_lmMNI_mid_tsub_CT.txt 2 -o ${tsub}_thiscontact.nii.gz
    echo $(cat ${tsub}_electrode_coordinates_mni_mid_tsub_CT.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3}') $deltarec  > ${tsub}_lmMNI_mid_tsub_CT.txt
    c3d $tdir/T01_${tsub}_CT.nii.gz -scale 0 -landmarks-to-spheres ${tsub}_lmMNI_mid_tsub_CT.txt 2 -o ${tsub}_thiscontact_deltarec.nii.gz
    c3d ${tsub}_stimcontacts_target_CT.nii.gz ${tsub}_thiscontact.nii.gz -thresh 1 inf 1 0 -scale $mask -add -o ${tsub}_stimcontacts_target_CT.nii.gz
    c3d ${tsub}_stimdeltarec_target_CT.nii.gz ${tsub}_thiscontact_deltarec.nii.gz -add -o ${tsub}_stimdeltarec_target_CT.nii.gz

    # Make target T1 space spheres
    c3d $tdir/T00_${tsub}_mprage.nii.gz -scale 0 -landmarks-to-spheres ${tsub}_lmMNI_mid_tsub_T1.txt 2 -o ${tsub}_thiscontact.nii.gz
    echo $(cat ${tsub}_electrode_coordinates_mni_mid_tsub_T1.csv | sed -n '2,$p' | awk -F',' '{print -1*$1, -1*$2, $3}') $deltarec  > ${tsub}_lmMNI_mid_tsub_T1.txt
    c3d $tdir/T00_${tsub}_mprage.nii.gz -scale 0 -landmarks-to-spheres ${tsub}_lmMNI_mid_tsub_T1.txt 2 -o ${tsub}_thiscontact_deltarec.nii.gz
    c3d ${tsub}_stimcontacts_target_T1.nii.gz ${tsub}_thiscontact.nii.gz -thresh 1 inf 1 0 -scale $mask -add -o ${tsub}_stimcontacts_target_T1.nii.gz
    c3d ${tsub}_stimdeltarec_target_T1.nii.gz ${tsub}_thiscontact_deltarec.nii.gz -add -o ${tsub}_stimdeltarec_target_T1.nii.gz


    N=$(expr $N + 1 )
    echo $outline >> ${tsub}_allcoords.csv
  fi
done
echo N is $N
N=$(echo  "1 / $N" | bc -l )
# c3d stimdeltarec_mni.nii.gz -scale $N -o stimdeltarec_mean_mni.nii.gz

