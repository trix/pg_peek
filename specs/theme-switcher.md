# SPEC: Pico CSS Theme Switcher

Stimulus controller for toggling between light and dark themes on all views.

## Behavior

### Initial State
- Theme is read from `localStorage` on page load
- If no preference stored, defaults to `light` theme
- Theme icon reflects current theme (moon for light mode, sun for dark mode)
- `data-theme` attribute set on `<html>` element
- `<meta name="color-scheme">` updated to match theme

### Theme Toggle
- **Trigger:** User clicks the theme toggle icon in the navigation
- **Action:** Toggles between `light` and `dark` themes
- **Persistence:** Theme preference saved to `localStorage`
- **Scope:** Theme applied immediately to entire document
- **No page reload required**

### Visual Feedback
- Icon changes to reflect the **opposite** theme (click to switch to):
  - Light mode active → shows moon icon (click to switch to dark)
  - Dark mode active → shows sun icon (click to switch to light)
- Aria label updates:
  - Light mode: `aria-label="Turn on dark mode"`
  - Dark mode: `aria-label="Turn on light mode"`

## Technical Implementation

### Stimulus Setup
- Load Stimulus via CDN in the view/layout
- Controller code inline in the layout (no separate JS file)
- Controller name: `theme-switcher`

### HTML Structure
```erb
<html lang="en" data-theme="light" data-controller="theme-switcher">
  <head>
    <meta name="color-scheme" content="light" data-theme-switcher-target="colorScheme">
    <!-- ... -->
  </head>
  <body>
    <nav>
      <!-- ... -->
      <ul class="icons">
        <!-- ... -->
        <li>
          <a class="contrast"
             aria-label="Turn on dark mode"
             href="#"
             data-action="click->theme-switcher#toggle"
             data-theme-switcher-target="button">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 32 32" fill="currentColor" class="icon-theme-toggle">
              <!-- theme icon SVG paths -->
            </svg>
          </a>
        </li>
      </ul>
    </nav>
  </body>
</html>
```

### Controller Responsibilities
1. Read theme preference from `localStorage` on connect
2. Apply initial theme to `<html data-theme>` attribute
3. Update `<meta name="color-scheme">` to match theme
4. Toggle theme on button click
5. Save new theme preference to `localStorage`
6. Update aria-label to reflect next action
7. Prevent default link behavior on toggle button

### localStorage Key
- **Key name:** `theme` (e.g., `localStorage.getItem('theme')`)
- **Values:** `"light"` or `"dark"`

### Pico CSS Integration
Pico CSS automatically applies theme styles based on:
- `<html data-theme="light">` or `<html data-theme="dark">`
- `<meta name="color-scheme" content="light">` or `content="dark"`

Both attributes must be updated together for proper rendering.

## Accessibility

- `aria-label` describes the action (what will happen on click)
- Button uses semantic `<a>` element with click handler
- Keyboard accessible (Enter/Space keys work via native link behavior)
- Color scheme meta tag helps browser UI match theme (address bar, scrollbars, etc.)

## Out of Scope

- System preference detection (`prefers-color-scheme` media query)
- Multiple theme options beyond light/dark
- Animated theme transitions
- Per-page theme preferences
- Theme switcher in multiple locations (only in main nav)

## Implementation Notes

- Controller should be attached to `<html>` element for full document control
- The existing theme toggle icon SVG can be reused (already in layout)
- Click handler should call `event.preventDefault()` to prevent navigation
- Theme change is instant (no loading state needed)
