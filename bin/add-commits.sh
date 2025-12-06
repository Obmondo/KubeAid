#!/bin/bash

changelog_file="CHANGELOG.md"
latest_tag=$(grep -oP '^## \K[0-9]+\.[0-9]+\.[0-9]+' "$changelog_file" | head -n1)

echo "$latest_tag"

commit_log=$(git log "$latest_tag"..origin/master --oneline --no-merges)

formatted_commit_log=$(echo "$commit_log" | awk '{
    sha=$1;
    $1="";
    sub(/^ /, "", $0);
    print "- [`" sha "`](../../commit/" sha ") " $0
}')

temp_file="temp.md"
{
  echo "### Improvements"
  echo "$formatted_commit_log"
  echo ""
} > "$temp_file"

# Update the changelog file
awk -v tag="## ${latest_tag}" -v file="$temp_file" '
  $0 == tag { 
    while ((getline line < file) > 0) {
      print line
    }
  }
  { print }
' "$changelog_file" > "${changelog_file}.tmp" && mv "${changelog_file}.tmp" "$changelog_file"

rm "$temp_file"

commit_msg="Add commit since ${latest_tag} tag to CHANGELOG.md"

git add CHANGELOG.md
git commit -S -m "$commit_msg"
