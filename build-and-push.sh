#!/bin/bash

source vars.sh
set -e

# Build a fresh copy of the site
rm -rf public
hugo -v

# Copy over pages - not static js/img/css/downloads
aws s3 sync --acl "public-read" \
--sse "AES256" \
public/ s3://$bucket_name \
--exclude 'post' \
--exclude '.DS_Store' \
--profile $profile

# Invalidate root page and page listings
aws cloudfront create-invalidation \
--distribution-id $dist_id \
--paths /index.html / /page/* \
--profile $profile
