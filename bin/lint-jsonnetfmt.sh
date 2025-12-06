#!/bin/sh

err=0
find . -not -path ./build/kube-prometheus/libraries/\* -name \*.jsonnet |
  while read -r f; do
    if ! jsonnetfmt --test "${f}"; then
      err=1
      echo "'${f}' not correctly formatted"
    fi

    if [ $err -gt 0 ]; then
      exit 1
    fi

  done

jsonnetfmt --test ./build/kube-prometheus/common-template.jsonnet