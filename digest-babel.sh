#! /usr/bin/env bash
date=$(date +%F)

sane() {
  if [[ -z "${sdf_files[*]}" ]] && [[ -z "${smi_files[*]}" ]]
  then echo "No input file"
    exit 2
  fi
  if [ "$threads" == '0' ]
  then echo Please use a non zero thread count
    exit 3
  fi
  for i in babel-output meta sdf-2d sdf-3d babel-logs csplit-output pdbqt
  do [ -e $i ] || mkdir $i
  done
}

main_smi() {
  echo Splitting ${#smi_files[*]} smi files
  cat ${smi_files[*]} |
  parallel --progress -j $threads --pipe getinfo_smi
}

main_sdf() {
  mkdir /dev/shm/babel/
  echo Splitting ${#sdf_files[*]} sdf files
  cat ${sdf_files[*]} |
  parallel -j $threads -N1 --recend '$$$$' --pipe getinfo_convert_sdf {#}
  rm -r /dev/shm/babel/
}

main() {
  [[ "${sdf_files[*]}" ]] && main_sdf
  [[ "${smi_files[*]}" ]] && main_smi
  echo Last Stage: Adding mySQL entries
  for I in MolPort Ambinter Zinc
  do for i in meta/${I:0:1}*
    do add_to_sql "$i"
      rm "$i"
    done 2> /dev/null
  done
}

getinfo_smi() {
  while read lines
  do
    local line=($(echo "$lines" | cut -d "$(echo -e '\t')" -f -3))
    local computed=($(echo ${line[0]}| obabel -ismi -r --append 'abonds atoms bonds dbonds formula HBA1 HBA2 HBD InChI InChIKey logP MP MR MW nF sbonds tbonds TPSA' -osmi 2> /dev/null ))
    local SMILES=${computed[0]}
    local ID=${line[2]}
    local positive=$(echo "$SMILES" | awk -F"+" '{print NF-1}')
    local negative=$(echo "$SMILES" | awk -F"-" '{print NF-1}')
    local hashalo=$(echo "$SMILES" | awk -F"F|Br|Cl|I|S" '{print NF-1}')
    local heavyatoms=$(echo $SMILES | obabel -ismiles -otxt --append atoms -d 2> /dev/null)
    echo \"$ID $SMILES $positive $negative $hashalo $heavyatoms ${computed[*]:1}\"|
    sed -e 's/ /\"\,\"/g' >> ./meta/${ID:0:1}.csv
  done
}
export -f getinfo_smi

getinfo_convert_sdf() {
  tail -n+2 > /dev/shm/babel/$1.sdf

  computed=($(obabel -isdf /dev/shm/babel/$1.sdf -r --append 'abonds atoms bonds dbonds formula HBA1 HBA2 HBD InChI InChIKey logP MP MR MW nF sbonds tbonds TPSA' -osmi 2> /dev/null ))
  positive=$(echo "${computed[0]}" | awk -F"+" '{print NF-1}')
  negative=$(echo "${computed[0]}" | awk -F"-" '{print NF-1}')
  hashalo=$(echo "${computed[0]}" | awk -F"F|Br|Cl|I|S" '{print NF-1}')
  heavyatoms=$(echo ${computed[0]} | obabel -ismiles -otxt --append atoms -d 2> /dev/null)
  ID=${computed[1]}
  echo \"$ID ${computed[0]} $positive $negative $hashalo $heavyatoms ${computed[*]:2}\"|
  sed -e 's/ /\"\,\"/g' >> ./meta/${ID:0:1}.csv
  obabel -isdf /dev/shm/babel/$1.sdf -opdbqt -O "pdbqt/$ID.pdbqt" 2> /dev/null
  rm /dev/shm/babel/$1.sdf
}
export -f getinfo_convert_sdf

add_to_sql() {
  mysql -pa -e "use BABEL" -e "
    LOAD DATA LOCAL INFILE '$1'
    INTO TABLE ${I}
    FIELDS TERMINATED BY '\,'
    OPTIONALLY ENCLOSED BY '\"'
    LINES TERMINATED BY '\n' ;
  "
}

while true
  do case $1 in
    '' ) break ;;
    -T | --threads ) threads=$2 ; shift 2 ;;
    *.sdf ) if [ -e "$1" ]
        then sdf_files+=("$1")
        else echo file not found: $1
      fi ; shift 1 ;;
    *.mdl ) if [ -e "$1" ]
        then sdf_files+=("$1")
        else echo file not found: $1
      fi ; shift 1 ;;
    *.smi ) if [ -e "$1" ]
        then smi_files+=("$1")
        else echo file not found: $1
      fi ; shift 1 ;;
    *.txt ) if [ -e "$1" ]
        then smi_files+=("$1")
        else echo file not found: $1
      fi ; shift 1 ;;
    * ) shift 1 ;;
  esac
done

while read -t 1 line
  do case $line in
    '' ) break ;;
    *.sdf ) if [ -e "$line" ]
        then sdf_files+=("$line")
        else echo file not found: $line
      fi ; shift 1 ;;
    *.mdl ) if [ -e "$line" ]
        then sdf_files+=("$line")
        else echo file not found: $line
      fi ; shift 1 ;;
    *.smi ) if [ -e "$line" ]
        then smi_files+=("$line")
        else echo file not found: $line
      fi ; shift 1 ;;
    *.txt ) if [ -e "$line" ]
        then smi_files+=("$line")
        else echo file not found: $line
      fi ; shift 1 ;;
    * ) echo What is: $line ; shift 1 ;;
  esac
done

line=''

sane
main
