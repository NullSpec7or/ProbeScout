 #!/usr/bin/env bash
set -euo pipefail

cat <<'BANNER'

 _______  _______  _______  ______   _______    _______  _______  _______          _________
(  ____ )(  ____ )(  ___  )(  ___ \ (  ____ \  (  ____ \(  ____ \(  ___  )|\     /|\__   __/
| (    )|| (    )|| (   ) || (   ) )| (    \/  | (    \/| (    \/| (   ) || )   ( |   ) (   
| (____)|| (____)|| |   | || (__/ / | (__      | (_____ | |      | |   | || |   | |   | |   
|  _____)|     __)| |   | ||  __ (  |  __)     (_____  )| |      | |   | || |   | |   | |   
| (      | (\ (   | |   | || (  \ \ | (              ) || |      | |   | || |   | |   | |   
| )      | ) \ \__| (___) || )___) )| (____/\  /\____) || (____/\| (___) || (___) |   | |   
|/       |/   \__/(_______)|/ \___/ (_______/  \_______)(_______/(_______)(_______)   )_(   
                                                                                            

Tool author: Rupesh Kumar aka NullSpec7or

BANNER

base="${1:?usage: $0 BASE_URL}"
act_base="$base/actuator"
api_act_base="$base/api/actuator"
endpoints=(health info metrics env beans mappings configprops loggers caches threaddump heapdump gateway/routes refresh shutdown httptrace auditevents)

# temp file to record successful URLs
result_file=$(mktemp)
trap 'rm -f "$result_file"' EXIT

# helper: safe dir name from base URL
base_dir_from_url() {
  u="$1"
  no_scheme="${u#http://}"
  no_scheme="${no_scheme#https://}"
  no_scheme="${no_scheme%/}"
  echo "${no_scheme//[^A-Za-z0-9._-]/_}"
}

BASE_DIR="$(base_dir_from_url "$base")"

# determine save path for a given path (path starts with /)
save_path_for() {
  path="$1"
  rel="${path#/}"
  if echo "$rel" | grep -q '^api/actuator'; then
    remainder="${rel#api/actuator/}"
    prefix="api_actuator"
  else
    remainder="${rel#actuator/}"
    prefix="actuator"
  fi

  if [ -z "$remainder" ]; then
    echo "$BASE_DIR/$prefix/index"
    return
  fi

  top_segment="${remainder%%/*}"
  final_segment="${rel##*/}"
  if [ "$final_segment" = "heapdump" ]; then
    dirpath="$BASE_DIR/$(dirname "$rel")"
    echo "$dirpath/$final_segment"
    return
  fi

  echo "$BASE_DIR/$prefix/$top_segment/index"
}

# perform a check; if successful (not 4xx) record URL to result_file.
# Do NOT save body here; saving happens later only for URLs that are in result_file.
check_url_record_only() {
  url="$1"
  http_code=$(curl -sk --max-time 10 --write-out "%{http_code}" --silent --output /dev/null "$url" || echo "000")
  case "$http_code" in
    4??) return 1 ;;
    000) return 1 ;;
    *) echo "$url" >> "$result_file" ; return 0 ;;
  esac
}

# initial checks for endpoints (record-only)
for ep in "${endpoints[@]}"; do
  check_url_record_only "$act_base/$ep" || true
  check_url_record_only "$api_act_base/$ep" || true
done

# probe mappings to discover additional endpoints
map_json=$(curl -sk --max-time 10 --silent "$act_base/mappings" || true)
map_json_api=$(curl -sk --max-time 10 --silent "$api_act_base/mappings" || true)
combined_maps="$map_json
$map_json_api"

# extract candidate paths like /actuator/... or /api/actuator/...
paths=$(echo "$combined_maps" | grep -oE '/(api/)?actuator/[A-Za-z0-9_./-]+' | sort -u || true)
while IFS= read -r p; do
  [ -z "$p" ] && continue
  check_url_record_only "$base$p" || true
done <<< "$paths"

# At this point result_file contains all successful URLs (may contain duplicates)
# make unique and save to a temp file for iteration
uniq_results=$(mktemp)
sort -u "$result_file" > "$uniq_results"

# Now fetch and save bodies only for the URLs that are in uniq_results
while IFS= read -r url; do
  [ -z "$url" ] && continue

  # derive path part relative to base
  # If url starts with base, take the remainder; otherwise, use the full path from the URL
  rel_path="${url#"$base"}"
  if [ "$rel_path" = "$url" ]; then
    # url did not start with base; extract path only
    rel_path="/$(echo "$url" | sed -E 's#^[a-zA-Z]+://[^/]+##')"
  fi

  out="$(save_path_for "$rel_path")"
  mkdir -p "$(dirname "$out")"

  tmpf=$(mktemp)
  hdrs=$(mktemp)
  http_code=$(curl -skL --max-time 120 -D "$hdrs" -o "$tmpf" --write-out "%{http_code}" "$url" 2>/dev/null || echo "000")

  # read content-type (preserve original, also lowercase for checks)
  content_type=$(grep -i '^Content-Type:' "$hdrs" | sed 's/^[Cc]ontent-[Tt]ype:[[:space:]]*//;s/[[:space:]]*$//' || true)
  lc_ct=$(echo "$content_type" | tr '[:upper:]' '[:lower:]')

  # determine if this is heapdump (always save) by checking final path segment
  final_segment="${rel_path##*/}"

  if printf '%s\n' "$http_code" | grep -qE '^(2..|3..)$'; then
    if [ "$final_segment" = "heapdump" ]; then
      mv "$tmpf" "$out"
      [ -n "$content_type" ] && echo "$content_type" > "$out.content-type"
    else
      # Save only if content-type is JSON (application/json or any +json)
      if printf '%s\n' "$lc_ct" | grep -qE '(^application/json\b|[+/]json\b)'; then
        mv "$tmpf" "$out"
        echo "$content_type" > "$out.content-type"
      else
        rm -f "$tmpf"
      fi
    fi
  else
    rm -f "$tmpf"
  fi
  rm -f "$hdrs"
done < "$uniq_results"

# Print the unique sorted results to stdout and save to Exposed-Actuators.txt under BASE_DIR
mkdir -p "$BASE_DIR"
sort -u "$uniq_results" | tee "$BASE_DIR/Exposed-Actuators.txt"
rm -f "$uniq_results"
