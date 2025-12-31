# SPEC: Table Search Filter

Stimulus controller for filtering database tables on the `#tables` view (`app/views/pg_peek/databases/tables.html.erb`).

## Behavior

### Initial State
- No tables are displayed on page load (unless URL contains search query)
- Search input is auto-focused
- Result count shows "0 tables" or similar

### Filtering
- **Trigger:** User types 2+ characters in the search input
- **Matching:** Case-insensitive substring match (e.g., "user" matches "users", "user_sessions", "active_users")
- **Debounce:** 250-300ms delay before filtering executes
- **No special character handling** - underscores and other characters matched literally

### Results Display
- Matching `<details>` elements are shown, non-matching are hidden
- Tables remain collapsed (do not auto-expand on match)
- Result count displayed (e.g., "12 tables found")
- Matching text highlighted with `<mark>` tag within table names

### Empty States
- **No matches:** Display "No tables found" simple text message
- **Search cleared:** Hide all tables, return to initial empty state

## Keyboard Interaction

| Key | Action |
|-----|--------|
| `/` | Focus search input from anywhere on page |
| `Escape` | Clear search input and hide all tables |

## URL State

- **Parameter name:** `q` (e.g., `?q=users`)
- **History mode:** `replaceState` (no browser history pollution)
- **Initialization:** If URL contains `?q=`, populate input and show filtered results on page load

## Technical Implementation

### Stimulus Setup
- Load Stimulus via CDN in the view/layout
- Controller code inline in the view (no separate JS file)
- Controller name: `search-filter`

### HTML Structure
```erb
<div data-controller="search-filter">
  <input type="search"
         placeholder="Search tables..."
         data-search-filter-target="input"
         data-action="input->search-filter#filter"
         autofocus>
  <p data-search-filter-target="count"></p>

  <% @database.tables.each do |table_name| %>
    <details data-search-filter-target="item"
             data-table-name="<%= table_name.downcase %>"
             hidden>
      <summary data-search-filter-target="summary"><%= table_name %></summary>
      <p>...</p>
    </details>
  <% end %>

  <p data-search-filter-target="empty" hidden>No tables found</p>
</div>
```

### Controller Responsibilities
1. Read URL param `q` on connect, initialize filter if present
2. Debounce input events (250-300ms)
3. Filter items when input length >= 2 characters
4. Update visibility of `<details>` elements
5. Highlight matching substring with `<mark>` in summary text
6. Update result count
7. Sync search value to URL via `replaceState`
8. Handle `/` key to focus input
9. Handle `Escape` key to clear and reset

## Accessibility

Minimal approach - rely on semantic HTML:
- `<input type="search">` provides native search semantics
- `placeholder` attribute for input hint
- Native browser clear button (type="search" provides this)

## Out of Scope

- Table details content (what shows when expanded) - placeholder `...` remains
- Schema-qualified table names - only public schema tables shown
- Pagination or virtual scrolling for large table counts
- Fuzzy matching or advanced search operators
