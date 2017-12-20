#! /usr/bin/env dash

# το shebang και όλο το αρχείο μπορεί να τρέξει και σε bash και dash
# η οποία είναι πιο γρήγορη αλλά δεν έχει τα ίδια features

# Κάνει print το 12 `"' το οποίο είναι το όνομα του ενός από τα αρχεία
# που θα κατεβούν
get_names() {
cut -d \" -f 12
}

# Το IFS είναι ουσιαστικά που το for βλέπει για νέο string ie το
# default είναι το whitespace ' ' και για αυτό δουλεύει το for a s d.
# Τώρα λέμε στο shell μας να βλέπει ως νέα γραμή κάθε όπου υπάρχοτν τα
# σύμβολά σε οποιαδήποτε σειρά. Το `cat -` εισάγει στο stdout το stdin
# που είσαγεται στο function. Τα 2 grep διαχωρίζουν τα αρχεία που θέλουμε
# με τα παραπάνω κριτήρια.
json_parser() {
local IFS='{}'
for i in $(cat -)
  do echo $i | grep \"R\"\:\""$reg_reactive"\" |
  grep \"P\":\""$reg_purchasable"\" | get_names
done
}

# Το τελικό payload (με curl) που στέλνουμε σε μορφή url στην zinc15 με
# την τελευταία ημ/νια που αποθηκεύεται στο /home/common/babel/.zinc15-dl-ld. To grep
# υπάρχει για να αποφευχθεί η εγγραφή λανθασμένων δεδομένων στο τελίκο αρχείο
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

# Το αρχικό αρχείο το οποίο κατεβάζουμε από zinc15 και περιέχει όλη την
# πληροφορία για τα links που θα μας δώσει τελικά
# (όνομα, αντιδραστικότητα, κλπ).
get_json() {
curl 'http://zinc15.docking.org/tranches/all3D.json' --compressed
}

# [a-z] = regex για όλα τα μικρά γράμματα
# reactive a-c είναι τα Clean και πάνω
reg_reactive='[A-C]'
# ομοίως a-b είναι τα in-stock και πάνω
reg_purchasable='[A-B]'

# Μερικό string manipulation με το ένα function να δίνει pipe στο άλλο
# και τελικά να πάει στο tranches
tranches="$(echo $(get_json | jq -c '.[] | { R: .reactive ,P: .purchasable ,N: .name }' | json_parser) | tr ' ' '+')"

mkdir zinc ; cd zinc
get_links
[ "$@" == 'download' ] 2> /dev/null && bash ./zinc15_$date.sh
