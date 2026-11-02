# Privacy Policy

**Last updated: November 2, 2026**

## Summary

BrickSweep has no accounts, analytics, or advertising. Your collection and your progress
stay on your device. To look up a set, the app downloads that set's parts list, which
sends the set number you entered to the service providing it (see below).

## Data stored on your device

BrickSweep stores the following data **locally on your device only**:

- **Rebrickable API key** — saved in your device's Keychain using iOS's secure storage APIs.
  It is only ever sent directly to `rebrickable.com` when fetching set and part data.
- **Set and parts data** — stored in SwiftData on your device. This data is not backed up
  to any external service by BrickSweep (standard iCloud backup rules apply per your iOS settings).

## Where set data comes from

**Without an API key**, BrickSweep downloads set lists from `data.bricksweep.app`. These are
static files the developer publishes daily from Rebrickable's public data, hosted on
[Cloudflare](https://www.cloudflare.com/privacypolicy/). Each request includes the set number,
your IP address, the time, and the app's name and version. BrickSweep stores none of this.
Cloudflare processes it to deliver the files and to block abusive traffic; the developer can
see aggregate traffic statistics, and the details of requests Cloudflare blocks.

**With your own Rebrickable API key**, BrickSweep connects to the
[Rebrickable API](https://rebrickable.com/api/) directly, using the key **you provide**, and
does not contact `data.bricksweep.app`.

Either way, set and part pictures load from Rebrickable's image server. Rebrickable is an
independent service — please review their [privacy policy](https://rebrickable.com/privacy/)
for details on how they handle requests.

BrickSweep is not affiliated with or endorsed by Rebrickable, the LEGO Group, or any of their affiliates.

## Analytics and crash reporting

BrickSweep collects no analytics and has no crash reporting. The developer receives no usage data of any kind.

## Children's privacy

BrickSweep does not knowingly collect any information from anyone, including children under 13.

## Contact

Questions about this policy? Open an issue at
[github.com/iamboliver/brick-sweep](https://github.com/iamboliver/brick-sweep)
or email **brickcheckapp@gmail.com**.

## Changes

If this policy changes materially, the "Last updated" date above will be updated and a note will
be added to the repository's commit history.
