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
split_file_smi ${smi_files[@]}
echo Converting sdf input files
for i in ${count[@]}
  do babel_thread_smi $i &
done
wait
}

main_sdf() {
echo Splitting ${#sdf_files[@]} sdf files
split_file_sdf

echo Converting sdf input files
find csplit-output -type f -printf '%f\n' |
parallel --progress -j $threads -I {} obabel -i sdf csplit-output/{} -r \
--add 'abonds atoms bonds cansmi cansmiNS dbonds formula HBA1 HBA2 HBD InChI InChIKey logP MP MR MW nF sbonds tbonds title TPSA' \
-p 7.4 -m -o sdf -O babel-output/{} &> babel-logs/babel-output-$date-$1.log
rm -rf csplit-output
}

main() {
[[ "${smi_files[@]}" ]] && main_smi
[[ "${sdf_files[@]}" ]] && main_sdf

echo Second Stage: Getting Info on each file and moving them
find ./babel-output/ -type f |
parallel --progress -j $threads caser_wrap {}

echo Last Stage: Adding mySQL entries
for I in MolPort Ambinter Zinc
do for i in meta/${I:0:1}*
  do add_to_sql "$i" &> /dev/null
  rm "$i"
  done
done
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
(cd babel-output
obabel ../thread_$1.smi --gen2d --add 'formula HBA1 HBD InChIKey logP MW TPSA' \
-p 7.4 -m -o sdf -O $1_$date.sdf &> ../babel-logs/babel-output-$date-$1.log
echo Convertion of smi files in thread $1 exited
rm ../thread_$1.smi
)
}

caser_wrap() {
grep '^>' -A1 --no-group-separator $@ |
caser "$@"
}
export -f caser_wrap

caser() {
while read first ; read second
  do case "$first" in
    '>  <PUBCHEM_EXT_DATASOURCE_REGID>' ) local ID="$second" ; continue ;;
    '>  <VERIFIED_AMOUNT_MG>' ) local VERIFIED_AMOUNT_MG="$second" ; continue ;;
    '>  <UNVERIFIED_AMOUNT_MG>' ) local UNVERIFIED_AMOUNT_MG="$second" ; continue ;;
    '>  <PRICERANGE_5MG>' ) local PRICERANGE_5MG="$second" ; continue ;;
    '>  <PRICERANGE_1MG>' ) local PRICERANGE_1MG="$second" ; continue ;;
    '>  <PRICERANGE_50MG>' ) local PRICERANGE_50MG="$second" ; continue ;;
    '>  <IS_SC>' ) local IS_SC="$second" ; continue ;;
    '>  <IS_BB>' ) local IS_BB="$second" ; continue ;;
    '>  <COMPOUND_STATE>' ) local COMPOUND_STATE="$second" ; continue ;;
    '>  <QC_METHOD>' ) local QC_METHOD="$second" ; continue ;;
    '>  <smiles>' ) local SMILES="$second" ; continue ;;
    '>  <lead_like>' ) local lead_like="${!second}"  ; continue ;;
    '>  <drug_like>' ) local drug_like="${!second}"  ; continue ;;
    '>  <PPI_like>' ) local PPI_like="${!second}"  ; continue ;;
    '>  <fragment_like>' ) local fragment_like="${!second}"  ; continue ;;
    '>  <ext_fragment_like>' ) local ext_fragment_like="${!second}"  ; continue ;;
    '>  <kinase_like>' ) local kinase_like="${!second}"  ; continue ;;
    '>  <GPCR_like>' ) local GPCR_like="${!second}"  ; continue ;;
    '>  <NR_like>' )  local NR_like="${!second}"  ; continue ;;
    '>  <NP_like>' ) local NP_like="${!second}"  ; continue ;;
    '>  <is_3D>' ) local is_3d='../sdf-3d/' ; continue ;;
    '>  <abonds>' ) local abonds="$second" ; continue ;;
    '>  <atoms>' ) local atoms="$second" ; continue ;;
    '>  <bonds>' ) local bonds="$second" ; continue ;;
    '>  <cansmi>' ) local cansmi="$second" ; continue ;;
    '>  <cansmiNS>' ) local cansmiNS="$second" ; continue ;;
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


[ "$ID" ] || local \
ID=$(head -n1 $1 | cut -d '_' -f1)

[ "$SMILES" ] ||
local SMILES="$(obabel -i sdf $1 -o smiles 2> /dev/null)"

local positive=$(awk -F"+" '{print NF-1}' <<< "$SMILES")
local negative=$(awk -F"-" '{print NF-1}' <<< "$SMILES")
local hashalo=$(awk -F"F|Br|Cl|I|S" '{print NF-1}' <<< "$SMILES")
local heavyatoms=$(echo $SMILES | obabel -ismiles -otxt --append atoms -d -l5)

if [ ! "${ID:0:1}" = 'Z' ]
then
  echo "\"$ID\",\"$VERIFIED_AMOUNT_MG$lead_like\",\"$UNVERIFIED_AMOUNT_MG$drug_like\",\"$PRICERANGE_5MG$PPI_like\",\"$PRICERANGE_1MG$fragment_like\",\"$PRICERANGE_50MG$ext_fragment_like\",\"$IS_SC$kinase_like\",\"$IS_BB$GPCR_like\",\"$COMPOUND_STATE$NR_like\",\"$QC_METHOD$NP_like\",\"$SMILES\",\"$positive\",\"$negative\",\"$hashalo\",\"$heavyatoms\",\"$abonds\",\"$atoms\",\"$bonds\",\"$cansmi\",\"$cansmiNS\",\"$dbonds\",\"$formula\",\"$HBA1\",\"$HBA2\",\"$HBD\",\"$InChI\",\"$InChIKey\",\"$logP\",\"$MP\",\"$MR\",\"$MW\",\"$nF\",\"$sbonds\",\"$tbonds\",\"$TPSA\"" >> ./meta/${ID:0:1}.csv
  mv "$1" ./sdf-2d/$ID.sdf
else
  mv "$1" ./sdf-3d/$ID.sdf
  echo "\"$ID\",\"$SMILES\",\"$positive\",\"$negative\",\"$hashalo\",\"$heavyatoms\",\"$abonds\",\"$atoms\",\"$bonds\",\"$cansmi\",\"$cansmiNS\",\"$dbonds\",\"$formula\",\"$HBA1\",\"$HBA2\",\"$HBD\",\"$InChI\",\"$InChIKey\",\"$logP\",\"$MP\",\"$MR\",\"$MW\",\"$nF\",\"$sbonds\",\"$tbonds\",\"$TPSA\"" >> ./meta/Z.csv
  obabel ./sdf-3d/$ID.sdf -o pdbqt -O ./pdbqt/$ID.pdbqt &> babel-logs/babel-output-pdbqt-$date.log
fi
}
export -f caser

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
