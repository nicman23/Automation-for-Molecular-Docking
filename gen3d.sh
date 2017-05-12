#! /usr/bin/env bash

main() {
cd sdf-2d
echo Finding 2d files
allthemfiles=( $(find .) )
echo Found: ${#allthemfiles[@]}
cd ../sdf-3d
echo Finding 3d Files
allthemdonefiles=( $(find .) )
echo Found: ${#allthemdonefiles[@]}
cd ..
echo Removing already computed 3d files from array

#this made me rethink life, our place in the universe and the upcoming singularity
allthemfiles=($(echo "${allthemdonefiles[@]} ${allthemfiles[@]}" | tr ' ' '\n' | sort | uniq -u))
files=${#allthemfiles[@]}
divdummy=$(( files / threads ))
echo Converting sdf input files $files
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
do echo "${allthemfiles[$i]}" >> ./babel-logs/babel-output-gen3d-$date-thread-$thread_i.log
  timeout 20s obabel -i sdf ./sdf-2d/"${allthemfiles[$i]}" --gen3d -o sdf\
  -O ./sdf-3d/$(basename "${allthemfiles[$i]}")\
  &>> ./babel-logs/babel-output-gen3d-$date-thread-$thread_i.log
  if [ ! "$?" == '0' ]
    then echo "${allthemfiles[$i]}" >> bad_sdfs &
  fi
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
