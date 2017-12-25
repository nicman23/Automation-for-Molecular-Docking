#! /usr/bin/env bash

discover() {
find sdf-3d sdf-2d -type f -printf "%f\n" |
sort --parallel=$threads | uniq -u > to_convert
}

main() {
[ -e "$1" ] && allthemfiles=( $(cat $1) )
[ "$allthemfiles" ] || discover
parallel -j $threads --bar -I{} babel_thread {.} :::: to_convert
}

babel_thread() {
if timeout 20s obabel sdf-2d/"$@".sdf --gen3d -o sdf \
-p 7.4 -O sdf-3d/"$@".sdf &> /dev/null
  then echo obabel -i sdf sdf-3d/"$@".sdf -o pdbqt\
  -O ./pdbqt/$@.pdbqt &> /dev/null
  else echo $@ >> bad_sdfs
fi
}
export -f babel_thread

sane() {
[ -e sdf-2d ] || exit 2
for i in sdf-3d babel-logs
  do [ -e $i ] || mkdir $i
done
[ "$threads" -eq "$threads" ] &> /dev/null ||
echo Please specify a correct thread count
echo example $(basename $0) 10 for 10 threads
}

threads=$1
sane
main $2
