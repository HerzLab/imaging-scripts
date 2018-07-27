#! /bin/bash

mail_result() {
    if [ $? == 0 ] ;then
      result='was successful'
    else
       result='failed'
    fi
    message="Command ${1} for subject ${2} ${result}"
    echo $message | mail -s "Imaging pipeline ${1} completed" -r ${USER}@rhino2.psych.upenn.edu ${3}
}


if [ $# -lt 2 ]; then
  echo Usage: $0 [-M email_address] stage SubjectID [optarg]
  echo Example: $0 coreg R1001P [NOREG]
  echo Example: $0 [-M anon@my_email_server.com] loc  R1001P
  echo Example: $0 norm R1001P
  echo Example: $0 walk R1001P
  exit 1
fi
if [ -z $RAMROOT ]; then
  echo "Please define RAMROOT to point to the top level image analysis directory"
  exit 1
fi
while getopts ':M:' opts; do
    case ${opts} in
        M )
            shift $((OPTIND-1))
            mail_str="mail_result ${1} ${2} ${OPTARG}"
            ;;
        \?) ;;
        \:);;
    esac
done

# TODO: make this more portable
source activate event_creation

oldcwd=$PWD
SDIR=$(dirname $0)
cd $SDIR
SDIR=$PWD

OPTIND=1

stg=$1

shift
for i in $1;do
  cd $RAMROOT/${i}; 
  #rm ${stg}.log
  # qsub -P RAM_DCC -q RAM.q -l h_vmem=30.1G,s_vmem=30G -cwd -j y -o ${stg}.log -V -N ${stg}$i $SDIR/${stg}.sh $*;
  { qsub -q RAM.q -l h_vmem=30.1G,s_vmem=30G -cwd -sync y -j y -o ${stg}.log -V -N ${stg}$i $SDIR/${stg}.sh "$@";
    eval ${mail_str}; } &
  # no DCC #  qsub -l h_vmem=20.1G,s_vmem=20G -cwd -j y -o ${stg}.log -V -N ${stg}$i $SDIR/${stg}.sh $*; 
done

cd $oldcwd

