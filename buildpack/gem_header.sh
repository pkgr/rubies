#!/bin/sh
# -*- ruby -*-
bindir=`cd -P "${0%/*}" 2>/dev/null; pwd`
exec "$bindir/ruby" -x "$0" "$@"
