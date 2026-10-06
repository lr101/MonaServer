# Pin photos and updates

Implemented design, 6 October 2026.

## Content model

A pin represents one place with an original photo and later photo updates. Each
photo appears as its own feed/profile entry with its contributor, observation
date, caption, and photo-specific likes. The map continues to show one marker
for the place. Personal sticks count photos; group sticks count distinct
locations.

## User and group image feeds

User Images and Group Images lists show only a thumbnail for each photo entry,
without the author overlay, likes row, title, or description. The thumbnail is
clickable and opens pin details with the tapped photo selected. Selecting a
photo in a Profile Pins or Group Pins grid opens the corresponding image list
at that entry.

## Main-feed image card

The established feed image card keeps its dark translucent attribution overlay
at the top. It shows the photo author, the user's badge, and the place label.
The author and group's profile pictures overlap at the top left, beside the
author name, without borders or the user's level. Resolve the place to city,
state, or country when possible; show coordinates only when no place name
resolves. When there is more than one photo, show a centered dotted progress
indicator at the bottom of the image; swiping changes photos.

The map inset swaps with the main image on tap. While the map fills the card,
the inset shows the photo and is the visible way to switch back. No separate
image button or pin-information control is shown.

Below the image, keep original photos and updates visually consistent; do not
show an update label or icon in the feed. The likes row also shows the group
name and the photo's age. The pin title and selected photo description follow
it. Swiping updates the image, contributor, date, caption, and likes together.
The original is the first photo when opening details from the map. Opening
details from a photo entry keeps that photo selected. Pin details show a full
photo carousel with thumbnail navigation and the selected photo's contributor,
date, caption, and likes. Pin details do not show separate update or mark-gone
buttons; users make photo updates and gone reports through the regular camera
flow.

## Adding photo updates

Photo updates use the regular camera and approval screen. After taking or
choosing a picture, the user can select a synced pin within 50 m in the
currently selected group, or keep `A new pin` selected. The photo note is
optional. Each nearby pin has a thumbnail to the left of its title; tapping it
opens pin details. For a selected pin, an optional control can mark that place
gone after the photo update is saved. It is off by default. If the photo saves
but the status change fails, retrying does not upload the same photo a second
time.

## Styling

Use Material theme surfaces and support light and dark themes. Keep the photo
card's established 10 px corners and overlay spacing. Text over the image uses
a translucent dark surface. Contributor names truncate; place labels, photo
navigation, likes, titles, and descriptions remain readable at narrow widths.
