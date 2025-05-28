#!/bin/bash
# set -x 
#
ROOTDIR=~/wd/Pfizer/ADC/long/structural
ROOTDIR=~/wd/Josh/long
OLDROOTDIR=~/wd/ADNI2/long
ROOTDIR=~/wd/ADNI2/longBLT1
ROOTDIR=~/wd/7T/Corey
ROOTDIR=~/wd/7T/long
ROOTDIR=~/wd/ADNI2/long
ROOTDIR=~/wd/DARPA/long
# for sub in $(cat /home/srdas/wd/Pfizer/ADC/hippospm/all_2mm_T00.txt); do



#COL_QA_COMMENT=$(head -n 1 $ROOTDIR/ADNI_1.8.14_withsubfield.csv | awk  -F "," '{for(i=1;i<NF;i++)printf i " " $i "\n"}' | grep " QA_COMMENT"$ | awk '{print $1}')
# for sub in $(tail -n +2 $ROOTDIR/analysis_input/subj.txt); do
# for sub in $(cat $ROOTDIR/sub_noqa_feb042014.txt); do
IDS=($(cat $ROOTDIR/*_S_*/dates.txt | awk '{print $1}'))
tps=($(cat $ROOTDIR/*_S_*/dates.txt | awk '{print $2}'))
IDS=(TJ053_1 TJ060)
tps=(T00 T00)
IDS=($(cat $ROOTDIR/cbica_sublist.txt))
IDS=($(cat $ROOTDIR/sub_t1only_ge_adni2.txt))
IDS=(YHC11)
IDS=(012_S_4849)
IDS=($(cat $ROOTDIR/ashsrun_12242014.txt | grep T00 | awk '{print $1}' ))
tps=($(cat $ROOTDIR/ashsrun_12242014.txt | grep T00 | awk '{print $2}' ))
IDS=($(cat $ROOTDIR/missingthickness_20150204.txt | grep T00 | awk '{print $1}' ))
tps=($(cat $ROOTDIR/missingthickness_20150204.txt | grep T00 | awk '{print $2}' ))
IDS=(CTL11_S1 CTL13_S1 CTL14_S1 TLE08_S1 TLE10_S1 TLE12_S1 TLE14_S1 TLE13_S1 TLE17_S1 TLE18_S1 TLE19_S1 TLE20_S1 TLE21_S1 TLE06_S1 TLE07_S1 TLE09_S1 TLE11_S1)
IDS=($(cat $ROOTDIR/newfrozenpaper/needdirect.txt | awk '{print $1}' ))
tps=($(cat $ROOTDIR/newfrozenpaper/needdirect.txt | awk '{print $2}' ))
IDS=(R1045E)

for ((i=0;i<${#IDS[*]};i++)); do
# for id in $IDS; do
  sub=${IDS[i]}
#  tp=${tps[i]}
  tp=T00

#  RID=${sub:6:9};
#  line=$(grep ^${RID} $ROOTDIR/ADNI_1.8.14_withsubfield.csv);
#  if [ "$line" != "" ]; then
#    QA=$(echo $line | cut -f $COL_QA_COMMENT -d ",");
#    if [[ $QA -le 1 ]]; then

      OUTDIR=$ROOTDIR/$sub/$tp/thickness
      OLDOUTDIR=$OLDROOTDIR/$sub/$tp/thickness
#  cp -pr $ROOTDIR/$sub/T00/thickness $ROOTDIR/$sub/T00/thickness_old
      if [ ! -f $OUTDIR/${sub}CorticalThicknessNormalizedToTemplate.nii.gz ]; then
      #rm -rf $OUTDIR
      mkdir -p $OUTDIR/dump
      #exe="./ProcessADNISubject.sh $OUTDIR/../../${tp}_${sub}_mprage_N4corrected.nii.gz $OUTDIR/ $sub" 
      exe="./ProcessADNISubject.sh $OUTDIR/../../${tp}_${sub}_mprage.nii.gz $OUTDIR/ $sub" 
      WAIT=TRUE
      while [ "$WAIT" == "TRUE" ]; do
        Njobs=`qstat | grep dir  | wc -l`
        if [ $Njobs -lt 4 ]; then
          WAIT=FALSE
          echo $Njobs jobs running, will run subject $sub
        else
          echo $Njobs jobs running, will wait subject $sub
          sleep 60
        fi
      done
      #qsub  -V -N dir${sub} -o $OUTDIR/dump -e $OUTDIR/dump -j y -pe serial 4 -l h_vmem=30.1G,s_vmem=30G -wd $OUTDIR $exe
      qsub  -V -N DP${sub} -o $OUTDIR/dump -e $OUTDIR/dump -j y -l h_vmem=10.1G,s_vmem=10G -wd $OUTDIR $exe
      #qalter -p -1023 dir${sub}
      else
        echo $id $tp exists
      fi
      sleep 0.2
#    fi
#  fi
done
