#! /usr/bin/env bash

get_links() {
  ld_date=$(cat /home/common/babel/.zinc15-dl-ld)
  date="$(date +%Y-%m-%d | tee /home/common/babel/.zinc15-dl-ld)"
  curl 'http://zinc15.docking.org/tranches/download'\
    --data "representation=3D&tranches=$tranches
  &since=$ld_date&database_root=&format=sdf.gz&using=wget"\
    --compressed | grep '^mkdir' | sed 's/wget/wget -c --limit-rate=2M/g' \
    > zinc15_$date.sh
  echo The links are in zinc15_$date.sh
}

filter_json() {
curl 'http://zinc15.docking.org/tranches/all3D.json' --compressed |
jq -rc '.[] | select(.ph_mod_fk | match("[R]")) |
select(.purchasable | match("[A-B]")) | select(.reactive | match("[A-C]")) |
select(.size != 0) | .name' | paste -s -d '+'
}

tranches=$(filter_json)

mkdir zinc ; cd zinc || exit 5
get_links
[ "$1" = 'download' ] 2> /dev/null && bash ./zinc15_$date.sh
