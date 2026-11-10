#!/usr/bin/env bash
set -euo pipefail

mkdir -p exports
printf "account,balance\nA001,100\n" > exports/accounts_2024-10.csv
