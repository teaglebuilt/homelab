#!/bin/bash

get_version() {
  dpkg -s unifi | grep Version
}

flush_dns_cache() {
  sudo systemd-resolve --flush-caches
}
