#! /usr/bin/env bash
date=$(date +%F)

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
for i in babel-output meta sdf-2d sdf-3d babel-logs csplit-output pdbqt
  do [ -e $i ] || mkdir $i
done
}

main_smi() {
echo Getting Info on each file and moving them
echo ${smi_files[@]} | xargs cat |
parallel --progress -j $threads --pipe getinfo_smi

echo Last Stage: Adding mySQL entries
for I in MolPort Ambinter Zinc
do for i in meta/${I:0:1}*
  do add_to_sql "$i" &> /dev/null
  rm "$i"
  done
done
}

main_sdf() {
echo Splitting ${#sdf_files[@]} sdf files
split_file_sdf

echo Converting sdf input files
find csplit-output -type f -printf '%f\n' |
parallel --progress -j $threads -I {} obabel -i sdf csplit-output/{} -r \
--add 'abonds atoms bonds dbonds formula HBA1 HBA2 HBD InChI InChIKey logP MP MR MW nF sbonds tbonds TPSA' \
-m -o sdf -O babel-output/{} &> babel-logs/babel-output-$date-$1.log
rm -rf csplit-output

echo Second Stage: Getting Info on each file and moving them
find ./babel-output/ -type f |
parallel --progress -j $threads getinfo_sdf {}

echo Last Stage: Adding mySQL entries
for I in MolPort Ambinter Zinc
do for i in meta/${I:0:1}*
  do add_to_sql "$i" &> /dev/null
  rm "$i"
  done
done
}

main() {
[[ "${sdf_files[@]}" ]] && main_sdf
[[ "${smi_files[@]}" ]] && main_smi
}

csplit_sdf() {
csplit $1 /\$\$\$\$\/+1 '{*}' -z -b %02d$2
}
export -f csplit_sdf

split_file_sdf() (
cd csplit-output
for i in ${sdf_files[@]}
  do echo ../$i
done |
parallel --progress -j $threads csplit_sdf {} {/} |
echo Found $(wc -l) molecules
)

getinfo_smi() {
local line=($(cut -d '	' -f -3))
local computed=($(echo ${line[0]}| obabel -ismi -r --append 'abonds atoms bonds dbonds formula HBA1 HBA2 HBD InChI InChIKey logP MP MR MW nF sbonds tbonds TPSA' -osmi 2> /dev/null ))
local SMILES=${computed[0]}
local ID=${line[2]}
local positive=$(awk -F"+" '{print NF-1}' <<< "$SMILES")
local negative=$(awk -F"-" '{print NF-1}' <<< "$SMILES")
local hashalo=$(awk -F"F|Br|Cl|I|S" '{print NF-1}' <<< "$SMILES")
local heavyatoms=$(echo $SMILES | obabel -ismiles -otxt --append atoms -d 2> /dev/null)
echo \"$ID $SMILES $positive $negative $hashalo $heavyatoms ${computed[@]:1}\"|
sed -e 's/ /\"\,\"/g' >> ./meta/${ID:0:1}.csv
}
export -f getinfo_smi

getinfo_sdf() {
grep '^>' -A1 --no-group-separator $@ |
while read first ; read second
  do case "$first" in
    '>  <abonds>' ) local abonds="$second" ; continue ;;
    '>  <atoms>' ) local atoms="$second" ; continue ;;
    '>  <bonds>' ) local bonds="$second" ; continue ;;
    '>  <dbonds>' ) local dbonds="$second" ; continue ;;
    '>  <formula>' ) local formula="$second" ; continue ;;
    '>  <HBA1>' ) local HBA1="$second" ; continue ;;
    '>  <HBA2>' ) local HBA2="$second" ; continue ;;
    '>  <HBD>' ) local HBD="$second" ; continue ;;
    '>  <InChI>' ) local InChI="$second" ; continue ;;
    '>  <InChIKey>' ) local InChIKey="$second" ; continue ;;
    '>  <logP>' ) local logP="$second" ; continue ;;
    '>  <MP>' ) local MP="$second" ; continue ;;
    '>  <MR>' ) local MR="$second" ; continue ;;
    '>  <MW>' ) local MW="$second" ; continue ;;
    '>  <nF>' ) local nF="$second" ; continue ;;
    '>  <sbonds>' ) local sbonds="$second" ; continue ;;
    '>  <tbonds>' ) local tbonds="$second" ; continue ;;
    '>  <TPSA>' ) local TPSA="$second" ; continue ;;    '' ) break ;;
    * ) continue ;;
  esac
done

ID=$(head -n1 $1 | cut -d '_' -f1)
local SMILES="$(obabel -i sdf $1 -o smiles 2> /dev/null)"

local positive=$(awk -F"+" '{print NF-1}' <<< "$SMILES")
local negative=$(awk -F"-" '{print NF-1}' <<< "$SMILES")
local hashalo=$(awk -F"F|Br|Cl|I|S" '{print NF-1}' <<< "$SMILES")
local heavyatoms=$(echo $SMILES | obabel -ismiles -otxt --append atoms -d 2> /dev/null)

mv "$1" ./sdf-3d/$ID.sdf
echo "\"$ID\",\"$SMILES\",\"$positive\",\"$negative\",\"$hashalo\",\"$heavyatoms\",\"$abonds\",\"$atoms\",\"$bonds\",\"$dbonds\",\"$formula\",\"$HBA1\",\"$HBA2\",\"$HBD\",\"$InChI\",\"$InChIKey\",\"$logP\",\"$MP\",\"$MR\",\"$MW\",\"$nF\",\"$sbonds\",\"$tbonds\",\"$TPSA\"" >> ./meta/${ID:0:1}.csv
obabel ./sdf-3d/$ID.sdf -o pdbqt -O ./pdbqt/$ID.pdbqt &> babel-logs/babel-output-pdbqt-$date.log
}
export -f getinfo_sdf

add_to_sql() {
mysql -pa -e "use BABEL" -e "
      LOAD DATA LOCAL INFILE '$@'
      INTO TABLE ${I}
      FIELDS TERMINATED BY '\,'
      OPTIONALLY ENCLOSED BY '\"'
      LINES TERMINATED BY '\n' ;
"
}

while true
  do case $1 in
    -T | --threads	) threads=$2 ; shift 2 ;;
    *.sdf		) if [ -e "$1" ]
                            then sdf_files+=("$1")
                            else echo file not found: $1
                          fi ; shift 1 ;;
    *.smi		) if [ -e "$1" ]
                            then smi_files+=("$1")
                            else echo file not found: $1
                          fi ; shift 1 ;;
    ''			) break ;;
    *			) shift 1 ;;
  esac
done

while read -t 1 line
  do case $line in
    ''			) break ;;
    *.sdf               ) if [ -e "$line" ]
                            then sdf_files+=("$line")
                            else echo file not found: $line
                          fi ; shift 1 ;;
    *.smi               ) if [ -e "$line" ]
                            then smi_files+=("$line")
                            else echo file not found: $line
                          fi ; shift 1 ;;
    *                   ) echo What is: $line ; shift 1 ;;
  esac
done

line=''
true=1
false=0

sane
main
