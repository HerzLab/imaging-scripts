# for i in R1001P R1002P R1004D R1005P R1006P R1011P R1014D R1015J R1017J R1018P R1019J R1020J R1021D R1022J R1023J R1025P R1026D R1027J R1030J R1031M R1033D R1035M R1036M; do
stg=$1
shift
for i in $*;do
  cd $i; 
#  rm coreg.log
#  qsub -cwd -j y -o coreg.log -V -N $i ../command.sh $i; 
#  rm norm.log
#  qsub -cwd -j y -o norm.log -V -N $i ../normalize.sh $i; 
#  cp walk.log walk.log.bkp
#  cp electrode_path.txt electrode_path_bkp.txt
#  qsub -cwd -j y -o walk.log -V -N $i ../walk2.sh ; 
  rm ${stg}.log
  qsub -q RAM.q -l h_vmem=10.1G,s_vmem=10G -cwd -j y -o ${stg}.log -V -N $i ../${stg}.sh $i; 
  cd ..; 
done

