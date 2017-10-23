write_csv() {
echo \"$1\",\"$2\" >> /tmp/zinc.csv
}

reader() {
while read line
  do write_csv $line
done
}

add_to_mysql() {
mysql -u nikosf -pa -e "use BABEL" -e "
      LOAD DATA LOCAL INFILE '$2'
      INTO TABLE $1
      FIELDS TERMINATED BY ','
      OPTIONALLY ENCLOSED BY '\"'
      LINES TERMINATED BY '\n' ;
"
}

info_file="$@"
cat $@ |
reader

add_to_mysql Zinc /tmp/zinc.csv
rm /tmp/zinc.csv
