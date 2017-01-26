##### -*- mode:shell-script; indent-tabs-mode:nil; sh-basic-offset:2 -*-
# Copyright (c) 2017 Travis Cross <tc@traviscross.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

sender_addr=""
sender_name=""
cc_emails=""
to_emails=""
msg_subject=""

err () {
  printf "Error: %s\n" "$1">&2
  exit 1
}

trim_leading_spaces () {
  #printf "%s" "${1#""${1%%[![:s]*}""}" # broken in dash v0.5.{6,7}
  printf "%s" "$1" | sed "s/^[[:space:]]*//"
}

trim_trailing_spaces () {
  #printf "%s" "${1%""${1##*[![:space:]]}""}" # broken in dash v0.5.{6,7}
  printf "%s" "$1" | sed "s/[[:space:]]*$//"
}

trim_spaces () {
  trim_leading_spaces "$(trim_trailing_spaces "$1")"
}

email_name () {
  printf "%s" "${1#""${1%%<*}""}"
}

email_name () {
  trim_spaces "${1%%<*}"
}

email_addr () {
  local x="$1"
  x="${x%>}"
  x="${x##*<}"
  printf "%s" "$x"
}

random10 () {
  local c="$1"
  test -n "$c" || err "No count given"
  cat /dev/urandom | tr -dc '0-9' | head -c${c}
}

uuid () {
  cat /proc/sys/kernel/random/uuid
}

mime_boundary () {
  printf "%s" "------------"
  random10 24
}

mime_add_text () {
  local boundary="$1"
  local content_type="$2"
  cat <<EOF
Content-Type: ${content_type}; charset=UTF-8
Content-Transfer-Encoding: 8bit

EOF
  cat
}

mime_add_text_plain () {
  mime_add_text "$1" "text/plain"
}

mime_add_text_html () {
  mime_add_text "$1" "text/html"
}

mime_add_file () {
  local boundary="$1"
  local content_type="$2"
  local encoding="$3"
  local file_name="$4"
  cat <<EOF
Content-Type: ${content_type};
 name="${file_name}"
Content-Transfer-Encoding: ${encoding}
Content-Disposition: attachment;
 filename="${file_name}"

EOF
  cat
}

mime_add_file_binary () {
  base64 -w72 | mime_add_file "$1" "$2" "base64" "$3"
}

mime_add_file_gzip () {
  gzip -9cn | mime_add_file_binary "$1" "application/gzip" "$2"
}

mime_add_multipart_mixed () {
  cat <<EOF
Content-Type: multipart/mixed;
 boundary="$1"

This is a multi-part message in MIME format.
EOF
}

mime_next () {
  printf "\n%s%s\n" "--" "$1"
}

mime_end () {
  printf "\n%s%s%s\n" "--" "$1" "--"
}

template_header () {
  local sender_name="$1"
  local sender_addr="$2"
  local to_emails="$3"
  local cc_emails="$4"
  local msg_subject="$5"
  local msg_id="$(uuid)"
  local msg_date="$(/bin/date -u -R)"
  local sender_email="$sender_addr"
  test -z "$sender_name" \
    || sender_email="\"$sender_name\" <$sender_addr>"
  cat <<EOF
Message-ID: <${msg_id}>
Date: ${msg_date}
From: ${sender_email}
To: ${to_emails}
Cc: ${cc_emails}
Subject: ${msg_subject}
MIME-Version: 1.0
EOF
}

send_mail () {
  local sender_addr="$1"
  /usr/sbin/sendmail \
    -B 8BITMIME \
    -f "${sender_addr}" \
    -i \
    -N never \
    -t
}
