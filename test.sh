sub=$1
fn=T01_${sub}_CT.nii
c3d ${fn}.gz -o ${fn}
echo "x,y,z,t,label,mass,volume,count" > electrode_coordinates.csv
MATLAB_ROOT=/usr/global/matlabR2011b
#$ -v LM_LICENSE_FILE=/usr/global/matlabR2011b/licenses/network.lic.rhino-matlab16 
$MATLAB_ROOT/bin/matlab $MATOPT -nodisplay <<MAT
  addpath ~sudas/bin/spm5
  addpath ~sudas/bin/localization/matlab
  coords=importdata('vox_coords.txt');
  coords=coords';
  pcoords=map_coords(coords,'${fn}');
  V=spm_vol('${fn}');
  voxvol=abs(prod(diag(V.mat)));
  fd=fopen('electrode_coordinates.csv', 'a');
  for i=1:size(pcoords, 2)
    fprintf(fd, '%f,%f,%f,%d,%d,%d,%f,%d', -pcoords(1, i), -pcoords(2, i), pcoords(3, i),0, i, i, voxvol, 1);
    fprintf(fd, '\n');
  end
  fclose(fd);
  exit
MAT
rm -f ${fn}  
