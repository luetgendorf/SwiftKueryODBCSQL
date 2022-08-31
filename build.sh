#!/bin/bash

set -o verbose

swift build -Xcc -I/usr/local/Cellar/unixodbc/2.3.7/include -I/usr/local/Cellar/openssl@1.1/1.1.1k/lib/pkgconfig

swift package generate-xcodeproj --xcconfig-overrides SwiftKueryODBCSQL.xcconfig
