# sms_traffic_sdk 0.3.0: REXML instead of Nokogiri, honest dependency bounds

Status: ready for implementation
Delivery target: main, then GitHub Release `v0.3.0` (publishes through CI)
Task branch: release-0.3.0
Review tier: opus
Gate: `bundle exec rake`; `BUNDLE_GEMFILE=gemfiles/minimum.gemfile bundle exec rake spec`; `bundle exec rake build`;
packaged gem installed into an isolated GEM_HOME and required in a plain Ruby process; `actionlint`

## Context

Replies from `multi.php` are small flat XML documents. Nokogiri (native extension) is heavier than needed and its
`~> 1.12` lower bound is untested: CI always resolves the newest version. Nori ships a REXML parser
(`Nori.new(parser: :rexml)`); REXML is pure Ruby and a bundled gem since Ruby 3.0.

## Required behavior

1. Default parser: `Nori.new(advanced_typecasting: false, parser: :rexml)`. Remove the `nokogiri` runtime dependency;
   add `rexml` with a lower bound of `3.3.9` (after the 2024 DoS fixes).
2. Every XML fixture in `spec/fixtures` parses to the same hash with the REXML parser as with Nokogiri. Prove it once
   with a temporary comparison run before removing Nokogiri (record the result in the commit message or report;
   no permanent spec needs Nokogiri). Whitespace-only and empty elements (`<error></error>`, `<status/>`) keep
   their current results.
3. Runtime dependency bounds are honest: each lower bound in the gemspec is a version the suite passes with.
   `gemfiles/minimum.gemfile` pins every runtime dependency to its gemspec lower bound (`nori`, `rexml`,
   `bigdecimal`) and reuses the dev dependencies from the main Gemfile. Raise a bound only when the minimum fails,
   and say why in CHANGELOG.
4. CI: a `test-minimum` job (or matrix entry) runs RSpec with `BUNDLE_GEMFILE: gemfiles/minimum.gemfile` on
   Ruby 3.1 and 3.4. `publish` needs it too. Gemfile.lock files stay untracked.
5. README: no mention of Nokogiri; a custom `xml_parser` remains possible (any object responding to `parse`).
6. CHANGELOG `0.3.0 - <release date>`: Changed (Nokogiri dropped, REXML parser, dependency bounds, minimum-versions
   CI). Breaking note: applications that relied on Nokogiri being installed through this gem must depend on it
   themselves. `VERSION = '0.3.0'`.

## Out of scope
- Dropping Nori, HTTP API v2, API changes.
