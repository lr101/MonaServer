#!/usr/bin/env bash

set -euo pipefail

generated_root=${1:?generated output directory is required}
reference_root=${2:-}

while IFS= read -r -d '' generated_file; do
  # Preserve byte-identical files already in the checked-in output. This keeps
  # a generator upgrade or a new schema from rewriting unrelated legacy files.
  relative_file=${generated_file#"$generated_root"/}
  if [ -n "$reference_root" ] &&
    [ -f "$reference_root/$relative_file" ] &&
    cmp -s "$generated_file" "$reference_root/$relative_file"; then
    continue
  fi

  if [[ "$generated_file" == *.dart ]]; then
    dart format "$generated_file" >/dev/null
  fi

  if [ "$relative_file" = "lib/model/email_login_code_exchange_request_dto.dart" ]; then
    # The email sign-in code is a short-lived secret and must not appear in
    # generated model logs.
    sed -i 's/EmailLoginCodeExchangeRequestDto\[code=\$code,/EmailLoginCodeExchangeRequestDto[code=[redacted],/' "$generated_file"
  fi

  # OpenAPI Generator 7.x emits trailing spaces and sometimes multiple blank
  # lines at EOF. Normalize only new or changed generated artifacts so local
  # and CI output use the same bytes without unrelated churn.
  if grep -Iq . "$generated_file"; then
    sed -i 's/[[:blank:]]\+$//' "$generated_file"
    perl -0pi -e 's/\n+\z/\n/' "$generated_file"
  fi
done < <(find "$generated_root" -type f -print0)
