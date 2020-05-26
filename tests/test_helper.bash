assert_test_success() {
  if ! test "$status" -eq 0; then
    batslib_print_kv_single_or_multi 6 \
      output "$output" |
      batslib_decorate "non-zero exit $status" |
      fail
    return $?
  fi

  if ! test "$output" == ""; then
    echo "$output" |
      batslib_decorate "unexpected output" |
      fail
    return $?
  fi
}

assert_test_failure() {
  local -r header="$1"
  local -r message="$2"

  local -r expected="-- $header --"

  if ! test "$status" -eq 1; then
    batslib_print_kv_single 8 \
      expected 1 \
      actual "$status" |
      batslib_decorate "exit code differs" |
      fail
    return $?
  fi

  if ! test "${#lines[@]}" -eq 3; then
    batslib_print_kv_single_or_multi 8 \
      expected "(3 lines of output)" \
      actual "$output" |
      batslib_decorate "output differs" |
      fail
    return $?
  fi

  if ! test "$expected" == "${lines[0]}"; then
    batslib_print_kv_single 8 \
      expected "$expected" \
      actual "${lines[0]}" |
      batslib_decorate "failure header differs" |
      fail
    return $?
  fi

  if ! test "$message" == "${lines[1]}"; then
    batslib_print_kv_single 8 \
      expected "$message" \
      actual "${lines[1]}" |
      batslib_decorate "failure message differs" |
      fail
    return $?
  fi

  if ! test "${lines[2]}" == "--"; then
    batslib_print_kv_single 8 \
      expected "--" \
      actual "${lines[2]}" |
      batslib_decorate "failure trailer differs" \
        fail
    return $?
  fi
}

assert_contents_of_file() {
  local -r file="$1"
  local -r expected="$2"

  local actual
  if ! actual="$(cat "$file" 2>&1)"; then
    batslib_print_kv_single_or_multi 5 \
      file "$file" \
      error "$actual" |
      batslib_decorate "failed to read file" |
      fail
    return $?
  fi

  if ! test "$expected" == "$actual"; then
    batslib_print_kv_single_or_multi 8 \
      file "$file" \
      expected "$expected" \
      actual "$actual" |
      batslib_decorate "file contents differ" |
      fail
    return $?
  fi
}

refute_contents_of_file() {
  local -r file="$1"
  local -r expected="$2"

  local actual
  if ! actual="$(cat "$file" 2>&1)"; then
    batslib_print_kv_single_or_multi 5 \
      file "$file" \
      error "$actual" \
      batslib_decorate "failed to read file" |
      fail
    return $?
  fi

  if test "$expected" == "$actual"; then
    batslib_print_kv_single_or_multi 7 \
      file "$file" \
      contents "$actual" |
      batslib_decorate "file contents do not differ" |
      fail
    return $?
  fi
}
