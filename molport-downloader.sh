#! /usr/bin/env bash
url="ftp://$@@www.molport.com/molport_database/"
done_txt="/home/common/babel/.molport_downloader"
db_location='/home/common/babel'

remove_done() {
for i in ${already_done[@]}
  do date=( ${date[@]/$i} )
done
}

download_sdf() {
date=( $(curl $url | grep '^d' | rev | cut -d ' ' -f1 | rev | grep -P '(?<!\d)\d{4}(?!\d)-(?<!\d)\d{2}(?!\d)') )
remove_done
if [ "$first_run" == '1' ]
  then echo ${date[@]} | tr ' ' '\n'  > $done_txt
  date=( $(echo ${date[@]} | rev | cut -d ' ' -f1 | rev) )

fi
for i in ${date[@]}
  do if [ ! "$first_run" == '1' ]
    then addition='Changed Since Previous Update/'
    echo $i | tr ' ' '\n' >> $done_txt
  fi
  sdf=( $(curl "$url$i/All Stock Compounds/$addition" | grep '.gz' | rev | cut -d ' ' -f1 | rev) )
  for I in ${sdf[@]}
    do curl -C - --limit-rate 2M "$url$i/All Stock Compounds/$addition/$I" -O
    echo ungziping
    gunzip $I
  done
    [ -e 'lmiis_added.sdf' ] && mv lmiis_added.sdf $i\_added.sdf
    if [ -e 'lmiis_removed.txt' ]
      then for i in sdf-2d sdf-3d pdbqt
        do cat ../lmiis_removed.txt | xargs -I{} rm $db_location/$i/{}
      done
      rm lmiis_removed.txt
    fi
done
}

main() {
if [ -e $done_txt ]
  then already_done=( $(cat $done_txt) )
  else first_run=1
fi
download_sdf
echo Done
}

mkdir molport ; cd molport
main
