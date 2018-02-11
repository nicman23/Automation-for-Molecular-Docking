#! /usr/bin/env bash

discover() {
find sdf-2d pdbqt -type f ! -name 'Z*' -printf "%f\n" |
sed -e 's/pdbqt/sdf/g' |
sort --parallel=$threads | uniq -u > to_convert
}

main() {
if [ -e "$1" ]
  then cp "$1" to_convert
  else discover
fi
echo Converting $(wc -l to_convert) files
parallel -j $threads babel_thread {.} :::: to_convert
}

babel_thread() {
if timeout 20s obabel sdf-2d/"$@".sdf --gen3d -o sdf \
-p 7.4 -O sdf-3d/"$@".sdf &> /dev/null
  then obabel -i sdf sdf-3d/"$@".sdf -o pdbqt\
  -O ./pdbqt/$@.pdbqt &> /dev/null
  else echo $@ >> bad_sdfs
fi
}
export -f babel_thread

sane() {
[ -e sdf-2d ] || exit 2
for i in sdf-3d babel-logs pdbqt
  do [ -e $i ] || mkdir $i
done
[ "$threads" -eq "$threads" ] &> /dev/null ||
echo 'Please specify a correct thread count
'example $(basename $0) 10 for 10 threads
}

threads=$1
export threads

sane
main $2
