#! /usr/bin/env bash

add_to_mysql() {
mysql -u nikosf -pa -e "use BABEL" -e "
      LOAD DATA LOCAL INFILE '$2'
      INTO TABLE $1
      FIELDS TERMINATED BY ','
      OPTIONALLY ENCLOSED BY '\"'
      LINES TERMINATED BY '\n' ;
"
}

cat $* |
cut -d "	" -f -2 |
sed -e "s/^/\"/;s/$/\"/;s/	/\",\"/" > /tmp/zinc.csv

add_to_mysql Zinc_ext /tmp/zinc.csv
rm /tmp/zinc.csv
