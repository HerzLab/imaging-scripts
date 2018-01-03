if [ $# -lt 2 ]; then
  echo Usage: $0 stage SubjectID [optarg]
  echo Example: $0 coreg R1001P [NOREG]
  echo Example: $0 loc R1001P
  echo Example: $0 norm R1001P
  echo Example: $0 walk R1001P
  exit 1
fi
stg=$1
if [ -z $RAMROOT ]; then
  echo "Please define RAMROOT to point to the top level image analysis directory"
  exit 1
fi


oldcwd=$PWD
SDIR=$(dirname $0)
cd $SDIR
SDIR=$PWD

shift
for i in $1;do
  cd $RAMROOT/${i}; 
  rm ${stg}.log
  # qsub -P RAM_DCC -q matlab.q -l h_vmem=30.1G,s_vmem=30G -cwd -j y -o ${stg}.log -V -N ${stg}$i $SDIR/${stg}.sh $*; 
  qsub  -q matlab.q -l h_vmem=30.1G,s_vmem=30G -cwd -j y -m ea -o ${stg}.log -V -N ${stg}$i $SDIR/${stg}.sh "$@";
  # no DCC #  qsub -l h_vmem=20.1G,s_vmem=20G -cwd -j y -o ${stg}.log -V -N ${stg}$i $SDIR/${stg}.sh $*; 
done

cd $oldcwd

