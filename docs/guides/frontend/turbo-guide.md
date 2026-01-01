# Turbo Guide

**Last Updated**: December 30, 2025
**Document Type**: Guide
**Audience**: Frontend developers

---

## Overview

This project uses Hotwire (Turbo + Stimulus) for frontend interactivity with minimal JavaScript.

### Core Concepts

- **Turbo Drive**: SPA-like navigation without page reloads
- **Turbo Frames**: Partial page updates
- **Turbo Streams**: Real-time DOM updates
- **Stimulus**: Lightweight JavaScript controllers

---

## Turbo Drive

Automatically intercepts link clicks and form submissions for faster navigation.

### Disable for Specific Links

```erb
<%= link_to "External", url, data: { turbo: false } %>
```

### Progress Bar

Turbo shows a progress bar during navigation. Customize in CSS:

```css
.turbo-progress-bar {
  background-color: theme('colors.primary');
}
```

---

## Turbo Frames

### Basic Frame

```erb
<%= turbo_frame_tag "user_profile" do %>
  <h2><%= @user.name %></h2>
  <%= link_to "Edit", edit_user_path(@user) %>
<% end %>
```

### Lazy Loading

```erb
<%= turbo_frame_tag "comments", src: comments_path, loading: :lazy do %>
  <p>Loading comments...</p>
<% end %>
```

### Target Parent Frame

```erb
<%= link_to "View All", users_path, data: { turbo_frame: "_top" } %>
```

---

## Turbo Streams

### Controller Response

```ruby
respond_to do |format|
  format.turbo_stream do
    render turbo_stream: turbo_stream.append("messages", @message)
  end
  format.html { redirect_to messages_path }
end
```

### Stream Actions

| Action | Description |
|--------|-------------|
| `append` | Add to end of container |
| `prepend` | Add to start of container |
| `replace` | Replace entire element |
| `update` | Replace inner HTML |
| `remove` | Remove element |
| `before` | Insert before element |
| `after` | Insert after element |

### Example Stream Template

```erb
<%# app/views/messages/create.turbo_stream.erb %>
<%= turbo_stream.append "messages" do %>
  <%= render @message %>
<% end %>

<%= turbo_stream.update "message_count", Message.count %>
```

---

## Stimulus Controllers

### Basic Controller

```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = { open: Boolean }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.contentTarget.classList.toggle("hidden", !this.openValue)
  }
}
```

### Usage in Views

```erb
<div data-controller="toggle" data-toggle-open-value="false">
  <button data-action="toggle#toggle">Toggle</button>
  <div data-toggle-target="content" class="hidden">
    Content here
  </div>
</div>
```

---

## Form Patterns

### Form Submission with Stream

```erb
<%= form_with model: @message, data: { turbo_stream: true } do |f| %>
  <%= f.text_field :content %>
  <%= f.submit %>
<% end %>
```

### Disable Button During Submit

```erb
<%= f.submit "Save", data: { turbo_submits_with: "Saving..." } %>
```

---

## Form View Toggle (Wizard/Traditional)

The form filling experience supports two modes: **Wizard** (one field at a time) and **Traditional** (all fields visible). These modes are managed by coordinated Stimulus controllers.

### Controller Architecture

```
view-toggle controller (parent)
├── Manages mode state (wizard/traditional)
├── Persists preference to localStorage
├── Syncs data between views on toggle
└── Dispatches modeChanged event

wizard controller (child)
├── Handles card navigation with flip animations
├── Listens for modeChanged events
├── Navigates to first empty field on mode switch
└── Updates navigation dots to show filled/empty state
```

### Data Synchronization

Both views render the same form fields with identical input names. When switching modes:

1. `view-toggle` syncs values from source to target container
2. `wizard` receives `view-toggle:modeChanged` event
3. When switching to wizard: navigates to first empty required field
4. Navigation dots update to show filled (green) vs empty (gray) state

### Usage in Views

```erb
<div data-controller="view-toggle">
  <%# Toggle Switch %>
  <label class="flex items-center gap-2">
    <span>Traditional</span>
    <input type="checkbox"
           data-view-toggle-target="toggle"
           data-action="change->view-toggle#toggle">
    <span>Wizard</span>
  </label>

  <%= form_with ... do |f| %>
    <%# Wizard Container %>
    <div data-view-toggle-target="wizardContainer"
         data-controller="wizard"
         data-wizard-total-fields-value="<%= @fields.count %>">
      <% @fields.each_with_index do |field, i| %>
        <div data-wizard-target="card">
          <%= render "forms/fields/#{field.type}", field: field, form: f %>
        </div>
      <% end %>

      <%# Navigation Dots %>
      <div class="flex gap-2">
        <% @fields.each_with_index do |field, i| %>
          <button data-wizard-target="dot"
                  data-action="click->wizard#goTo"
                  data-index="<%= i %>">
          </button>
        <% end %>
      </div>
    </div>

    <%# Traditional Container %>
    <div data-view-toggle-target="traditionalContainer" class="hidden">
      <% @fields.each do |field| %>
        <%= render "forms/fields/#{field.type}", field: field, form: f %>
      <% end %>
    </div>
  <% end %>
</div>
```

### Wizard Navigation Dots

Dots visually indicate field completion status:

| State | Color | Description |
|-------|-------|-------------|
| Active | Primary + ring | Currently selected field |
| Filled | Success (green) | Field has a value |
| Empty | Base-300 (gray) | Field is empty |

### Key Methods

**view-toggle controller:**
- `toggle()` - Switch between modes
- `syncFormData()` - Copy values between containers
- `setWizardMode()` / `setTraditionalMode()` - Programmatic mode changes

**wizard controller:**
- `next()` / `previous()` - Navigate with animation
- `goTo(event)` - Jump to specific field
- `goToInstant(index)` - Navigate without animation (for mode switch)
- `findFirstEmptyFieldIndex()` - Find first empty required field
- `updateNavigationDots()` - Update dot colors based on field state

---

## Best Practices

1. **Prefer Turbo Frames** over full page reloads
2. **Use Turbo Streams** for real-time updates
3. **Keep Stimulus controllers small** and focused
4. **Use data attributes** for configuration
5. **Test frame/stream behavior** in system specs
6. **Coordinate controllers via events** (e.g., `view-toggle:modeChanged`)
7. **Sync form data** when switching between views that share inputs
