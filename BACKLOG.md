# Backlog

- Debug request log line still prints `phones` and extra `**options` values unfiltered (`lib/sms_traffic/client.rb`); decide whether phone numbers count as sensitive and mask them.
- A 200 response with a non-XML body (e.g. an HTML error page) yields `"Sms has not been enqueued: "` with an empty description; raise `SmsTraffic::ApiError` or include the body size instead.
- Release workflow: configure a RubyGems trusted publisher for `golifox/sms_traffic_sdk`, workflow `ci.yml`, before the first CI publish; until then the publish job fails at the OIDC exchange.
