# Changelog

## 1.6.1

- Apply the minimum threshold to Shadow Word: Death nameplates even when maximum health is secret. Hide the threshold marker and fill if the client rejects clipping.

## 1.6.0

- Group threshold, fill, marker, and icon settings in one Nameplates tab with a fixed live preview. Align the shared window settings and remove the theme color reset rows.
- Add optional Sintezza Perf developer measurements for execute indicators.
- Avoid repeated marker-range updates when public health limits and thresholds are unchanged. Secret-health updates keep their regular refresh path.

## 1.5.0

- The settings window displays the version, and its WoW AddOns page uses the shared launcher.
- Settings use the standard compact header.
- The preview controls use a shared section heading on the window background.
- Left-clicking the minimap icon opens or closes the window.
- Connected window scale, opacity, and layer to the shared Theme settings.
- Updated the project logo and in-game addon icon.

## 1.4.5

- Recognizes additional client formats for the Shadow Word: Death damage range and reports when the range cannot be read.

## 1.4.4

- Keeps the last confirmed cooldown state when data is temporarily unavailable. Reads the global cooldown flag during the cooldown event to prevent nameplate icons from flashing between updates.

## 1.4.3

- Clarified the wording for the threshold marker and minimum threshold filter. Added a tooltip beside each setting.

## 1.4.2

- Shows a cooldown bar, remaining seconds, and a completion message below the preview nameplate. The result describes how the selected cooldown mode affects the icon.

## 1.4.1

- The cooldown preview moves the dummy into execute range when needed and counts down on the test button. The test is available for each supported ability.

## 1.4.0

- Automatically detects the highest learned rank of Shadow Word: Death, Execute, Hammer of Wrath, or Soul Fire with Decimation.
- Shows the ability's HP estimate or health percentage and uses its game icon by default. The icon dropdown includes six transparent alternatives.

## 1.3.13

- Added a themed hint that explains the damage reduction buffer.

## 1.3.12

First public release baseline for WoW Forever 1.60.1.

- Shadow Word: Death threshold from the highest learned rank, with a configurable damage buffer and display filters.
- Independent fill, threshold marker, and spell icon for Blizzard and EllesmereUI enemy nameplates.
- Settings preview with target health, combat scenarios, and cooldown. Controls for color, size, pulse, and cooldown behavior.
- Shared Sintezza Theme and support for English and Russian spell tooltips.
