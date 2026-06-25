for pofile in po/*.po; do
  msgmerge --update "$pofile" po/wattage.pot
done
