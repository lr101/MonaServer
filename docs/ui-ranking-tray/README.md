# Rankings tray aligned with floating navigation

On compact layouts the rankings sheet shares the navigation capsule's width,
rounded outline and bottom edge. The collapsed header grows upward from the
same base; expanding and dragging preserve this attachment. The rankings list
reserves navigation clearance, keeping content above the icons. Tap and drag
snapping use the navigation motion duration and respect reduced motion.

Location and OpenStreetMap attribution follow the top of the tray, including
while it moves. A local ValueNotifier updates only these controls, avoiding a
map/provider rebuild on each drag frame. Wide layouts retain an edge-anchored
sheet alongside the navigation rail.

- [Recorded tray motion](tray-motion.gif)
- [Collapsed, light](collapsed-light.png)
- [Expanded, light](expanded-light.png)
- [Collapsed at 320 px, dark](collapsed-dark.png)
- [Expanded at 320 px, dark](expanded-dark.png)

Verification: 29 focused Flutter widget checks passed across rankings,
navigation, and map/camera lifecycle. These include shared bounds, dragging,
keyboard activation, large text in short windows, reduced motion, and content
clearance. Focused analysis reported no issues. A mobile Playwright journey
signed in through the real form and checked dock alignment, expansion,
collapse, and the location control above the expanded tray. It passed against
a connected hot-reload Flutter Chrome session with local PostGIS, RustFS and
the Go API. Browser evidence does not establish native Android behavior.
