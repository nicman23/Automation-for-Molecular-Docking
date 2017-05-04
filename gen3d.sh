#! /usr/bin/env bash

main() {
cd sdf-2d
allthemfiles=( $(find .) )
cd ../sdf-3d
allthemdonefiles=( $(find .) )
cd ..
for i in ${allthemdonefiles[@]}
  do allthemfiles=( ${allthemfiles[@]/%$i} )
done
# compress array \#totaly not acrane bs
allthemfiles=( ${allthemfiles[@]} )

files=${#allthemfiles[@]}
divdummy=$(( files / threads ))
echo Converting sdf input files $files
exit
lastfile=0
for thread_i in ${count[@]} last
  do [ "$thread_i" = 'last' ] && wait
  babel_thread $lastfile $((lastfile + divdummy)) &
  lastfile=$((lastfile + divdummy))
done
wait
}

babel_thread() {
i=$1
while [ ! "$i" -eq "$2" ]
do obabel -i sdf ./sdf-2d/"${allthemfiles[$i]}" --gen3d -o sdf\
  -O ./sdf-3d/$(basename "${allthemfiles[$i]}")\
  &>> ./babel-logs/babel-output-gen3d-$date-thread-$thread_i.log
  i=$(( i + 1 ))
done
echo Thread $thread_i exited
}

sane() {
for i in sdf-3d babel-logs
  do [ -e $i ] || mkdir $i
done
[ -e sdf-2d ] || exit 2
[ "$threads" -eq "$threads" ] &> /dev/null ||
echo Please specify a correct thread count
count=($(eval echo {$threads..1}))
date=$(date +%F)
}

threads=$1
sane
main
