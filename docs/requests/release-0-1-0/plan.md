# Plan

Workspace: main checkout `/Users/david/dev/konsierge/gems/sms-traffic`, branch `KON-0000`, base `c2fc17b`.
Checks: `bundle exec rake` (RSpec + RuboCop). Ruby 3.3.3 via mise.

## Slice 1: library, tests, docs (spec items 1-27)
One slice because items share `client.rb`, replies, `sms.rb`, and their specs. Tests first for every defect.
Commit in logical steps (packaging, client/errors, replies, sms, docs/version).

## Slice 2: GitHub CI (spec items 28-32)
Files: `.github/workflows/ci.yml`, `Gemfile` (coverage formatter), `spec/spec_helper.rb` (formatter).
Validate workflow syntax with `actionlint` if available through mise, else YAML parse.
Runs after slice 1 (shares `Gemfile`/`spec_helper.rb`).
