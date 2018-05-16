#! /usr/bin/env bash
cd /home/common/babel || exit 5
export PATH="/home/common/babel/Automation-for-Molecular-Docking:$PATH"
threads=20

(
  mkdir Downloads-tmp ; cd Downloads-tmp || exit 5
  molport-downloader.sh $(cat ../.molport_downloader_pass)
  zinc-downloader.sh download
  (
    mkdir ambinter ; cd ambinter || exit 5
    curl 'http://www.ambinter.com/bundles/ambintersearch/download/ambinter_catalogue_3D_2018v1.mdl.tar.bz2' |
    tar -jxf -
  )

  wget -c --limit-rate=3m http://files.docking.org/catalogs/50/molportbbe/molportbbe.info.txt.gz
  wget -c --limit-rate=3m http://files.docking.org/catalogs/50/molporte/molporte.info.txt.gz
#  wget -c --limit-rate=3m http://files.docking.org/catalogs/10/ambint/ambint.info.txt.gz
  find . -name '*.gz' -type f -exec gunzip {} \;
  zinc-to-third.sh molportbbe.info.txt molporte.info.txt # ambint.info.txt
)

find Downloads-tmp -type f | grep 'smi\|sdf\|mdl'|
digest-babel.sh -T $threads
gen3d.sh $threads

#rm -rf Downloads-tmp
