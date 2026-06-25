for f in po/*.po; do
  msgattrib --no-obsolete -o "$f" "$f"
done
