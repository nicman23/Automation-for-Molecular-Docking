db_location='.'

help_txt="--min-HBD
--max-HBD

--min-MW
--max-MW

--min-TPSA
--max-TPSA

--min-LogP
--max-LogP

--min-ΗΒΑ1
--max-ΗΒΑ1

--min-Pstv
--max-Pstv

--min-Ngtv
--max-Ngtv

--db

--zinc-mode
--vina-threads
--vina-log
--vina-cfg
--vina-rcp
--vina-rlt
"

mysql_q() {
if [ ! "$I" = 'Zinc' ] && [ ! -z "$I" ]
  then
  mysql --user=nikosf -pa -e "use BABEL" -e "
  SELECT ${I}.ID, COALESCE(Zinc_ext.ID,'')
  FROM ${I}
  LEFT JOIN Zinc_ext ON Zinc_ext.EXT_ID = ${I}.ID
  $(cat -)
  ;
  "
  else
  mysql --user=nikosf -pa -e "use BABEL" -e "
  SELECT ID
  FROM Zinc
  $(cat -)
  ;
  " | xargs -I{} echo dummy {}
fi
}

query_writer() {
I=$DB
for i in HBA1 HBD LogP MW TPSA Pstv Ngtv
  do line_start=WHERE
  [ "$first" ] && line_start=AND
  max_i=max_$i
  min_i=min_$i
  if [ "${!max_i}" ]
    then if [ "${!min_i}" ]
      then echo $line_start $I.\`$i\` BETWEEN ${!min_i} AND ${!max_i}
      first=0
      else echo $line_start $I.\`$i\` \< ${!max_i}
      first=0
    fi
    else if [ "${!min_i}" ]
      then echo $line_start $I.\`$i\` \> ${!min_i}
      first=0
    fi
  fi
done | mysql_q
}


file_writer() {
if [ $2 ]
  then echo $db_location/pdbqt/$2.pdbqt
  else if [ ! "$zinc_mode" ]
    then echo $db_location/pdbqt/$1.sdf
  fi
fi
}

if [ -z "$@" ] 2> /dev/null
  then echo --help for help
  exit 2
fi

file_writter_wrapper() {
IFS="$(echo -en '\t') "
while read line
  do file_writer $(echo $line)
done
}

vina_wrapper() {
if [ "$vina_cfg" ]
  then out_dir=$(mktemp -d -p .)
  parallel -j $threads -I{} vina --cpu 4 --config $vina_cfg --ligand {} $vina_log $vina_rcp --out $out_dir/{/}
  score() {
    mv $@ $(sed '2q;d' $@ | cut -d '-' -f 2 | cut -d ' ' -f1)_$@
  }
  export -f score
  (
  cd $out_dir
  find . -type f -printf "%f\n" |
  parallel -j $threads score {/}
  find . -type f -printf "%f\n" |
  head -n $results | tar zcfv ../vina-result_$(date +'%s').tar.gz\
  --files-from -
  )
  rm -rf $out_dir
  else cat -
fi
}

results=1000

while true
  do case $1 in
    --min-ΗΒΑ1     ) min_HBA1=$2 ; shift 2 ;;
    --max-ΗΒΑ1     ) max_HBA1=$2 ; shift 2 ;;
    --min-HBD      ) min_HBD=$2 ; shift 2 ;;
    --max-HBD      ) max_HBD=$2 ; shift 2 ;;
    --min-LogP     ) min_LogP=$2 ; shift 2 ;;
    --max-LogP     ) max_LogP=$2 ; shift 2 ;;
    --min-MW       ) min_MW=$2 ; shift 2 ;;
    --max-MW       ) max_MW=$2 ; shift 2 ;;
    --min-TPSA     ) min_TPSA=$2 ; shift 2 ;;
    --max-TPSA     ) max_TPSA=$2 ; shift 2 ;;
    --min-Pstv     ) min_Pstv=$2 ; shift 2 ;;
    --max-Pstv     ) max_Pstv=$2 ; shift 2 ;;
    --min-Ngtv     ) min_Ngtv=$2 ; shift 2 ;;
    --max-Ngtv     ) max_Ngtv=$2 ; shift 2 ;;
    --help         ) echo "$help_txt" ; exit 2 ;;
    --db           ) DB=$2 ; shift 2 ;;
    --zinc-mode    ) zinc_mode=1 ; shift 1 ;;
    --vina-threads ) threads=$((($2+3)/4)) ; shift 2 ;;
    --vina-log     ) vina_log="--log $2" ; shift 2 ;;
    --vina-cfg     ) vina_cfg=$2 ; shift 2 ;;
    --vina-rcp     ) vina_rcp="--receptor $2" ; shift 2 ;;
    --vina-rlt     ) results="$2" ; shift 2 ;;
    ''             ) break ;;
    *              ) echo error, what is: $1 ; exit 1 ;;
  esac
done

IFS='
'
query_writer | tail -n +2 | file_writter_wrapper | vina_wrapper

#find pdbqt -type f | head -n5 | vina_wrapper #debug test
