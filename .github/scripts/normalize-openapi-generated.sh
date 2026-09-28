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

  if [ "$relative_file" = "lib/model/profile_progression_dto.dart" ]; then
    # Go's JSON encoder can serialize an integral float64 as an integer token
    # (for example, 0). OpenAPI Generator's Dart decoder expects a double token
    # for a `number` field, so accept either JSON number type.
    python3 - "$generated_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
contents = path.read_text()
generated = "        fraction: mapValueOfType<double>(json, r'fraction')!,"
compatible = (
    "        // Go's JSON encoder emits integral float64 values (0 and 1) without a\n"
    "        // decimal point, so accept both integer and double JSON numbers.\n"
    "        fraction: mapValueOfType<num>(json, r'fraction')!.toDouble(),"
)
if generated in contents:
    contents = contents.replace(generated, compatible, 1)
elif compatible not in contents:
    raise SystemExit(f"cannot normalize generated progression decoder in {path}")
path.write_text(contents)
PY
  fi

  if [ -n "$reference_root" ] &&
    [ -f "$reference_root/$relative_file" ] &&
    cmp -s "$generated_file" "$reference_root/$relative_file"; then
    continue
  fi

  if [[ "$generated_file" == *.dart ]] &&
    { [ -z "$reference_root" ] ||
      [ ! -f "$reference_root/$relative_file" ] ||
      ! cmp -s "$generated_file" "$reference_root/$relative_file"; }; then
    dart format "$generated_file" >/dev/null
  fi
done < <(find "$generated_root" -type f -print0)
