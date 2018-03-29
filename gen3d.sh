#! /usr/bin/env bash

discover() {
  for I in MolPort
  do mysql --login-path=local -N -e "use BABEL" -e "
    SELECT IF(Zinc_ext.ID IS NULL AND Frog.ID IS NULL,${I}.ID,''), ${I}.SMILES
    FROM ${I}
    LEFT JOIN Zinc_ext
      ON ${I}.ID = Zinc_ext.EXT_ID
    LEFT JOIN Frog
      ON ${I}.ID = Frog.EXT_ID
    WHERE NOT ${I}.SMILES LIKE '%@%'
    LIMIT 100;"|
    grep '^[A-Z]' > to_convert
  done
}

add_to_sql() {
  mysql -pa -e "use BABEL" -e "
    LOAD DATA LOCAL INFILE '$1'
    INTO TABLE ${I}
    FIELDS TERMINATED BY '\,'
    OPTIONALLY ENCLOSED BY '\"'
    LINES TERMINATED BY '\n' ;
  "
}

Frog_f() {
  tempdir=$(mktemp -d -p /tmp)
  local origin=$PWD
  (
    cd $tempdir || exit 5
    echo "$1" | www_iMolecule.py -ismi - -opdbqt "$2" -wrkPath "$tempdir" -logFile /dev/stdout &> error.log
    local pdbqts=$(find . -name \*pdbqt)
    if [ "$pdbqts" ]
    then
      mv ${pdbqts[*]} $origin/pdbqt/ 2> /dev/null
      for i in ${pdbqts[*]}
      do echo $2,$(basename ${i%.*}) >> $origin/meta/Frog.csv
      done
    else
      echo -e $1'\t'$2 >> $origin/badsmi
      cat error.log >> $origin/$2.log
    fi
  )
  rm -rf $tempdir
}
export -f Frog_f

main() {
  if [ -e "$1" ]
  then cp "$1" to_convert
  else discover
  fi
  echo Converting $(wc -l to_convert) files
  parallel --progress -j $threads --colsep '\t' Frog_f {2} {1} :::: to_convert
  add_to_sql ./meta/Frog.csv
  # rm meta/Frog.csv
}

sane() {
  for i in pdbqt meta
  do [ -e $i ] || mkdir $i
  done
  [ "$threads" -eq "$threads" ] &> /dev/null ||
  echo 'Please specify a correct thread count
  ' example $(basename $0) 10 for 10 threads
}

threads=$1
export threads

sane
main $2
