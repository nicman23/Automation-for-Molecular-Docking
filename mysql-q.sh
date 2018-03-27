#! /usr/bin/bash
db_location='/home/common/babel'
array_opt=( Pstv Ngtv abonds atoms bonds cansmi cansmiNS dbonds formula HBA1
HBA2 HBD InChI InChIKey logP MP MR MW nF sbonds tbonds TPSA heavya)

help_txt="To search the databases you need:

1. Specify the database(s) by using the --db $(echo -e "\e[4mnameofdb\e[0m") arguement, one or multiple times

2. Optionally use filters with --max-$(echo -e "\e[4mSUFFIX\e[0m") or --min-$(echo -e "\e[4mSUFFIX\e[0m"). Available suffixes:
$(echo ${array_opt[@]} | fold -s -w 80  | sed -e "s|^|\t- |g")

When run without enough valid vina options, you will only receive the results of your query.
Otherwise the script will automatically run the resulting ligands to your specified receptor.

Vina Options:
  --zinc-mode
  --vina-threads
  --vina-log
  --vina-cfg
  --vina-rcp
  --vina-rlt
"

mysql_q() {
echo Searching $I 1>&2
if [ ! "$I" = 'Zinc' ]
  then mysql --login-path=local -N -e "use BABEL" -e "
    SELECT IF(Zinc_ext.ID IS NULL,${I}.ID,Zinc_ext.ID)
    FROM ${I}
    LEFT JOIN Zinc_ext ON ${I}.ID = Zinc_ext.EXT_ID
    $(cat -)
  ;
  "
  else mysql --login-path=local -N -e "use BABEL" -e "
    SELECT ID
    FROM ${I}
    $(cat -)
  ;
  "
fi
}


query_writer() {
for i in ${array_opt[@]}
  do line_start=WHERE
  [ "$first" ] && line_start=AND
  max_i=max_$i
  min_i=min_$i
  if [ "${!max_i}" ]
    then if [ "${!min_i}" ]
      then echo $line_start $I.\`$i\` BETWEEN ${!min_i} AND ${!max_i}
      first=0
    else echo $line_start $I.\`$i\` \<\= ${!max_i}
      first=0
    fi
    else if [ "${!min_i}" ]
      then echo $line_start $I.\`$i\` \>\= ${!min_i}
      first=0
    fi
  fi
done
echo $line_start $I.\`Halo\` $halo
}

vina_wrapper() {
out_dir=$(mktemp -d -p .)
vina_fun() {
vinaSH --cpu 4 --config $vina_cfg --ligand "$1" $vina_rcp --out $out_dir/"$2" &> /dev/null
}
export vina_cfg vina_log vina_rcp out_dir
export -f vina_fun
echo Starting Docking:
parallel --eta --progress -j $((threads/4)) --joblog /tmp/asd.log vina_fun $db_location/pdbqt/{}.pdbqt {/}.pdbqt
score() {
mv $@ $(sed '2q;d' $@ | cut -d '-' -f 2 | cut -d ' ' -f1)_$@
}
export -f score
(
cd $out_dir
echo Renaming results per score:
find . -type f -printf "%f\n" |
parallel --progress -j $threads score {/}
echo Tarring $results best results.
find . -type f -printf "%f\n" | sort -h |
tail -n $results | tar zcfv ../vinaSH-result_$(date +'%s').tar.gz \
--files-from -
)
echo Deleting temporary files
rm -rf $out_dir #results
echo Results are in vina-result_$(date +'%s').tar.gz
}

results=1000

if [ -z "$@" ] 2> /dev/null
  then echo --help for help
  exit 2
fi

creategetargs() {
echo 'function getargs() {'
  echo '  while true
    do case $1 in'
  for i in $@
    do for I in min max
      do echo -e '      '--$I-$i'  \t'\) $I\_$i=\$2 ';' shift 2 ';;'
    done
  done
  echo '      --help            ) echo "$help_txt" ; exit 2 ;;
      --db              ) DB+=($2) ; shift 2 ;;
      --zinc-mode       ) zinc_mode=1 ; shift 1 ;;
      --vina-threads    ) threads=$2 ; shift 2 ;;
      --vina-cfg        ) vina_cfg=$2 ; shift 2 ;;
      --vina-rcp        ) vina_rcp="--receptor $2" ; shift 2 ;;
      --vina-rlt        ) results="$2" ; shift 2 ;;
      '\'\''                ) break ;;
      *                 ) echo error, what is: $1 ; exit 1 ;;
    esac
  done'
echo '}'
}



eval "$(creategetargs ${array_opt[@]})"
getargs $@

db_loop() {
for I in ${DB[@]}
  do halo='= 0'
  query_writer | mysql_q
done > query
}

if [ "$vina_cfg" ]
then findoutput="$(find query -maxdepth 1 2> /dev/null)"
  if [ "$findoutput" ]
    then read -p "$(echo $findoutput) found, do you want to use it?" -n 1 -r
      if [[ $REPLY =~ ^[Nn]$ ]]
        then echo 'Searching - this could take a lot of time (see mysql threads)'
        db_loop
      fi
  else
    echo 'Searching - this could take a lot of time (see mysql threads)'
    db_loop
  fi
    echo
    if [ -e ./query ]
    then
      time cat query | vina_wrapper
    fi
else
  echo 'Searching - this could take a lot of time (see mysql threads)'
  db_loop
  read -p "Do you want the resulting pdbqts?" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  out_dir=$(mktemp -d -p .)
  (
    cd $out_dir ; mkdir results haloresults
    echo $PWD
    cat ../query | xargs -I{} cp $db_location/pdbqt/{}.pdbqt results/
    tar zcfv ../queryresults_$(date +'%s').tar.gz .
  )
  rm -rf $out_dir
fi
fi
