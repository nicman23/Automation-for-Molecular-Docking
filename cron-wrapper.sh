cd /home/common/babel
export PATH="/home/common/babel/Automation-for-Molecular-Docking:$PATH"

(
mkdir Downloads-tmp ; cd Downloads-tmp
molport-downloader.sh $(cat ../.molport_downloader_pass)
bash `which zinc15-downloader-dash.sh` download #no dash installed
(
mkdir ambinter ; cd ambinter
for i in {1..6} # add here for new?
  do wget -c --limit-rate=2M -c http://www.ambinter.com/bundles/ambintersearch/download/Ambinter3D-$i.zip
  unzip Ambinter3D-$i.zip
done
)

wget -c --limit-rate=1.5m http://files.docking.org/catalogs/50/molport/molport.info.txt
wget -c --limit-rate=1.5m http://files.docking.org/catalogs/10/ambint/ambint.info.txt.gz
find . -name '*.gz' -type f -exec gunzip {} \;
zinc-to-third.sh molport.info.txt ambint.info.txt
)

find Downloads-tmp/ -name '*.sdf' -type f | digest-babel.sh

# rm -rf Downloads-tmp
