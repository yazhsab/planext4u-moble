# Location and serviceability shell

Story: `MOB-P2-007`

The shared location controller performs no device access until the current `LOCATION_SERVICEABILITY` consent policy is granted. It models education, GPS disabled, request/deny/deny-forever, settings, locating, manual selection, server checking, unserviceable, offline and retry states explicitly.

`geolocator` 14.0.3 is isolated behind a platform boundary. Android apps declare only coarse/fine foreground permission; Apple apps declare only when-in-use purpose text. There is no background location permission or continuous location stream in this customer serviceability flow.

Both GPS and manually selected coordinates are sent to the backend with accuracy, capture time and fixed purpose. A location cannot unlock customer content until the server returns a serviceable zone. Offline checks remain blocked rather than assuming availability.

Tests cover consent-first ordering, deny/retry/permanent-denial settings, disabled GPS, GPS/manual success, out-of-area, offline and accessible denial rendering.
