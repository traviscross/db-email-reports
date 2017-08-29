#!/bin/sh
##### -*- mode:shell-script; indent-tabs-mode:nil; sh-basic-offset:2 -*-
export PATH=/usr/bin:/bin

. "$(dirname "$0")"/shlib-mimemail.sh

usage () {
  echo "usage: $0 [-h]">&2
  echo "  -j <msg-subject>">&2
  echo "  -s <sender-email>">&2
  echo "  -t <to-emails>">&2
  echo "  -c <cc-emails>">&2
  echo "  -b <database>">&2
  echo "  [-m]">&2
  echo "  [-p]">&2
}

usage_err () {
  usage; err "$1"
}

sender_email=""
cc_emails=""
to_emails=""
msg_subject=""
compress=false
printonly=false
database=""
file_name_base="report"
while getopts "b:c:hj:mn:ps:t:" o; do
  case "$o" in
    b) database="$OPTARG" ;;
    c) cc_emails="$OPTARG" ;;
    h) usage; exit 0 ;;
    j) msg_subject="$OPTARG" ;;
    m) compress=true ;;
    n) file_name_base="$OPTARG" ;;
    p) printonly=true ;;
    s) sender_email="$OPTARG" ;;
    t) to_emails="$OPTARG" ;;
  esac
done
shift $(($OPTIND-1))

test -n "$to_emails" \
  || usage_err "No destinations specified"

test -n "$sender_email" \
  || usage_err "No sender specified"

test -n "$msg_subject" \
  || usage_err "No subject specified"

test -n "$database" \
  || usage_err "No database specified"

sender_addr="$(email_addr "$sender_email")"
sender_name="$(email_name "$sender_email")"
msg_subject="$msg_subject | $(/bin/date -u +%Y-%m-%d)"

template_body () {
  cat <<EOF
Greetings,

Please find attached the latest periodic report.
EOF
}

run_report () {
  psql -qn "$database" <<EOF
\unset HISTFILE
\set ON_ERROR_STOP on
create or replace function pg_temp.run_report()
    returns table(
      field1 text,
      field2 text,
      field3 text)
    stable strict as \$\$
select
    'one'::text,'two'::text,'three'::text;
\$\$ language sql;
\copy (select * from pg_temp.run_report()) to stdout with csv header delimiter ',';
EOF
}

compose_mail () {
  local boundary="$(mime_boundary)"
  template_header \
    "$sender_name" "$sender_addr" \
    "$to_emails" "$cc_emails" \
    "$msg_subject"
  mime_add_multipart_mixed "$boundary"
  mime_next "$boundary"
  template_body | mime_add_text_plain
  mime_next "$boundary"
  local err_id=$(mktemp /tmp/db-email-reports-ret-id.XXXXXXXX)
  local err_msg=$(mktemp /tmp/db-email-reports-ret-msg.XXXXXXXX)
  if $compress; then
    { run_report 2>$err_msg || echo $? >$err_id; } \
      | mime_add_file_gzip "$boundary" \
      "$(date -u +%Y%m%d)-${file_name_base}.csv.gz"
  else
    { run_report 2>$err_msg || echo $? >$err_id; }\
      | mime_add_file "$boundary" \
      "text/csv" "8bit" "$(date -u +%Y%m%d)-${file_name_base}.csv"
  fi
  if test -s $err_id && test "$(cat $err_id)" -ne 0; then
    echo "Report failed to run: $(cat $err_msg)">&2
    rm -f $err_id $err_msg
    exit 1
  fi
  rm -f $err_id $err_msg
  mime_end "$boundary"
}

if $printonly; then
  compose_mail
else
  compose_mail | send_mail "$sender_addr"
fi
