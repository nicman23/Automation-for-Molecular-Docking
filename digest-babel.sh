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
for i in ${sdf_files[@]}
  do cat $i
done | split_file_sdf | echo Found $(wc -l) molecules

echo Converting sdf input files
find csplit-output -type f -printf '%f\n' |
parallel -j $threads -I {} obabel -i sdf csplit-output/{} \
--add 'formula HBA1 HBD InChIKey logP MW TPSA InChI' \
-p 7.4 -m -o sdf -O babel-output/{} &> babel-logs/babel-output-$date-$1.log
rm -rf csplit-output
}

main() {
[[ "${smi_files[@]}" ]] && main_smi
[[ "${sdf_files[@]}" ]] && main_sdf
echo Second Stage: Getting Info on each file and moving them

find ./babel-output/ -type f |
parallel -j $threads --pipe caser_wrap
echo Please Wait for the the threads to exit
echo Last Stage: Adding mySQL entries
for I in MolPort Ambinter Zinc
do for i in meta/${I:0:1}*
  do add_to_sql "$i"
  #rm "$i"
  done
done

}

split_file_sdf() {
(cd csplit-output
csplit - /\$\$\$\$\/+1 '{*}' -z -b %02d.sdf
)
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
(cd babel-output
obabel ../thread_$1.smi --gen2d --add 'formula HBA1 HBD InChIKey logP MW TPSA' \
-p 7.4 -m -o sdf -O $1_$date.sdf &> ../babel-logs/babel-output-$date-$1.log
echo Convertion of smi files in thread $1 exited
rm ../thread_$1.smi
)
}

caser_wrap() {
true=1
false=0
NP_like=',"'
while read file
  do grep '^>' -A1 --no-group-separator $file |
  caser "$file"
done
}
export -f caser_wrap

caser() {
while read first ; read second
  do case "$first" in
    '>  <PUBCHEM_EXT_DATASOURCE_REGID>' ) local ID="$second" ; NP_like='' ; continue ;;
    '>  <VERIFIED_AMOUNT_MG>' ) local VERIFIED_AMOUNT_MG="$second" ; continue ;;
    '>  <UNVERIFIED_AMOUNT_MG>' ) local UNVERIFIED_AMOUNT_MG="$second" ; continue ;;
    '>  <PRICERANGE_5MG>' ) local PRICERANGE_5MG="$second" ; continue ;;
    '>  <PRICERANGE_1MG>' ) local PRICERANGE_1MG="$second" ; continue ;;
    '>  <PRICERANGE_50MG>' ) local PRICERANGE_50MG="$second" ; continue ;;
    '>  <IS_SC>' ) local IS_SC="$second" ; continue ;;
    '>  <IS_BB>' ) local IS_BB="$second" ; continue ;;
    '>  <COMPOUND_STATE>' ) local COMPOUND_STATE="$second" ; continue ;;
    '>  <QC_METHOD>' ) local QC_METHOD="$second" ; continue ;;
    '>  <formula>' ) local formula="$second" ; continue ;;
    '>  <HBA1>' ) local HBA1="$second" ; continue ;;
    '>  <HBD>' ) local HBD="$second" ; continue ;;
    '>  <InChIKey>' ) local InChIKey="$second" ; continue ;;
    '>  <logP>' ) local logP="$second" ; continue ;;
    '>  <MW>' ) local MW="$second" ; continue ;;
    '>  <TPSA>' ) local TPSA="$second" ; continue ;;
    '>  <smiles>' ) local SMILES="$second" ; continue ;;
    '>  <InChI>' ) local InChI="$(cut -d '	' -f 1 <<< $second)" ; continue ;;
    '>  <lead_like>' ) eval local lead_like=\$$second ; continue ;;
    '>  <drug_like>' ) eval local drug_like=\$$second ; continue ;;
    '>  <PPI_like>' ) eval local PPI_like=\$$second ; continue ;;
    '>  <fragment_like>' ) eval local fragment_like=\$$second ; continue ;;
    '>  <ext_fragment_like>' ) eval local ext_fragment_like=\$$second ; continue ;;
    '>  <kinase_like>' ) eval local kinase_like=\$$second ; continue ;;
    '>  <GPCR_like>' ) eval local GPCR_like=\$$second ; continue ;;
    '>  <NR_like>' )  eval local NR_like=\$$second ; continue ;;
    '>  <NP_like>' ) eval local NP_like=\$$second ; continue ;;
    '>  <is_3D>' ) local is_3d='../sdf-3d/' ; continue ;;
    '' ) break ;;
    * ) continue ;;
  esac
done

[ "$ID" ] || local \
ID=$(head -n1 $1 | cut -d '_' -f1)

[ "$SMILES" ] ||
local SMILES="$(obabel -i sdf $1 -o smiles)"

if [ ! "${ID:0:1}" = 'Z' ]
then
  echo "\"$ID\",\"$VERIFIED_AMOUNT_MG$lead_like\",\"$UNVERIFIED_AMOUNT_MG$drug_like\",\"$PRICERANGE_5MG$PPI_like\",\"$PRICERANGE_1MG$fragment_like\",\"$PRICERANGE_50MG$ext_fragment_like\",\"$IS_SC$kinase_like\",\"$IS_BB$GPCR_like\",\"$COMPOUND_STATE$NR_like\",\"$QC_METHOD$NP_like\",\"$HBA1\",\"$HBD\",\"$logP\",\"$MW\",\"$TPSA\",\"$formula\",\"$SMILES\",\"$InChI\",\"$InChIKey\"" >> ./meta/${ID:0:1}.csv
  mv "$1" ./sdf-2d/$ID.sdf
else
  mv "$1" ./sdf-3d/$ID.sdf
  echo "\"$ID\",\"$HBA1\",\"$HBD\",\"$logP\",\"$MW\",\"$TPSA\",\"$formula\",\"$SMILES\",\"$InChI\",\"$InChIKey\"" >> ./meta/Z.csv
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

while true; do
  case $1 in
    ''			) break ;;
    -T | --threads	) threads=$2 ; shift 2 ;;
    *.sdf		) if [ -e "$1" ]
                            then sdf_files=( $1 ${sdf_files[@]} )
                            else echo file not found: $1
                          fi ; shift 1 ;;
    *.smi		) if [ -e "$1" ]
                            then smi_files=( $1 ${smi_files[@]} )
                            else echo file not found: $1
                          fi ; shift 1 ;;
    *			) shift 1 ;;
  esac
done

sane
main
