#!/bin/bash 
#$ -S /bin/bash
set -x -e

##############################################################################
# INIT
#ANTSPATH=/home/avants/bin/ants
ANTSPATH=~sudas/bin/localization/ants_avants_Dec162013/
ANTSPATH=/home1/sudas/bin/ants_cook_Sep012015/
NEWANTSDIR=~/bin/ants_cook_Sep012015
PATH=$ANTSPATH:$PATH
BINDIR=~sudas/bin/localization/ashs/ext/Linux/bin

# TMPDIR
if [[ ! $TMPDIR ]]; then
  TMPDIR=$(mktemp -d)
fi

LABEL_IDS=(BKG      CA      DG  SUB ERC  BA35 BA36 PHC  CS)
LABEL_MRG=("0 7 16" "1 2 4" "3" "8" "10" "11" "12" "13" "14")
LABEL_NEW=(0        1       2   3   4    5    6    7   8)
MESH_LABEL=(CA SUB ERC BA35 BA36 PHC)
KINDS="tse mprage ${LABEL_IDS[*]}"
EVALLABELS=(CA DG SUB ERC BA35 BA36 PRC   PHC CS HIPP     EXPHIPP   ALL)
RANGES=(    1  2  3   4   5    6    "5 6" 7   8  "1 2 3"  "4 5 6 7" "1 2 3 4 5 6 7")

# Relevant labels
LABEL_FG=(CA DG SUB ERC BA35 BA36 PHC CS)
MESH_EVAL=(       CA  DG  SUB ERC BA35 BA36 PRC   PHC CS)
MESH_EVAL_RANGES=(1   2   3   4   5    6    "5 6" 7  8)
EXTRAMESHES=(HIPPO PRC ExtHippo MRG)
# EXTRAMESHESDEF=("-1  1  1 -1 -1 -1 -1 -1" \
#                 "-1  1 -1  1  1  1  1  1")
EXTRAMESHESDEF=("-1  1  1 -1 -1 -1 -1 -1 -1" \
                "-1 -1 -1 -1 -1  1  1 -1 -1" \
                "-1 -1 -1  1  1  1  1  1 -1" \
                "-1  1 -1  1  1  1  1  1 -1")


ROOT=~sudas/DARPA/Thickness
WORKDIR=$ROOT
ASHSRUNDIR=$ROOT/ashs_run
MATLABCODEDIR=$WORKDIR/matlabcode/

SUBJ_TXT=$WORKDIR/analysis_input/subj.txt

##############################################################################
# Parameters needs to be specified

# 1. Experiment number
expid=exp01
expdir=$WORKDIR/thickness
DUMPDIR=${expdir}/dump
STATDIR=$WORKDIR/analysis_input/stat${expid}/
mkdir -p ${expdir}/dump

# 2. Group settings (can be single group)
# array indicating whether certain group exits (12 max)
groups=(1)

# 3. ANTS parameters
ITER=8
ANTs_start=3
WGT=1
REG_LABELS=(${LABEL_IDS[*]})
ANTs_t="SyN[0.25]"
ANTs_r="Gauss[0.5,0]"
ANTs_i="80x80x20"
ANTs_x="Y"
ANTs_all_metrics="--use-all-metrics-for-convergence"

# 4. Mesh extraction
subfield_th=0.5
template_th=0.0

# 5. Thickness measurement
thick_p=1.2
thick_e=6

##############################################################################
function main()
{
  #reset_dir
  #copy_data
  #initial_average
  #main_loop
  #make_images
  #warp_labels
  #warp_meshes
  #evaluation
  disp_stats
  #thick_stats
}

##############################################################################
# Copy data
function copy_data()
{
  # Get the data
  mkdir -p ${expdir}/data

  # Load id number
  IDs=($(cat $SUBJ_TXT))

  # Submit job to copy data
  PREFIX=CP${expid}
  for side in left right; do

    for ((i=0;i<${#IDs[*]};i++)); do
      id=${IDs[i]}
      grp=1

      if [[ $grp != 0 ]]; then
        qsub -cwd -o $DUMPDIR -j y -N \
             "${PREFIX}_${id}_${side}_${grp}" \
             $0 copy_subject $id $side $grp
     fi

     done
  done

  # Wait for completion
  qsub -cwd -o $DUMPDIR -j y \
       -hold_jid "${PREFIX}_*" -sync y -b y \
       sleep 1
}

function copy_subject()
{
  fn=$1
  side=$2
  grp=$3
 
  # ASHS segmentation
  SEG=$ASHSRUNDIR/${fn}/final/${fn}_${side}_lfseg_corr_nogray.nii.gz

  # Link the subfield images
  if [[ -f $SEG ]]; then
    ln -sf $ASHSRUNDIR/$fn/tse_to_chunktemp_${side}.nii.gz \
           ${expdir}/data/${fn}_${side}_${grp}_tse.nii.gz
    ln -sf $ASHSRUNDIR/$fn/mprage_to_chunktemp_${side}.nii.gz \
           ${expdir}/data/${fn}_${side}_${grp}_mprage.nii.gz
  fi

  # Generate a binary image for the label
  for ((i=0;i<${#LABEL_IDS[*]};i++)); do

    c3d $SEG -replace $(for k in ${LABEL_MRG[i]}; do echo $k 999; done) -thresh 999 999 1 0 \
      -o $TMPDIR/binary_${LABEL_IDS[i]}_${fn}_${side}_${grp}.nii.gz

    WarpImageMultiTransform 3  \
      $TMPDIR/binary_${LABEL_IDS[i]}_${fn}_${side}_${grp}.nii.gz \
      ${expdir}/data/${fn}_${side}_${grp}_${LABEL_IDS[i]}.nii.gz \
      -R ${expdir}/data/${fn}_${side}_${grp}_tse.nii.gz \
      $ASHSRUNDIR/$fn/ants_t1_to_temp/ants_t1_to_tempWarp.nii.gz \
      $ASHSRUNDIR/$fn/ants_t1_to_temp/ants_t1_to_tempAffine.txt \
      $ASHSRUNDIR/$fn/flirt_t2_to_t1/flirt_t2_to_t1_ITK.txt

  done

  # Vote in the ASHS template subject space to create segmentation
  c3d $(for sub in ${LABEL_IDS[*]}; do echo ${expdir}/data/${fn}_${side}_${grp}_${sub}.nii.gz; done) \
    -vote -type ushort -o ${expdir}/data/${fn}_${side}_${grp}_seg.nii.gz
}

##############################################################################
# Average subfields
function average_subfield()
{
  side=$1
  grp=$2
  kind=$3

  # Output short images for memory considerations
  rstr=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 32)
  c3d ${expdir}/data/*_${side}_${grp}_${kind}.nii.gz -foreach -type short -endfor -oo $TMPDIR/${rstr}%02d.nii.gz
  $NEWANTSDIR/AverageImages 3 \
       ${expdir}/group${grp}/work/template_fullchunk_${side}_${grp}_${kind}.nii.gz \
       0 $TMPDIR/${rstr}*.nii.gz
  rm -f $TMPDIR/${rstr}*.nii.gz
}


function initial_average()
{
  # Compute initial average for all the groups
  PREFIX=AVG${expid}
  for grp in ${groups[*]}; do
    GROUPDIR=${expdir}/group${grp}
    mkdir -p ${GROUPDIR}/work

    # Compute initial average for each subfield mask
    for side in left right; do

      # Average all the input images
      for kind in $KINDS; do
        qsub -cwd -o $DUMPDIR -j y -N \
             "${PREFIX}_${kind}_${side}_${grp}" -l h_vmem=40.1G,s_vmem=40G $0 \
             average_subfield $side $grp $kind
      done
    done
  done

  # Wait for completion
  qsub -cwd -o $DUMPDIR -j y \
       -hold_jid "${PREFIX}_*" -sync y -b y \
       sleep 1

  # Compute the mask for all the groups
  for grp in ${groups[*]}; do

    for side in left right; do

      # Compute the initial mask for the segmentation
      c3d $(for sub in ${LABEL_IDS[*]}; do echo ${expdir}/group${grp}/work/template_fullchunk_${side}_${grp}_${sub}.nii.gz; done | grep -v BKG) \
      -mean -thresh 1e-5 inf 1 0 -trim 5vox \
      -o ${expdir}/group${grp}/work/template_mask_${side}_${grp}.nii.gz

      # Trim every template component using the mask
      for kind in $KINDS; do
        c3d ${expdir}/group${grp}/work/template_mask_${side}_${grp}.nii.gz \
          ${expdir}/group${grp}/work/template_fullchunk_${side}_${grp}_${kind}.nii.gz -reslice-identity \
          -o ${expdir}/group${grp}/work/template_${side}_${grp}_${kind}.nii.gz
      
      done
    done
  done
}

#############################################################################
# Take the one that is most similar to others as the initial template
function initialization
{
  # Initialization for all the groups
  for grp in ${groups[*]}; do

    GROUPDIR=${expdir}/group${grp}
    mkdir -p ${GROUPDIR}/work

    # Compute initial average for each subfield mask to generate mask
    PREFIX=AVG${expid}
    for side in left right; do

      # Average all the input images
      for kind in $KINDS; do
        qsub -cwd -o $DUMPDIR -j y -N \
             "${PREFIX}_${kind}_${side}_${grp}" -l h_vmem=40.1G,s_vmem=40G $0 \
             average_subfield $side $grp $kind
      done
    done
  done

  # Wait for completion
  qsub -cwd -o $DUMPDIR -j y \
       -hold_jid "${PREFIX}_*" -sync y -b y \
       sleep 1

  # Compute the mask for all the groups and cp init template
  for grp in ${groups[*]}; do

    i=$((grp-1))
    for side in left right; do

      if [[ ${side} == "left" ]]; then 
        INIT=${INIT_ID_left[i]}
      else
        INIT=${INIT_ID_right[i]}
      fi

      id=$(ls $ASHSRUNDIR | grep $INIT)

      # Compute the initial mask for the segmentation
      c3d $(for sub in ${LABEL_IDS[*]}; do echo ${expdir}/group${grp}/work/template_fullchunk_${side}_${grp}_${sub}.nii.gz; done | grep -v BKG) \
      -mean -thresh 1e-5 inf 1 0 -trim 5vox \
      -o ${expdir}/group${grp}/work/template_mask_${side}_${grp}.nii.gz

      # Trim every template component using the mask
      for kind in $KINDS; do
        
        c3d ${expdir}/group${grp}/work/template_mask_${side}_${grp}.nii.gz \
          ${expdir}/data/${id}_${side}_${grp}_${kind}.nii.gz \
          -reslice-identity \
          -o ${expdir}/group${grp}/work/template_${side}_${grp}_${kind}.nii.gz

      done
    done
  done
}

##############################################################################
# Build template using ANTs
function shape_update_to_template()
{

  side=$1
  grp=$2

  # Borrowed from ANTS buildtemplateparallel

  # Average the warp fields
  local TEMPWARP=${expdir}/group${grp}/work/template_${side}_${grp}_warp.nii.gz
  rstr=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 32)
  c3d ${expdir}/group${grp}/work/*_${side}_${grp}_totempWarp.nii.gz -foreach -type short -endfor -oo $TMPDIR/${rstr}%02d.nii.gz

  $NEWANTSDIR/AverageImages 3 $TEMPWARP 0 \
    $TMPDIR/${rstr}*.nii.gz

  rm -f $TMPDIR/${rstr}*.nii.gz

  # Scale by -0.25 (gradient step)
  MultiplyImages 3 $TEMPWARP -0.25 $TEMPWARP

  # Create a new template affine
  local TEMPAFF=${expdir}/group${grp}/work/template_${side}_${grp}_Affine.txt
  if [[ -f $TEMPAFF ]]; then rm -rf $TEMPAFF; fi

  cat ${expdir}/group${grp}/work/*_${side}_${grp}_totempAffine.txt \
    | grep '^Parameters:' | awk '\
    BEGIN { for(i=0;i<12;i++) x[i]=0} \
    { for(i=0;i<12;i++) x[i]=x[i]+$(i+2) } \
    END { \
      printf "Transform: MatrixOffsetTransformBase_double_3_3\nParameters: "; \
      for(i=0;i<12;i++) printf "%f ",x[i]/NR; \
      printf "\nFixedParameters: 0 0 0\n";}' > $TEMPAFF

  # Compose the warps
  WarpImageMultiTransform 3 $TEMPWARP $TEMPWARP -i $TEMPAFF \
    -R ${expdir}/group${grp}/work/template_${side}_${grp}_tse.nii.gz

  TEMPWARPFULL=${expdir}/group${grp}/work/template_${side}_${grp}_fullwarp.nii.gz
  # trap "{ echo Composing done $?;  }" EXIT
  echo "Will compose transform now"
  $ANTSPATH/ComposeMultiTransform 3 \
    $TEMPWARPFULL -R ${expdir}/group${grp}/work/template_${side}_${grp}_tse.nii.gz \
    -i $TEMPAFF $TEMPWARP $TEMPWARP $TEMPWARP $TEMPWARP

  cp ${expdir}/group${grp}/work/template_${side}_${grp}_fullwarp.nii.gz \
    ${expdir}/group${grp}/work/template_${side}_${grp}_fullwarp_bkp.nii.gz

  # Apply this warp to all the template derivatives
  for kind in $KINDS; do

    echo "kind = $kind"
    WarpImageMultiTransform 3 \
      ${expdir}/group${grp}/work/template_${side}_${grp}_${kind}.nii.gz \
      ${expdir}/group${grp}/work/template_${side}_${grp}_${kind}.nii.gz \
      $TEMPWARPFULL

  done
  echo "Applied composed warp"
}

function ants_iter()
{
  id=$1
  side=$2
  grp=$3
  doants=$4

  # Before we vote, use ml_affine for nice affine alignment
  ~/bin/localization/ashs/ext/Linux/bin/ml_affine \
    ${expdir}/group${grp}/work/template_${side}_${grp}_seg.nii.gz \
    ${expdir}/data/${id}_${side}_${grp}_seg.nii.gz \
    ${expdir}/group${grp}/work/${id}_${side}_${grp}_mlaffine.txt

  # Do we do ANTS or not?
  if [[ $doants -eq 0 ]]; then

    for sub in $KINDS; do

      c3d \
        ${expdir}/group${grp}/work/template_${side}_${grp}_tse.nii.gz \
        ${expdir}/data/${id}_${side}_${grp}_${sub}.nii.gz \
        -reslice-matrix \
        ${expdir}/group${grp}/work/${id}_${side}_${grp}_mlaffine.txt \
        -o ${expdir}/group${grp}/work/${id}_${side}_${grp}_totemp_reslice_${sub}.nii.gz 

    done

  else

    # Convert that to ITK format
    c3d_affine_tool \
      ${expdir}/group${grp}/work/${id}_${side}_${grp}_mlaffine.txt \
      -oitk ${expdir}/group${grp}/work/${id}_${side}_${grp}_mlaffine_itk.txt

    #WGT=$(echo ${#REG_LABELS[*]} | awk '{print 1.0 / $1}')

    CMD=""
    for sub in ${REG_LABELS[*]}; do
      CMD="$CMD -m MSQ[${expdir}/group${grp}/work/template_${side}_${grp}_${sub}.nii.gz,${expdir}/data/${id}_${side}_${grp}_${sub}.nii.gz,$WGT]"
    done

    if [[ $ANTs_x == "Y" ]]; then
       ANTs_mask="-x ${expdir}/group${grp}/work/template_mask_${side}_${grp}.nii.gz"
    else
       ANTs_mask=""
    fi

    ANTS 3 $CMD \
      -t $ANTs_t \
      -r $ANTs_r \
      -i $ANTs_i \
      $ANTs_mask \
      -a ${expdir}/group${grp}/work/${id}_${side}_${grp}_mlaffine_itk.txt \
      --continue-affine 0 \
      $ANTs_all_metrics \
      -o ${expdir}/group${grp}/work/${id}_${side}_${grp}_totemp.nii.gz \
      | tee ${expdir}/group${grp}/work/${id}_${side}_${grp}_antsoutput.txt

#    ANTS 3 $CMD -t SyN[0.25] -r Gauss[3,0.5] -i 80x80x20 \
#      -x ${expdir}/group${grp}/work/template_mask_${side}_${grp}.nii.gz \
#      -a ${expdir}/group${grp}/work/${id}_${side}_${grp}_mlaffine_itk.txt \
#      --continue-affine 0 \
#      --use-all-metrics-for-convergence \
#      -o ${expdir}/group${grp}/work/${id}_${side}_${grp}_totemp.nii.gz \
#      | tee ${expdir}/group${grp}/work/${id}_${side}_${grp}_antsoutput.txt
    
    for sub in $KINDS; do

      WarpImageMultiTransform 3 \
        ${expdir}/data/${id}_${side}_${grp}_${sub}.nii.gz \
        ${expdir}/group${grp}/work/${id}_${side}_${grp}_totemp_reslice_${sub}.nii.gz \
        -R ${expdir}/group${grp}/work/template_${side}_${grp}_tse.nii.gz \
        ${expdir}/group${grp}/work/${id}_${side}_${grp}_totempWarp.nii.gz \
        ${expdir}/group${grp}/work/${id}_${side}_${grp}_totempAffine.txt

    done

  fi
}


function main_loop
{
  # Main iteration loop
  PREFIX=ANTs${expid}
  for side in left right; do

    for ((iter=0;iter<$ITER;iter++)); do
      
      for grp in ${groups[*]}; do
    
        # Create the segmentation for the template
        c3d $(for sub in ${LABEL_IDS[*]}; do echo ${expdir}/group${grp}/work/template_${side}_${grp}_${sub}.nii.gz; done) \
          -vote -type ushort \
          -o ${expdir}/group${grp}/work/template_${side}_${grp}_seg.nii.gz

        # Back up template
        ITDIR=${expdir}/group${grp}/work/$(printf iter_%s_%02d $side $iter)
        mkdir -p $ITDIR
        cp -a ${expdir}/group${grp}/work/template_${side}_*.nii.gz $ITDIR/

        # Do ants?
        if [[ $iter -lt $ANTs_start ]]; then doants=0; else doants=1; fi
      
        IDS=$(ls ${expdir}/data | grep ${side}_${grp}_tse | sed -e "s/_${side}_${grp}_tse.nii.gz//")

        # Run ANTS for each image
        for id in $IDS; do

          #Submit ANTS job
          qsub -cwd -o $DUMPDIR -j y -N \
               "${PREFIX}_${id}_${side}_${grp}" $0 \
               ants_iter $id $side $grp $doants

        done

      done

      # Wait for completion
      qsub -cwd -o $DUMPDIR -j y \
        -hold_jid "${PREFIX}_*" -sync y -b y \
        sleep 1

      # If this is the last iteration, we don't want to recompute the template
      if [[ $iter -lt $((ITER-1)) ]]; then

        for grp in ${groups[*]}; do
      
          # Compute average images
          for kind in $KINDS; do

            if [[ $kind = "tse" ]]; then NORM=1; else NORM=0; fi
            rstr=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 32)
            c3d ${expdir}/group${grp}/work/*_${side}_${grp}_totemp_reslice_${kind}.nii.gz -foreach -type short -endfor -oo $TMPDIR/${rstr}%02d.nii.gz

            $NEWANTSDIR/AverageImages 3 ${expdir}/group${grp}/work/template_${side}_${grp}_${kind}.nii.gz $NORM $TMPDIR/${rstr}*.nii.gz
            rm -f $TMPDIR/${rstr}*.nii.gz

          done
        
          # Perform shape averaging
          if [[ $doants -eq 1 ]]; then
            shape_update_to_template $side $grp
#            qsub -cwd -o $DUMPDIR -j y -N \
#               "${PREFIX}_shapeupdate_${side}_${grp}" $0 \
#                shape_update_to_template $side $grp
#                 # Wait for completion
#            qsub -cwd -o $DUMPDIR -j y \
#              -hold_jid "${PREFIX}_shapeupdate*" -sync y -b y \
#              sleep 1

          fi

        done

      fi

    done

  done
}

##############################################################################
# Make images for further analysis
function make_images()
{
  for grp in ${groups[*]}; do

    for side in left right; do

      # Generate one compound label for all other subfields
      ITDIR=${expdir}/group${grp}/work/$(printf iter_%s_%02d $side $((ITER-1)) )
      for ((i=0;i<${#EXTRAMESHES[*]};i++)); do

        LABELDEF=(${EXTRAMESHESDEF[i]})
        echo $LABELDEF

        c3d $(for ((j=0;j<${#LABEL_IDS[*]};j++)); do echo "${expdir}/group${grp}/work/template_${side}_${grp}_${LABEL_IDS[j]}.nii.gz -scale ${LABELDEF[j]}"; done) \
          -accum -add -endaccum \
          -o $ITDIR/template_${side}_${grp}_${EXTRAMESHES[i]}.nii.gz

      done

      # for each subject
      IDS=$(ls ${expdir}/data | grep ${side}_${grp}_tse \
        | sed -e "s/_${side}_${grp}_tse.nii.gz//")

      for id in $IDS; do

      # Create seg for each subject
      c3d $(for sub in ${LABEL_IDS[*]}; do echo ${expdir}/group${grp}/work/${id}_${side}_${grp}_totemp_reslice_${sub}.nii.gz; done) -vote -type ushort \
        -o ${expdir}/group${grp}/work/${id}_${side}_${grp}_totemp_reslice_seg.nii.gz

      done
    done
  done

}

##############################################################################
# Measurement dice overlap when warp template back to original subject space
# Warp labels back to subject space and vote 
function warp_labels()
{
  PREFIX=WL${expid}
  for grp in ${groups[*]}; do

    mkdir -p ${expdir}/group${grp}/labelwarp

    # Iterate over side and subject
    for side in left right; do

      IDS=$(ls ${expdir}/data | grep ${side}_${grp}_tse | sed -e "s/_${side}_${grp}_tse.nii.gz//")

      for id in $IDS; do

        # Submit job for this subject
        qsub -cwd -o $DUMPDIR -j y \
          -N "${PREFIX}_${id}_${side}_${grp}" \
          $0 warp_labels_subj $id $side $grp

      done   
    done
  done

  # Wait for completion
  qsub -cwd -o $DUMPDIR -j y \
    -hold_jid "${PREFIX}_*" -sync y -b y \
    sleep 1
}

function warp_labels_subj()
{
  id=$1
  side=$2
  grp=$3
  
  # Apply the warp to each of the labels
  for sub in ${LABEL_IDS[*]}; do

    SEG=$ASHSRUNDIR/${id}/final/${id}_${side}_lfseg_corr_nogray.nii.gz

    antsApplyTransforms -d 3 \
      -r $SEG \
      -i ${expdir}/group${grp}/work/template_${side}_${grp}_${sub}.nii.gz \
      -o ${expdir}/group${grp}/labelwarp/${id}_${side}_${grp}_${sub}_tempfit.nii.gz \
      -t [$ASHSRUNDIR/${id}/flirt_t2_to_t1/flirt_t2_to_t1_ITK.txt,1] \
      -t [$ASHSRUNDIR/${id}/ants_t1_to_temp/ants_t1_to_tempAffine.txt,1] \
      -t $ASHSRUNDIR/${id}/ants_t1_to_temp/ants_t1_to_tempInverseWarp.nii \
      -t [${expdir}/group${grp}/work/${id}_${side}_${grp}_totempAffine.txt,1] \
      -t ${expdir}/group${grp}/work/${id}_${side}_${grp}_totempInverseWarp.nii.gz \
      -n BSpline

  done

  # Vote in original subject space to get the tempfit segmentation
  c3d $(for sub in ${LABEL_IDS[*]}; do echo ${expdir}/group${grp}/labelwarp/${id}_${side}_${grp}_${sub}_tempfit.nii.gz; done) -vote -type ushort \
    -o ${expdir}/group${grp}/labelwarp/${id}_${side}_${grp}_seg_tempfit.nii.gz


  # change ASHS labels to the current formate
  for ((i=0;i<${#LABEL_IDS[*]};i++)); do

    SEG=$ASHSRUNDIR/${id}/final/${id}_${side}_lfseg_corr_nogray.nii.gz

    c3d $SEG \
      -replace $(for k in ${LABEL_MRG[i]}; do echo $k 999; done) \
      -thresh 999 999 1 0 \
      -o ${expdir}/group${grp}/labelwarp/${id}_${side}_${grp}_${LABEL_IDS[i]}_ashs.nii.gz 
  done

  c3d $(for sub in ${LABEL_IDS[*]}; do echo ${expdir}/group${grp}/labelwarp/${id}_${side}_${grp}_${sub}_ashs.nii.gz; done) -vote -type ushort \
    -o ${expdir}/group${grp}/labelwarp/${id}_${side}_${grp}_seg_ashs.nii.gz
}

##############################################################################
# Extract meshes for the subfields and apply warps to these meshes. This allows us to# perform statistical analysis on the mesh boundaries
function warp_meshes()
{
  PREFIX=WM${expid}
  for grp in ${groups[*]}; do

    mkdir -p ${expdir}/group${grp}/meshwarp
    mkdir -p ${expdir}/group${grp}/jacobian
    mkdir -p ${expdir}/group${grp}/meshwarp/template

    # Iterate over side and subject
    for side in left right; do

      # Generate meshes for the individual subfields
      for sub in ${LABEL_FG[*]}; do

        $BINDIR/vtklevelset \
          ${expdir}/group${grp}/work/template_${side}_${grp}_${sub}.nii.gz \
          ${expdir}/group${grp}/meshwarp/template_${side}_${grp}_${sub}.vtk \
          $subfield_th

      done

      # Generate one mesh for all non-DG non-CS subfields
      ITDIR=${expdir}/group${grp}/work/$(printf iter_%s_%02d $side $((ITER-1)) )
      for ((i=0;i<${#EXTRAMESHES[*]};i++)); do

        $BINDIR/vtklevelset \
          $ITDIR/template_${side}_${grp}_${EXTRAMESHES[i]}.nii.gz \
          ${expdir}/group${grp}/meshwarp/template_${side}_${grp}_${EXTRAMESHES[i]}.vtk \
          $template_th

      done

      IDS=$(ls ${expdir}/data | grep ${side}_${grp}_tse | sed -e "s/_${side}_${grp}_tse.nii.gz//")
    
      for id in $IDS; do

        # Submit job for this subject
        qsub  -cwd -o $DUMPDIR -j y \
          -N "${PREFIX}_${id}_${side}_${grp}" \
          $0 warp_meshes_subj $id $side $grp

      done

    done
  
  done

  # Wait for completion
  qsub -cwd -o $DUMPDIR -j y \
       -hold_jid "${PREFIX}_*" -sync y -b y \
       sleep 1

  for grp in ${groups[*]}; do
    cp ${expdir}/group${grp}/meshwarp/template*.vtk \
       ${expdir}/group${grp}/meshwarp/template/
  done
}

function warp_meshes_subj()
{
  id=$1
  side=$2
  grp=$3
  ALLSF="${LABEL_FG[*]} ${EXTRAMESHES[*]}"
  
  # Compose the transformation between the template and the subject
  $ANTSPATH/ComposeMultiTransform 3 \
     $TMPDIR/compose.nii \
     -R ${expdir}/group${grp}/work/template_${side}_${grp}_tse.nii.gz \
     ${expdir}/group${grp}/work/${id}_${side}_${grp}_totempWarp.nii.gz \
     ${expdir}/group${grp}/work/${id}_${side}_${grp}_totempAffine.txt \
     $ASHSRUNDIR/${id}/ants_t1_to_temp/ants_t1_to_tempWarp.nii \
     $ASHSRUNDIR/${id}/ants_t1_to_temp/ants_t1_to_tempAffine.txt \
     $ASHSRUNDIR/${id}/flirt_t2_to_t1/flirt_t2_to_t1_ITK.txt

  # Split the transformations into xyz
  c3d -mcs $TMPDIR/compose.nii -oo $TMPDIR/comp%02d.nii

  # Apply the warp to each of the meshes
  for sub in $ALLSF; do

    # Warp the subfield into subject space
    $BINDIR/warpmesh -w ants -m ras \
      ${expdir}/group${grp}/meshwarp/template_${side}_${grp}_${sub}.vtk \
      ${expdir}/group${grp}/meshwarp/${id}_${side}_${grp}_${sub}_tempfit.vtk \
      $TMPDIR/comp00.nii $TMPDIR/comp01.nii $TMPDIR/comp02.nii

    # Extract the thickness of the subfield
    $BINDIR/cmrep_vskel -Q ~/bin/localization/ashs/ext/Linux/bin/qvoronoi \
      -T ${expdir}/group${grp}/meshwarp/${id}_${side}_${grp}_${sub}_thickmap.vtk \
      -p $thick_p -e $thick_e \
      ${expdir}/group${grp}/meshwarp/${id}_${side}_${grp}_${sub}_tempfit.vtk \
      ${expdir}/group${grp}/meshwarp/skel_${id}_${side}_${grp}_${sub}.vtk

  done

  # Compute the Jacobian map
  ANTSJacobian 3 $TMPDIR/compose.nii \
    ${expdir}/group${grp}/jacobian/${id}_${side}_${grp}_totemp 1
}

##############################################################################
# Evaluate the performance
# compute dice of mask
# compute dice of none DG none CS overlap
# compute mesh difference

function evaluation()
{
  EVALDIR=${expdir}/evaluation
  EVALTMPDIR=$EVALDIR/tmp
  rm -rf $EVALTMPDIR
  mkdir -p $EVALTMPDIR

  PREFIX=EV${expid}
  for grp in ${groups[*]}; do

    # Iterate over side and subject
    for side in left right; do

      IDS=$(ls ${expdir}/data | grep ${side}_${grp}_tse | sed -e "s/_${side}_${grp}_tse.nii.gz//")

      for id in $IDS; do

        # Submit job for this subject
        qsub -cwd -o $DUMPDIR -j y \
          -N "${PREFIX}_${id}_${side}_${grp}" \
          $0 eval_subj $id $side $grp $EVALTMPDIR
        sleep 0.1

      done
    done
  done

  # Wait for completion
  qsub -cwd -o $DUMPDIR -j y \
       -hold_jid "${PREFIX}_*" -sync y -b y \
       sleep 1

  # Combine scores
  #IDs=($(cat $SUBJ_TXT))
  for side in left right; do

    IDS=$(ls ${expdir}/data | grep ${side}_1_tse | sed -e "s/_${side}_1_tse.nii.gz//")

    echo "ID ${EVALLABELS[*]} ${MESH_EVAL[*]} ${EVALLABELS[*]}" \
      > $EVALDIR/overlap_${side}.txt

    for ids in $IDS; do

      file=$(ls $EVALTMPDIR | grep ^${ids}_${side})
      cat $EVALTMPDIR/$file \
          >> $EVALDIR/overlap_${side}.txt

    done

  done
}

function eval_subj()
{
  id=$1
  side=$2
  grp=$3
  EVALTMPDIR=$4
  ALLOVL=""
  
  ###################################
  # Compute dice overlap in subject space
  FITTED=${expdir}/group${grp}/labelwarp/${id}_${side}_${grp}_seg_tempfit.nii.gz
  ASHSSEG=${expdir}/group${grp}/labelwarp/${id}_${side}_${grp}_seg_ashs.nii.gz
  do_pair $ASHSSEG $FITTED
  ALLOVL="$ALLOVL $FULLOVL"

  ###################################
  # Compute H distance
  MESH_DIST=""
  for ((i=0;i<${#MESH_EVAL[*]};i++)); do
    
    c3d $ASHSSEG \
      -replace $(for k in ${MESH_EVAL_RANGES[i]}; do echo $k 999; done) \
      -thresh 999 999 1 0 \
      -trim 2mm -resample 100x100x300% \
      -o $TMPDIR/mask_seg.nii.gz
 
    $BINDIR/vtklevelset $TMPDIR/mask_seg.nii.gz $TMPDIR/mask_seg.vtk 0.5
    SIZE=$(cat $TMPDIR/mask_seg.vtk | wc -l)
    if [[ $SIZE -gt 6 ]]; then

      MESH_DIST_TMP="$($BINDIR/meshdiff ${expdir}/group${grp}/meshwarp/${id}_${side}_${grp}_${MESH_EVAL[i]}_tempfit.vtk $TMPDIR/mask_seg.vtk | grep RESULT | awk '{print $7}')"

      if [[ $MESH_DIST_TMP == "" ]]; then
        MESH_DIST="$MESH_DIST NA"
      else
        MESH_DIST="$MESH_DIST $MESH_DIST_TMP"
      fi

    else 

      MESH_DIST="$MESH_DIST NA"

    fi

  done

  ALLOVL="$ALLOVL $MESH_DIST"

  ###################################
  # Compute dice overlap in template space
  do_pair ${expdir}/group${grp}/work/template_${side}_${grp}_seg.nii.gz ${expdir}/group${grp}/work/${id}_${side}_${grp}_totemp_reslice_seg.nii.gz
  ALLOVL="$ALLOVL $FULLOVL"

  ###################################
  # save to temporary file
  echo $id $ALLOVL > $EVALTMPDIR/${id}_${side}_overlap.txt
}

function do_pair()
{
  # Get a pair of segmentations
  seg_a=$1
  seg_b=$2

  # out dice file
  #out_dice_file=$3
  
  # Iterate over all relevant labels
  FULLOVL=""
  for ((i=0; i<${#EVALLABELS[*]}; i++)); do

    # Do the analysis on full-size meshes
    REPRULE=$(for lab in ${RANGES[i]}; do echo $lab 99; done)

    # Extract the binary images and compute overlap
    c3d \
      $seg_a -dup $seg_b -int 0 -reslice-identity \
      -foreach -replace $REPRULE -thresh 99 99 1 0 -endfor \
      -overlap 1 | tee $TMPDIR/ovl.txt

    # Get the full-extent overlap
    OVL=$(cat $TMPDIR/ovl.txt | grep OVL | awk -F '[ ,]+' '{print $6}')

    #echo $id ${LABELS[i]} full $OVL $DIST >> $out_file
    FULLOVL="$FULLOVL $OVL"
    
  done

  # Save this temporary dice file
  #echo $id $FULLOVL > $out_dice_file
}

##############################################################################
# Display statistics
ALLSF="${LABEL_FG[*]} MRG"
function disp_stats()
{
  PREFIX=STATS${expid}
  for grp in ${groups[*]}; do
    
    rm -rf ${expdir}/group${grp}/meshwarp/analysis
    mkdir -p ${expdir}/group${grp}/meshwarp/analysis

    for side in left right; do
      for sub in $ALLSF; do

        # Submit job for this subject
  #      qsub -cwd -o $DUMPDIR -j y \
  #        -N "${PREFIX}_${side}_${grp}_${sub}" \
  #        $0 disp_stats_sub $side $grp $sub
           disp_stats_sub $side $grp $sub

      done
    done
  done

  # Wait for completion
  #qsub -cwd -o $DUMPDIR -j y \
  #     -hold_jid "${PREFIX}_*" -sync y -b y \
  #     sleep 1
}

function disp_stats_sub()
{
  side=$1
  grp=$2
  sub=$3

  # TODO following lines appear to be different from Long's 101 script but should do the same thing

  #IDS=$(ls ${expdir}/data | grep ${side}_${grp}_tse | sed -e "s/_${side}_${grp}_tse.nii.gz//")
  #IDS=$(cat $WORKDIR/group/IDs_grp${expid}/subjID_${side}_${grp}.txt)
  IDS=$(cat $SUBJ_TXT)

  # Displacement analysis
  MESHES=$(for id in $IDS; do \
    echo $(find ${expdir}/group${grp}/meshwarp | grep ${expdir}/group${grp}/meshwarp/${id}_${side}_${grp} | grep ${sub}_tempfit ); done)

  $BINDIR/meshdisp $MESHES \
    ${expdir}/group${grp}/meshwarp/analysis/disp_${side}_${grp}_${sub}.vtk

  # Thickness analysis
  MESHES=$(for id in $IDS; do \
    echo $(find ${expdir}/group${grp}/meshwarp | grep ${expdir}/group${grp}/meshwarp/${id}_${side}_${grp} | grep ${sub}_thickmap ); done)

  $BINDIR/mesh_merge_arrays \
    -r ${expdir}/group${grp}/meshwarp/template_${side}_${grp}_${sub}.vtk \
    ${expdir}/group${grp}/meshwarp/analysis/thick_${side}_${grp}_${sub}.vtk \
    Thickness $MESHES

}

##############################################################################
# For thickness analysis, we can run analysis on multiple groups of meshes at once
ANGRP[0]="MRG DG"
ANGRP[1]="CA DG SUB ERC BA35 BA36"

GRPNM[0]="merged"
GRPNM[1]="all"

function thick_stats()
{
  PREFIX=THICK${expid}
  for grp in ${groups[*]}; do

    for side in left right; do

     for design in $(ls $STATDIR | grep "design_.*txt" | grep $side | grep $grp ); do

        exp=$(echo $design | sed -e "s/^design_${side}_${grp}_//" | sed -e "s/\.txt//")

        for ((igrp=0;igrp<${#ANGRP[*]};igrp++)); do

          # Submit job for this subject
          qsub -cwd -o $DUMPDIR -j y \
            -N "${PREFIX}_${exp}_${side}_${grp}_${GRPNM[igrp]}" \
            $0 thick_stats_sub $exp $side $grp $igrp

        done
      done
    done
  done

  # Wait for completion
  qsub -cwd -o $DUMPDIR -j y \
       -hold_jid "${PREFIX}_*" -sync y -b y \
       sleep 1
}

function thick_stats_sub()
{
  exp=$1
  side=$2
  grp=$3
  igrp=$4

  MYGRP=${ANGRP[igrp]}
  GNAME=${GRPNM[igrp]}

  # Create the work directory for this analysis
  WORK=${expdir}/group${grp}/meshwarp/analysis/design_${exp}_group_${GNAME}
  mkdir -p $WORK
  rm -rf $WORK/*

  # Merge the meshes for this analysis
  for sub in $MYGRP; do

    # Get the list of subjects
    DESIGNTXT=$WORKDIR/analysis_input/stat${expid}/design_${side}_${grp}_${exp}.txt
    SUBJ=$(cat $DESIGNTXT | awk '{print $1}')

    # Generate the design matrix for meshglm
    cat $DESIGNTXT | awk '{$1=""; print}' > $WORK/design_${side}.txt

    MESHES=$(for id in $SUBJ; do \
      echo $(find ${expdir}/group${grp}/meshwarp | grep "${id}.*_${side}_${grp}_${sub}_thickmap.vtk"); done)

    $BINDIR/mesh_merge_arrays -r \
      ${expdir}/group${grp}/meshwarp/template_${side}_${grp}_${sub}.vtk \
      $WORK/thick_${side}_${grp}_${sub}.vtk Thickness $MESHES

  done

  # Go through the list of contrasts
  for con in $(ls $STATDIR | grep "contrast_${exp}_.*\.txt"); do

    # Get the suffix for this contrast
    suffix=$(echo $con | sed -e "s/^contrast_${exp}_//" -e "s/\.txt//")

    # Create the directory for this contrast
    CWORK=$WORK/contrast_${suffix}
    mkdir -p $CWORK

    FULLNM="design_${exp}_group_${GNAME}_con_${suffix}"

    # Copy the contrast
    cp $STATDIR/$con $CWORK/contrast.txt

    # Build the list of meshes to include
    MESHPARAM=""
    for sub in $MYGRP; do
      MESHPARAM="$MESHPARAM -m $WORK/thick_${side}_${grp}_${sub}.vtk $CWORK/thickstat_${FULLNM}_${side}_${grp}_${sub}.vtk"

      $BINDIR/meshglm $MESHPARAM \
        -g $WORK/design_${side}.txt $CWORK/contrast.txt \
        -a Thickness

    done
  done
}

##############################################################################
function reset_dir()
{
  #rm -rf data
  #rm -rf ${expdir}/work ${expdir}/meshwarp ${expdir}/jacobian ${expdir}/segerrormap
  rm -rf ${expdir}/dump/*
}


##############################################################################
if [[ $1 == "copy_subject" ]]; then

  copy_subject $2 $3 $4

elif [[ $1 == "average_subfield" ]]; then

  average_subfield $2 $3 $4

elif [[ $1 == "ants_iter" ]]; then

  ants_iter $2 $3 $4 $5

elif [[ $1 == "warp_labels_subj" ]]; then

  warp_labels_subj $2 $3 $4

elif [[ $1 == "warp_meshes_subj" ]]; then

  warp_meshes_subj $2 $3 $4

elif [[ $1 == "eval_subj" ]]; then

  eval_subj $2 $3 $4 $5

elif [[ $1 == "disp_stats_sub" ]]; then

  disp_stats_sub $2 $3 $4

elif [[ $1 == "shape_update" ]]; then

  shape_update_to_template $2 $3 

elif [[ $1 == "thick_stats_sub" ]]; then

  thick_stats_sub $2 $3 $4 $5

else

  main

  exit

fi

