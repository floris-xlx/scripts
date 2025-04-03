#!/bin/bash

curl -L https://github.com/PostgREST/postgrest/releases/latest/download/postgrest-v12.2.8-linux-static-x86-64.tar.xz -o postgrest.tar.xz
tar -xvf postgrest.tar.xz
sudo mv postgrest /usr/local/bin/
chmod +x /usr/local/bin/postgrest
postgrest --version