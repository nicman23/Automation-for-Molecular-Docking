#! /usr/bin/env dash
reg_reactive='[A-C]'
reg_purchasable='[A-B]'

get_names() {
cut -d \" -f 28
}

json_parser() {
local IFS='}]['
for i in $(cat -)
  do echo $i |grep "\"reactive\": \"$reg_reactive\""|
  grep "\"purchasable\": \"$reg_purchasable\"" | get_names
done
}

get_links() {
ld_date=$(cat ~/.zinc15-dl-ld)
date="$(date +%Y-%m-%d | tee ~/.zinc15-dl-ld)"
curl 'http://zinc15.docking.org/tranches/download'\
 --data "representation=3D&tranches=$tranches
 &since=$ld_date&database_root=&format=db2.gz&using=wget"\
 --compressed | grep '^mkdir' > zinc15_$date.sh
echo The links are in zinc15_$date.sh
}

get_json() {
curl 'http://zinc15.docking.org/tranches/all3D.json' --compressed
}

tranches="$(echo $(get_json | json_parser) | tr ' ' '+')"
get_links
