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
echo $date > temp
exit
if [ "$first_run" == '1' ]
    then sdf=( $(curl $url$date/All\ Stock\ Compounds/ | grep '.sdf.gz'  | rev | cut -d ' ' -f1 | rev) )
    else sdf=( $(curl $url$date/All\ Stock\ Compounds/Changed\ Since\ Previous\ Update/ | rev | cut -d ' ' -f1 | rev) )
    addition='Changed Since Previous Update/'
fi
for I in ${sdf[@]}
  do curl -O "$url$date/All Stock Compounds/$addition$date"
  echo ungziping
  gunzip $I
done
echo $date >> $done_txt
}

main() {
if [ -e $done_txt ]
  then already_done=( $(cat $done_txt) )
  else first_run=1
fi
download_sdf
echo Removing no longer available
[ -e 'lmiis_removed.txt' ] && rm -rf $(echo ./sdf-2d/$(cat lmiis_removed.txt))
}

main
