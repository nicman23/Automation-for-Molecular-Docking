#! /usr/bin/env bash
date=$(date +%F)
threads=$(grep -c ^processor /proc/cpuinfo)

sane() {
if [[ -z "${sdf_files[@]}" ]] && [[ -z "${smi_files[@]}" ]]
  then echo "No input file"
  exit 2
fi
if [ "$threads" == '0' ]
  then echo Please use a non zero thread count
  exit 3
  else count=($(eval echo {$threads..1}))
fi
for i in babel-output meta sdf-2d
  do [ -e $i ] || mkdir $i
done
}

main_smi() {
split_file_smi ${smi_files[@]}
echo Converting sdf input files
for i in ${count[@]}
  do babel_thread_smi $i &
done
wait
}

main_sdf() {
thread_prepare_sdf
for i in ${sdf_files[@]}
  do split_file_sdf $i
done
echo Converting sdf input files
for i in ${count[@]}
  do babel_thread_sdf $i &
done
wait
}

main() {
[[ "${smi_files[@]}" ]] && main_smi
[[ "${sdf_files[@]}" ]] && main_sdf
echo Second Stage: Getting Info on each file and moving them
for thread_i in ${count[@]}
  do local=( $(find ./babel-output/ -mindepth 1 -name $thread_i'*') )
  caser_wrap &
done
echo Please Wait for the the threads to exit
wait
echo Last Stage: Adding mySQL entries
for i in meta/*
  do add_to_sql "$i"
  rm "$i"
done
}

thread_prepare_sdf() {
files=0
for i in ${sdf_files[@]}
  do files=$(( files + 1 ))
done
divdummy=$(( files / threads ))
[ "$divdummy" == '0' ] && return 0
i=0
thread=1
repeat=$(eval echo {1..$divdummy})
while [ ! $thread -gt $threads ]
  do for I in $repeat
    do cat ${sdf_files[$i]} >> thread_$thread.sdf
    unset sdf_files[$i]
    i=$(( i + 1 ))
  done
  thread=$((thread + 1))
done
}

split_file_sdf() {
lines=$(cat $@ | wc -l)
lines_avg=$(( lines / threads ))
last_line=1
for i in ${count[@]}
  do echo Splitting File $1: $i/$threads times
  cat $@ | sed -n $last_line,$(( lines_avg + last_line ))p >> thread_$i.sdf
  last_line=$(( last_line + lines_avg ))
  if [ "$i" == '1' ]
    then cat $@ | tail -n +$(( last_line + 1 )) >> thread_1.sdf
    else reader_line=$(reader_sdf $@ $i)
    last_line=$reader_line
  fi
done
}

reader_sdf() {
cat $@ | tail -n +$last_line | while read line
  do echo $line >> thread_$2.sdf
  last_line=$(( last_line + 1 ))
  if [ "$line" = '$$$$' ]
    then echo $last_line
    break
  fi
done
}

babel_thread_sdf() {
cd babel-output
babel ../thread_$1.sdf --add 'formula HBA1 HBD InChIKey logP MW TPSA' -m -o sdf $1_$date.sdf &> ./babel-output-$date-$1.log
echo Convertion of sdf files in thread $1 exited
rm ../thread_$1.sdf
}

split_file_smi() {
lines=$(cat $@ | wc -l)
lines_avg=$(( lines / threads ))
last_line=1
for i in ${count[@]}
  do echo Splitting smi Files $i/$threads times
  cat $@ | sed -n $last_line,$(( lines_avg + last_line ))p >> thread_$i.smi
  last_line=$(( last_line + lines_avg ))
  if [ "$i" == '1' ]
    then cat $@ | tail -n +$(( last_line + 1 )) >> thread_1.smi
  fi
done
}

babel_thread_smi() {
cd babel-output
babel ../thread_$1.smi --gen2d --add 'formula HBA1 HBD InChIKey logP MW TPSA' -m -o sdf $1_$date.sdf &> ./babel-output-$date-$1.log
echo Convertion of smi files in thread $1 exited
rm ../thread_$1.smi
}

caser_wrap() {
i=0
while [ ! -z "${local[$i]}" ]
  do caser $(grep '^>' -A1 --no-group-separator ${local[$i]} | tr -d '<> ')
  i=$(( i + 1 ))
done
sleep 2s
echo Thread $thread_i exited
}

caser() {
while true; do
  case $1 in
    PUBCHEM_EXT_DATASOURCE_REGID ) local PUBCHEM_EXT_DATASOURCE_REGID="$2" ; shift 2 ;;
    PUBCHEM_EXT_SUBSTANCE_URL ) local PUBCHEM_EXT_SUBSTANCE_URL="$2" ; shift 2 ;;
    PUBCHEM_EXT_DATASOURCE_URL ) local PUBCHEM_EXT_DATASOURCE_URL="$2" ; shift 2 ;;
    VERIFIED_AMOUNT_MG ) local VERIFIED_AMOUNT_MG="$2" ; shift 2 ;;
    UNVERIFIED_AMOUNT_MG ) local UNVERIFIED_AMOUNT_MG="$2" ; shift 2 ;;
    PRICERANGE_5MG ) local PRICERANGE_5MG="$2" ; shift 2 ;;
    PRICERANGE_1MG ) local PRICERANGE_1MG="$2" ; shift 2 ;;
    PRICERANGE_50MG ) local PRICERANGE_50MG="$2" ; shift 2 ;;
    IS_SC ) local IS_SC="$2" ; shift 2 ;;
    IS_BB ) local IS_BB="$2" ; shift 2 ;;
    COMPOUND_STATE ) local COMPOUND_STATE="$2" ; shift 2 ;;
    QC_METHOD ) local QC_METHOD="$2" ; shift 2 ;;
    formula ) local formula="$2" ; shift 2 ;;
    HBA1 ) local HBA1="$2" ; shift 2 ;;
    HBD ) local HBD="$2" ; shift 2 ;;
    InChIKey ) local InChIKey="$2" ; shift 2 ;;
    logP ) local logP="$2" ; shift 2 ;;
    MW ) local MW="$2" ; shift 2 ;;
    TPSA ) local TPSA="$2" ; shift 2 ;;
    '' ) break ;;
    * ) echo hi $1 ; shift 1;;
  esac
done
[ "$PUBCHEM_EXT_DATASOURCE_REGID" ] || local PUBCHEM_EXT_DATASOURCE_REGID=$(head -n1 ${local[$i]})
echo \"\",\""$PUBCHEM_EXT_DATASOURCE_REGID"\",\""$PUBCHEM_EXT_SUBSTANCE_URL"\",\""$VERIFIED_AMOUNT_MG"\",\""$UNVERIFIED_AMOUNT_MG"\",\""$PRICERANGE_5MG"\",\""$PRICERANGE_1MG"\",\""$PRICERANGE_50MG"\",\""$IS_SC"\",\""$IS_BB"\",\""$COMPOUND_STATE"\",\""$QC_METHOD"\",\""$formula"\",\""$HBA1"\",\""$HBD"\",\""$InChIKey"\",\""$logP"\",\""$MW"\",\""$TPSA"\"  >> ./meta/$thread_i.csv
mv "${local[$i]}" ./sdf-2d/$PUBCHEM_EXT_DATASOURCE_REGID.sdf
}

add_to_sql() {
mysql -u nikosf -pa -e "use BABEL" -e "
      LOAD DATA LOCAL INFILE '$@'
      INTO TABLE Molecules
      FIELDS TERMINATED BY ','
      OPTIONALLY ENCLOSED BY '\"'
      LINES TERMINATED BY '\n' ;
"
}


while true; do
  case $1 in
    ''			) break ;;
    -T | --threads	) threads=$2 ; shift 2 ;;
    *.sdf		) [ -e "$1" ] && sdf_files=( $1 ${sdf_files[@]} ) ; shift 1 ;;
    *.smi		) [ -e "$1" ] && smi_files=( $1 ${smi_files[@]} ) ; shift 1 ;;
    *			) shift 1 ;;
  esac
done

sane
main
wait
