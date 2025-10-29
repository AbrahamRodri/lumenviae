# Phoenix LiveView Architecture Standards

This document defines the standard architectural patterns used in this codebase for organizing LiveViews, components, templates, and supporting modules.

## Table of Contents

1. [LiveView Organization](#liveview-organization)
2. [Component Architecture](#component-architecture)
3. [Template Organization](#template-organization)
4. [Parent-Child Communication](#parent-child-communication)
5. [Supporting Modules](#supporting-modules)
6. [Directory Structure](#directory-structure)
7. [Naming Conventions](#naming-conventions)
8. [Key Patterns](#key-patterns)

---

## LiveView Organization

### Directory Structure

Each LiveView follows this standard structure:

```
lib/{web_module}/live/{resource}/{action}/
├── {action}.ex              # Main LiveView module
├── {action}.html.heex       # Main template
├── {component_name}/        # Sub-components
│   ├── {component_name}.ex
│   └── {component_name}.html.heex
└── {modal_name}_modal/      # Modal components
    ├── {modal_name}_modal.ex
    └── {modal_name}_modal.html.heex
```

### Module Naming Pattern

```elixir
defmodule {WebModule}.Live.{Resource}.{Action} do
  use {WebModule}, :live_view

  def mount(%{"organization_id" => org_id} = params, session, socket) do
    # mount logic
  end
end
```

**Examples:**
- `OperatorWeb.Live.Zone.List`
- `OperatorWeb.Live.Asset.Show`
- `ControlTowerWeb.Live.Exception.List`

### Breaking Up Complex LiveViews

Never create monolithic LiveViews. Break them into smaller, focused components:

**Example: Zone List**
```
lib/operator_web/live/zone/list/
├── list.ex                    # Main LiveView (filtering, state management)
├── list.html.heex            # Main template
├── table_header/
│   ├── table_header.ex       # Header with sorting, select-all
│   └── table_header.html.heex
└── table_body/
    ├── table_body.ex         # Individual row rendering
    └── table_body.html.heex
```

**Usage in template:**
```heex
<.live_component
  module={OperatorWeb.Live.Zone.List.TableHeader}
  id="zone-list-table-header"
  zones={@zones}
  checked_zone_ids={@checked_zone_ids}
/>

<.live_component
  :for={zone <- @zones}
  module={OperatorWeb.Live.Zone.List.TableBody}
  id={zone.id}
  zone={zone}
  organization={@organization}
/>
```

### State Management

**Initialize in Mount:**
```elixir
def mount(%{"organization_id" => org_id} = params, session, socket) do
  socket
  |> assign(:organization, organization)
  |> assign(:zones, zones)
  |> assign(:checked_zone_ids, [])
  |> then(&{:ok, &1})
end
```

**Update in Events:**
```elixir
def handle_event("validate", %{"query" => query_params}, socket) do
  socket =
    socket
    |> update(:query_input, fn query_input ->
      query_input
      |> QueryInput.changeset(query_params)
      |> Ecto.Changeset.apply_action!(:sort)
    end)

  {:noreply, socket}
end
```

**URL as Source of Truth:**
```elixir
socket
|> push_patch(to: Routes.resource_path(socket, action, org_id, query_params))
```

---

## Component Architecture

### Component Types

#### 1. Live Components (Stateful)

Use for components that need to handle their own events or maintain state.

```elixir
defmodule OperatorWeb.Live.Zone.Show.DeleteModal do
  use OperatorWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("submit", %{"delete" => input}, socket) do
    # Handle deletion
    send(self(), {__MODULE__, :asset_deleted, %{}})
    {:noreply, socket}
  end
end
```

**Characteristics:**
- Use `use {WebModule}, :live_component`
- Implement lifecycle callbacks: `mount/1`, `update/2`, `handle_event/3`
- Can maintain their own state
- Must have a unique `id` when used

#### 2. Function Components (Stateless)

Use for pure presentational components without state.

```elixir
defmodule CommonWeb.Components.DatePicker do
  use Phoenix.Component

  def render(assigns) do
    assigns = Map.put_new(assigns, :value, "")

    ~H"""
    <div
      id={@id}
      class="control has-icons-left date-picker-wrapper"
      phx-hook="DatePicker"
      data-value={@value}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
end
```

**Characteristics:**
- Use `use Phoenix.Component`
- Single `render/1` function
- No state or event handling
- Highly reusable
- Can accept slots via `render_slot/1`

#### 3. Page Components (Modern Pattern)

Use for breaking up page UI into logical sections with multiple related components.

```elixir
defmodule ControlTowerWeb.Pages.Shipment.Show.ProgressPanel do
  use ControlTowerWeb, :component

  # Public component function
  def progress_panel(assigns) do
    ~H"""
    <div class={"column #{@column_size}"}>
      <.status shipment={@shipment} context={@context} />
      <.eta_at shipment={@shipment} context={@context} />
      <.progress_bar shipment={@shipment} />
      <.shipment_details shipment={@shipment} context={@context} />
    </div>
    """
  end

  # Private helper components
  defp status(assigns) do
    ~H"""
    <div class="column">
      <!-- status markup -->
    </div>
    """
  end

  defp eta_at(assigns) do
    ~H"""
    <div class="column">
      <!-- ETA markup -->
    </div>
    """
  end

  defp shipment_details(assigns) do
    assigns = assign_detail_items(assigns)
    ~H"""
    <div class="column">
      <%= for {key, val} <- @items do %>
        <div><strong><%= key %>:</strong> <%= val %></div>
      <% end %>
    </div>
    """
  end
end
```

**Characteristics:**
- Use `use {WebModule}, :component`
- Multiple public and private component functions
- No lifecycle management
- Fragments UI into logical sub-functions
- Easier testing and composition
- Can transform assigns before rendering

### Component Organization Patterns

#### Pattern 1: Simple Component Hierarchy
```
lib/operator_web/live/zone/list/
├── list.ex
├── list.html.heex
├── table_header/
│   ├── table_header.ex
│   └── table_header.html.heex
└── table_body/
    ├── table_body.ex
    └── table_body.html.heex
```

#### Pattern 2: Multiple Modals
```
lib/operator_web/live/asset/show/
├── show.ex
├── show.html.heex
├── delete_modal/
│   ├── delete_modal.ex
│   └── delete_modal.html.heex
├── edit_modal/
│   ├── edit_modal.ex
│   └── edit_modal.html.heex
└── transfer_modal/
    ├── transfer_modal.ex
    └── transfer_modal.html.heex
```

#### Pattern 3: Nested Hierarchies
```
lib/operator_web/live/zone/schedule/
├── schedule.ex
├── schedule_modal/
│   ├── schedule_modal.ex
│   ├── schedule_modal.html.heex
│   └── weekly_schedule_inputs/
│       ├── weekly_schedule_inputs.ex
│       └── weekly_schedule_inputs.html.heex
└── timeline_item/
    ├── timeline_item.ex
    ├── timeline_item.html.heex
    └── body_attributes/
        ├── body_attributes.ex
        └── body_attributes.html.heex
```

---

## Template Organization

### Embedded vs. Separate Files

**For LiveViews: Use Separate Files**
```
lib/operator_web/live/zone/list/list.ex         # Module
lib/operator_web/live/zone/list/list.html.heex  # Template (auto-loaded)
```

**For Components: Use Embedded Sigils**
```elixir
def render(assigns) do
  ~H"""
  <div id={@id}>
    <%= render_slot(@inner_block) %>
  </div>
  """
end
```

### Fragment Pattern

Break complex templates into private functions:

```elixir
def main_panel(assigns) do
  ~H"""
  <div class="panel">
    <.header title={@title} />
    <.body content={@content} />
    <.footer actions={@actions} />
  </div>
  """
end

defp header(assigns) do
  ~H"""
  <div class="panel-header">
    <h2><%= @title %></h2>
  </div>
  """
end

defp body(assigns) do
  ~H"""
  <div class="panel-body">
    <%= @content %>
  </div>
  """
end

defp footer(assigns) do
  ~H"""
  <div class="panel-footer">
    <%= for action <- @actions do %>
      <button><%= action %></button>
    <% end %>
  </div>
  """
end
```

**Benefits:**
- Improved readability
- Easier to reorder sections
- Better testability
- Clear separation of concerns

---

## Parent-Child Communication

### Parent → Child

Pass data via assigns:

```heex
<.live_component
  module={OperatorWeb.Live.Zone.List.TableBody}
  id={zone.id}
  zone={zone}
  organization={@organization}
  selected={zone.id in @selected_ids}
/>
```

### Child → Parent

#### Method 1: Send Messages
```elixir
# In child component
def handle_event("delete", _params, socket) do
  send(self(), {__MODULE__, :asset_deleted, %{id: socket.assigns.id}})
  {:noreply, socket}
end

# In parent LiveView
def handle_info({ChildComponent, :asset_deleted, %{id: id}}, socket) do
  # Handle deletion
  {:noreply, socket}
end
```

#### Method 2: Public API Functions
```elixir
# In child component
defmodule OperatorWeb.Live.Analysis.Form do
  # Public API
  def add_form_component(form_component_id, type) do
    Phoenix.LiveView.send_update(__MODULE__,
      id: form_component_id,
      constraint_update: %{action: :add, type: type}
    )
    :ok
  end

  def update_form_component(form_component_id, ref, changeset) do
    Phoenix.LiveView.send_update(__MODULE__,
      id: form_component_id,
      constraint_update: %{action: :update, ref: ref, changeset: changeset}
    )
    :ok
  end

  def remove_form_component(form_component_id, ref) do
    Phoenix.LiveView.send_update(__MODULE__,
      id: form_component_id,
      constraint_update: %{action: :remove, ref: ref}
    )
    :ok
  end
  # End Public API

  @impl true
  def update(%{constraint_update: update} = assigns, socket) do
    # Handle update
  end
end

# Usage from parent or sibling
OperatorWeb.Live.Analysis.Form.add_form_component("form-id", :temperature)
```

**Mark public APIs clearly:**
```elixir
# Public API

# ... public functions ...

# End Public API
```

---

## Supporting Modules

### Data Module Pattern

Centralize GraphQL queries and fragments:

```elixir
# lib/control_tower_web/live/shipment/data.ex
defmodule ControlTowerWeb.Live.Shipment.Data do
  alias Common.Sensetra
  alias ControlTower.Query

  def query("basic_org_data") do
    """
    query ($org_id: ID!) {
      organization(id: $org_id) {
        id
        name
        shipment_templates {
          id
          name
        }
      }
    }
    """
  end

  def query("shipment_list", variables) do
    """
    query ($org_id: ID!, $filters: ShipmentFilters) {
      organization(id: $org_id) {
        shipments(filters: $filters) {
          ...ShipmentListInfo
        }
      }
    }

    #{@shipment_list_info}
    """
  end

  @shipment_list_info """
  fragment ShipmentListInfo on Shipment {
    id
    name
    state
    created_at
  }
  """
end
```

**Benefits:**
- Centralized query management
- Easy to reuse across pages
- Keeps LiveView modules clean
- Improves testability

### Helpers Module Pattern

Extract business logic and transformations:

```elixir
# lib/operator_web/live/analysis/helpers.ex
defmodule OperatorWeb.Live.Analysis.Helpers do
  def format_constraint(constraint) do
    # Complex transformation logic
  end

  def validate_analysis(analysis) do
    # Validation logic
  end

  def prepare_for_submission(form_data) do
    # Preparation logic
  end
end
```

### Complex Page Helpers

For very complex pages, create dedicated helper modules:

```
lib/control_tower_web/pages/shipment/show/
├── show.ex
├── show.html.heex
├── helpers/
│   ├── derive_shipment_assigns.ex  # Complex state derivation
│   └── shipment_helpers.ex          # Business logic
└── components/
    ├── progress_panel.ex
    └── shipment_labels.ex
```

---

## Directory Structure

### Complete Web Module Structure

```
lib/{web_module}/
├── components/               # Shared function components
│   ├── date_picker.ex
│   ├── address_components.ex
│   └── nav/
│       ├── nav.ex
│       └── nav.html.heex
├── live/
│   ├── modal_component.ex   # Shared modal wrapper
│   ├── live_helpers.ex      # Helper functions
│   ├── {resource}/
│   │   ├── {action}/
│   │   │   ├── {action}.ex           # LiveView
│   │   │   ├── {action}.html.heex    # Template
│   │   │   ├── {sub_component}/      # Sub-components
│   │   │   │   ├── {sub_component}.ex
│   │   │   │   └── {sub_component}.html.heex
│   │   │   └── {modal}_modal/        # Modals
│   │   │       ├── {modal}_modal.ex
│   │   │       └── {modal}_modal.html.heex
│   │   ├── data.ex          # GraphQL queries
│   │   └── helpers.ex       # Helper functions
│   └── ...
├── pages/                   # Alternative organization
│   ├── {feature}/
│   │   ├── {page}/
│   │   │   ├── {page}.ex
│   │   │   ├── {page}.html.heex
│   │   │   ├── components/
│   │   │   └── helpers/
│   │   └── ...
│   └── ...
├── templates/               # Legacy templates (non-LiveView)
├── views/                   # Legacy Phoenix Views
└── router.ex
```

### Bounded Contexts

This codebase uses multiple web modules (bounded contexts):

- `ControlTowerWeb` - Shipping/logistics features
- `OperatorWeb` - Administrative/operational features
- `MonitoringWeb` - Monitoring features
- `AssetTracingWeb` - Asset tracking features
- `CommonWeb` - Shared components across contexts

Each follows the same architectural patterns.

---

## Naming Conventions

### LiveView Modules
- **Pattern:** `{WebModule}.Live.{Resource}.{Action}`
- **Examples:**
  - `OperatorWeb.Live.Zone.List`
  - `OperatorWeb.Live.Asset.Show`
  - `ControlTowerWeb.Live.Exception.List`

### Live Components
- **Pattern:** `{WebModule}.Live.{Resource}.{Action}.{ComponentName}`
- **Examples:**
  - `OperatorWeb.Live.Zone.List.TableBody`
  - `OperatorWeb.Live.Asset.Show.DeleteModal`
  - `ControlTowerWeb.Live.Exception.Filter.Pills`

### Function Components
- **Pattern:** `{WebModule}.Components.{ComponentName}`
- **Examples:**
  - `CommonWeb.Components.DatePicker`
  - `ControlTowerWeb.Components.LabelsModal`

### Page Components
- **Pattern:** `{WebModule}.Pages.{Feature}.{Page}.{ComponentName}`
- **Examples:**
  - `ControlTowerWeb.Pages.Shipment.Show.ProgressPanel`
  - `ControlTowerWeb.Pages.Shipment.Show.ShipmentLabels`

### Helper Modules
- **Pattern:** `{WebModule}.Live.{Resource}.{HelperType}`
- **Examples:**
  - `ControlTowerWeb.Live.Shipment.Data`
  - `OperatorWeb.Live.Analysis.Helpers`

### File Names
- **LiveViews:** `{action}.ex` and `{action}.html.heex`
- **Components:** `{component_name}.ex` and optionally `{component_name}.html.heex`
- **Helpers:** `data.ex`, `helpers.ex`

---

## Key Patterns

### 1. One Resource Per LiveView

Each LiveView handles one domain resource (Zone, Asset, Exception, Shipment, etc.). Don't mix multiple resources in a single LiveView.

### 2. URL as Source of Truth

Persist state in URL parameters, not just socket assigns:

```elixir
def handle_event("filter", %{"filter" => filter_params}, socket) do
  socket
  |> push_patch(to: Routes.resource_path(
    socket,
    :index,
    socket.assigns.org_id,
    filter: filter_params
  ))
  |> then(&{:noreply, &1})
end
```

### 3. Break Up Complexity

Never create monolithic components. If a LiveView or component exceeds ~200 lines, break it into smaller pieces:

- Extract modals into separate components
- Split tables into header/body components
- Create page components for sections
- Use fragment functions for template sections

### 4. Modal Wrapper Pattern

Use a shared modal wrapper component:

```elixir
# In live_helpers.ex
def live_modal(component, opts) do
  path = Keyword.fetch!(opts, :return_to)
  title = Keyword.get(opts, :modal_title)

  assigns = %{
    module: ControlTowerWeb.ModalComponent,
    id: :modal,
    title: title,
    return_to: path,
    component: component,
    component_attrs: Map.new(opts)
  }

  Phoenix.Component.live_component(assigns)
end
```

Usage:
```heex
<%= live_modal ControlTowerWeb.Live.Asset.Show.DeleteModal,
  id: @asset.id,
  modal_title: "Delete Asset",
  return_to: Routes.asset_path(@socket, :show, @org_id, @asset.id),
  asset: @asset
%>
```

### 5. Explicit Public APIs

For complex components with child-parent communication, define clear public APIs:

```elixir
# Public API

def add_item(component_id, item) do
  send_update(__MODULE__, id: component_id, action: :add, item: item)
end

def remove_item(component_id, item_id) do
  send_update(__MODULE__, id: component_id, action: :remove, item_id: item_id)
end

# End Public API
```

### 6. Separate Data Layer

Keep GraphQL queries and data fetching in dedicated modules:

```elixir
# In LiveView
def mount(params, session, socket) do
  query = Shipment.Data.query("shipment_list")
  {:ok, result} = Sensetra.query(query, variables)

  {:ok, assign(socket, shipments: result.shipments)}
end
```

### 7. Fragment Templates

Use private functions to fragment complex templates:

```elixir
def main(assigns) do
  ~H"""
  <.section_1 data={@data} />
  <.section_2 data={@data} />
  <.section_3 data={@data} />
  """
end

defp section_1(assigns), defp section_2(assigns), defp section_3(assigns)
```

### 8. Consistent File Organization

Match directory structure to module names:

- Module: `OperatorWeb.Live.Zone.List.TableBody`
- File: `lib/operator_web/live/zone/list/table_body/table_body.ex`

### 9. Periodic Updates with Timers

For real-time updates, use process timers:

```elixir
@tick_ms 10_000

defp update_tick(socket, time \\ @tick_ms) do
  update(socket, :__tick__, fn ref ->
    if ref, do: Process.cancel_timer(ref)
    if time, do: Process.send_after(self(), {__MODULE__, :tick, %{}}, time)
  end)
end

def handle_info({__MODULE__, :tick, _}, socket) do
  socket
  |> refresh_data()
  |> update_tick()
  |> then(&{:noreply, &1})
end
```

### 10. No Monolithic Views

Even complex pages should be broken into components. Examples from the codebase:

- Shipment Show page: Broken into ProgressPanel, ShipmentLabels, Timeline components
- Analysis Form: Broken into NameDescription, constraint components, NewConstraint
- Zone List: Broken into TableHeader, TableBody components

---

## Quick Reference

### Starting a New Feature

1. Create directory structure:
   ```
   lib/{web_module}/live/{resource}/{action}/
   ├── {action}.ex
   └── {action}.html.heex
   ```

2. Define the LiveView:
   ```elixir
   defmodule {WebModule}.Live.{Resource}.{Action} do
     use {WebModule}, :live_view

     def mount(params, session, socket) do
       {:ok, socket}
     end
   end
   ```

3. Add routing:
   ```elixir
   live "/{resource}", {WebModule}.Live.{Resource}.{Action}
   ```

4. Break down complexity as you build:
   - Extract modals → `{modal}_modal/`
   - Extract components → `{component}/`
   - Extract queries → `data.ex`
   - Extract helpers → `helpers.ex`

### Component Decision Tree

- **Need state/events?** → Live Component
- **Pure presentation?** → Function Component
- **Multiple related functions?** → Page Component
- **Shared across features?** → Put in `components/`
- **Feature-specific?** → Put in `live/{resource}/{action}/`

---

## Examples from Codebase

### Well-Structured Feature: Zone Management

```
lib/operator_web/live/zone/
├── list/
│   ├── list.ex               # List view with filtering
│   ├── list.html.heex
│   ├── table_header/         # Sortable header
│   └── table_body/           # Individual rows
├── show/
│   ├── show.ex               # Detail view
│   ├── show.html.heex
│   └── delete_modal/         # Delete action
├── schedule/
│   ├── schedule.ex           # Schedule management
│   ├── schedule_modal/       # Schedule editor
│   └── timeline_item/        # Timeline display
├── new/
│   └── new.ex                # Creation form
├── data.ex                   # All queries
└── helpers.ex                # Shared logic
```

### Well-Structured Complex Page: Shipment Show

```
lib/control_tower_web/pages/shipment/show/
├── show.ex                           # Main LiveView
├── show.html.heex
├── components/
│   ├── progress_panel.ex             # Progress section
│   ├── shipment_labels.ex            # Labels section
│   └── timeline.ex                   # Timeline section
├── helpers/
│   ├── derive_shipment_assigns.ex    # Complex derivation
│   └── shipment_helpers.ex           # Business logic
├── edit_modal_component.ex
├── delete_modal_component.ex
└── update_status_modal_component.ex
```

---

## Summary

Follow these principles for all new code:

1. One resource per LiveView
2. Break complex UIs into components
3. Keep queries in `data.ex`
4. Keep business logic in `helpers.ex`
5. Fragment templates with private functions
6. Use URL for state persistence
7. Define clear public APIs for complex components
8. Match directory structure to module names
9. Use appropriate component type for the job
10. Never create monolithic views

This architecture ensures maintainability, testability, and consistency across the entire codebase.
