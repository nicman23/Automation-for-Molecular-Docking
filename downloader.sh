#! /usr/bin/env bash
url="ftp://$@@www.molport.com/molport_database/"
done_txt="$HOME/.cache/molport_downloader"

remove_done() {
for i in ${already_done[@]}
  do date=( ${date[@]/$i} )
done
}

download_sdf() {
date=( $(curl $url | grep '^d' | rev | cut -d ' ' -f1 | rev | grep -P '(?<!\d)\d{4}(?!\d)-(?<!\d)\d{2}(?!\d)' | tail -n1 ) )
remove_done
for i in ${date[@]}
  do if [ "$first_run" == '1' ]
    then sdf=( $(curl $url$i/All\ Stock\ Compounds/ | grep '.sdf.gz'  | rev | cut -d ' ' -f1 | rev) )
    else sdf=( $(curl $url$i/All\ Stock\ Compounds/Changed\ Since\ Previous\ Update/ | grep '.sdf.gz'  | rev | cut -d ' ' -f1 | rev) )
    addition='Changed Since Previous Update/'
  fi
  for I in ${sdf[@]}
    do curl -O "$url$i/All Stock Compounds/$addition$I"
  done
  echo $i >> $done_txt
done
}

if [ -e $done_txt ]
  then already_done=( $(cat $done_txt) )
  else first_run=1
fi

download_sdf
