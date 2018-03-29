#! /usr/bin/env bash
url="ftp://$*@www.molport.com/molport_database/"
db_location='/home/common/babel'
done_txt="$db_location/.molport_downloader"

remove_done() {
  for i in ${already_done[*]}
  do date=( ${date[*]/$i} )
  done
}

download_sdf() {
  date=( $(curl $url | grep '^d' | rev | cut -d ' ' -f1 | rev | grep -P '(?<!\d)\d{4}(?!\d)-(?<!\d)\d{2}(?!\d)') )
  echo ${date[*]} | tr ' ' '\n'  > $done_txt
  remove_done
  last_date="$(echo ${date[*]} | rev | cut -d ' ' -f1 | rev)"
  array=( $(curl "$url${last_date}/All Stock Compounds/SMILES/" | grep '.gz' | rev | cut -d ' ' -f1 | rev) )
  for I in ${array[*]}
  do echo curl -C - --limit-rate 2M "$url$i/All Stock Compounds/SMILES/$I" |
    gunzip | tail -n+2 >> molport.smi
  done
  for i in ${date[*]}
  do curl "$url$i/All Stock Compounds/Changed Since Previous Update/lmiis_removed.txt.gz" |
    gunzip | xargs -I{} rm $db_location/pdbqt/{}*
  done
}

main() {
  if [ -e $done_txt ]
  then already_done=( $(cat $done_txt) )
  fi
  download_sdf
  echo Done
}

mkdir molport ; cd molport || exit 5
main
