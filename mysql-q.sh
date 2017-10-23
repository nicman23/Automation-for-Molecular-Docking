mysql_q() {
mysql -pa -e "use BABEL" -e "
SELECT MolPort.PUBCHEM_EXT_DATASOURCE_REGID, Zinc.ID
FROM MolPort
LEFT JOIN Zinc ON Zinc.EXT_ID = MolPort.PUBCHEM_EXT_DATASOURCE_REGID
$(cat -)
;
"
}

if [ -z "$@" ] 2> /dev/null
  then echo -h \| --help for help
  exit 2
fi

help_txt="--min-ΗΒΑ1  | -a
--min-HBD   | -d
--min-LogP  | -p
--min-MW    | -w
--min-TPSA  | -t
--max-ΗΒΑ1  | -A
--max-HBD   | -D
--max-LogP  | -P
--max-MW    | -W
--max-TPSA  | -T"

while true
  do case $1 in
    --min-ΗΒΑ1  | -a ) min_HBA1=$2 ; shift 2 ;;
    --min-HBD   | -d ) min_HBD=$2 ; shift 2 ;;
    --min-LogP  | -p ) min_LogP=$2 ; shift 2 ;;
    --min-MW    | -w ) min_MW=$2 ; shift 2 ;;
    --min-TPSA  | -t ) min_TPSA=$2 ; shift 2 ;;
    --max-ΗΒΑ1  | -A ) max_HBA1=$2 ; shift 2 ;;
    --max-HBD   | -D ) max_HBD=$2 ; shift 2 ;;
    --max-LogP  | -P ) max_LogP=$2 ; shift 2 ;;
    --max-MW    | -W ) max_MW=$2 ; shift 2 ;;
    --max-TPSA  | -T ) max_TPSA=$2 ; shift 2 ;;
    --help      | -h ) echo "$help_txt" ; exit 2 ;;
    ''               ) break ;;
    *                ) echo error ; exit 1 ;;
  esac
done

I='MolPort.'
for i in HBA1 HBD LogP MW TPSA
  do line_start=AND
  [ $first ] || line_start=WHERE
  first=0
  max_i=max_$i
  min_i=min_$i
  if [ "${!max_i}" ]
    then if [ "${!min_i}" ]
      then echo $line_start $I\`$i\` BETWEEN ${!min_i} AND ${!max_i}
      else echo $line_start $I\`$i\` \< ${!max_i}
    fi
    else if [ "${!min_i}" ]
      then echo $line_start $I\`$i\` \> ${!min_i}
    fi
  fi
done | mysql_q
