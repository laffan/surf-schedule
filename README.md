# Surf Schedule

A minimal SwiftUI iPhone + Apple Watch app that uses your current location to
find the best nearby surfing times for the week. The best window to surf is the
**two hours before each daytime high tide**, so the app highlights that stretch
for each day alongside wind and temperature.

You can dial in the spot two ways when GPS lands on the wrong place:

- **ZIP code** — type a ZIP to recenter (geocoded on-device via `CLGeocoder`,
  no API key).
- **Beach picker** — choose among the nearest NOAA tide stations (each shown
  with its distance). The selected beach's coordinates are also used for the
  weather lookup, so wind/temps match the spot. On the watch, tap the beach
  row to pick.

```
Monday
1–3 PM
5 to 10 mph / Sunny
Low 55° / High 75°
```

## Data sources (NOAA, no API key required)

- **Tides** — [NOAA Tides & Currents](https://api.tidesandcurrents.noaa.gov).
  The app finds the nearest tide-prediction station to your location and pulls
  high/low tide predictions for the week (`product=predictions`,
  `interval=hilo`).
- **Wind, conditions & temperature** — [NOAA National Weather Service](https://api.weather.gov).
  The app resolves your point's forecast and distills each day's daytime
  high/wind/conditions and overnight low.

Both APIs are free and keyless. The NWS API requires a descriptive
`User-Agent` header, which the app sets.

## Project layout

```
SurfSchedule/
  Shared/                     # compiled into BOTH the phone and watch apps
    Models.swift              # SurfDay, SurfWindow, TideEvent, TideStation
    LocationManager.swift     # CoreLocation wrapper (one-shot location)
    NOAATideService.swift     # nearest station + hi/lo tide predictions
    WeatherService.swift      # NWS wind / conditions / temps
    SurfScheduleViewModel.swift  # combines location + tides + weather
  iOS/                        # iPhone app target
    SurfScheduleApp.swift
    ContentView.swift         # weekly list
    Assets.xcassets, Info.plist
  Watch/                      # Apple Watch app target
    SurfScheduleWatchApp.swift
    WatchContentView.swift
    Assets.xcassets, Info.plist
  SurfSchedule.xcodeproj      # open this
  project.yml                 # optional XcodeGen spec to regenerate the project
```

## Running it

You need a Mac with **Xcode 15+**.

1. `open SurfSchedule/SurfSchedule.xcodeproj`
2. Select the **SurfSchedule** scheme and an iOS Simulator (or your device).
3. Build & run. Grant location access when prompted.
4. To run on the watch, choose the watch app target / a paired watch simulator.

> In the iOS Simulator you may need to set a location via
> **Features ▸ Location ▸ Custom Location…** (or pick a city) so the app has a
> coordinate to work from. Choose somewhere coastal for real tide data.

### Regenerating the project (optional)

The committed `.xcodeproj` works as-is. If you'd rather generate it from
`project.yml`:

```
brew install xcodegen
cd SurfSchedule
xcodegen generate
```

## Notes & next steps

This is intentionally bare-bones:

- Tide times are parsed in the device's local timezone (NOAA returns
  station-local time). Good enough for nearby stations; revisit if you travel
  across timezones.
- Weather is best-effort — if the NWS request fails, the app still shows the
  tide-based surf windows.
- Obvious follow-ups: a real app icon, surf-quality scoring (swell/period from
  buoy data), per-day detail screens, and a complication / widget.
