cd /home/common/babel
export PATH="/home/common/babel/Automation-for-Molecular-Docking:$PATH"
threads=20

(
mkdir Downloads-tmp ; cd Downloads-tmp
molport-downloader.sh $(cat ../.molport_downloader_pass)
bash `which zinc15-downloader-dash.sh` download #no dash installed
(
mkdir ambinter ; cd ambinter
for i in {1..6} # add here for new?
  do wget -c --limit-rate=3M -c http://www.ambinter.com/bundles/ambintersearch/download/Ambinter3D-$i.zip
  unzip Ambinter3D-$i.zip
done
)

wget -c --limit-rate=3m http://files.docking.org/catalogs/50/molportbbe/molportbbe.info.txt.gz
wget -c --limit-rate=3m http://files.docking.org/catalogs/50/molporte/molporte.info.txt.gz
wget -c --limit-rate=3m http://files.docking.org/catalogs/10/ambint/ambint.info.txt.gz
find . -name '*.gz' -type f -exec gunzip {} \;
zinc-to-third.sh molportbbe.info.txt molporte.info.txt ambint.info.txt
)

find Downloads-tmp/ -name '*.sdf' -type f | digest-babel.sh -T $threads
gen3d.sh $threads

#rm -rf Downloads-tmp
