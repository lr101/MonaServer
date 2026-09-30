#!/usr/bin/env bash

set -euo pipefail

generated_root=${1:?generated output directory is required}
reference_root=${2:-}

while IFS= read -r -d '' generated_file; do
  # Preserve byte-identical files already in the checked-in output. This keeps
  # a generator upgrade or a new schema from rewriting unrelated legacy files.
  relative_file=${generated_file#"$generated_root"/}

  if [ "$relative_file" = "lib/model/admin_user_update_dto.dart" ]; then
    # The Dart generator defaults optional arrays to const [], which would
    # serialize an omitted PATCH field as an explicit request to clear it.
    python3 - "$generated_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
contents = path.read_text()
generated = (
    "        adminPermissions: json[r'adminPermissions'] is Iterable\n"
    "            ? (json[r'adminPermissions'] as Iterable)\n"
    "                .cast<String>()\n"
    "                .toList(growable: false)\n"
    "            : const [],"
)
compatible = generated.replace(": const [],", ": null,")
if generated in contents:
    contents = contents.replace(generated, compatible, 1)
elif compatible not in contents:
    raise SystemExit(f"cannot preserve omitted admin permissions in {path}")
path.write_text(contents)
PY
  fi

  if [ "$relative_file" = "doc/AdminUserUpdateDto.md" ]; then
    # adminPermissions is optional; its empty-list behavior is explicit and
    # must not inherit the generator's default-to-empty-array documentation.
    python3 - "$generated_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
contents = path.read_text()
default_note = "**adminPermissions** | **List<String>** | Replacement permission list for an existing active admin membership. Only superadmins may set it. The superadmin entry grants every current and future permission, and an empty list removes all permissions. | [optional] [default to const []]"
without_default = default_note.removesuffix(" [default to const []]")
if default_note in contents:
    contents = contents.replace(default_note, without_default, 1)
elif without_default not in contents:
    raise SystemExit(f"cannot normalize admin permission documentation in {path}")
path.write_text(contents)
PY
  fi

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
