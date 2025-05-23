-- scripts/gui/main_gui.lua
-- Main GUI for the Factorio Admin Command Center (FACC).
-- Builds an adaptive, tabbed interface with controls that enable/disable
-- based on active mods (Quality, Space Age). Persists tab, slider, and
-- switch state across open/close cycles.
--
-- Changes in this version:
--   • “Platform Distance” slider + confirm button are fully disabled
--     (greyed out and non-interactable) whenever the Space Age DLC/mod
--     is not present.

local M = {}

--------------------------------------------------------------------------------
-- Mod detection
--------------------------------------------------------------------------------
local quality_enabled   = script.active_mods["quality"]    ~= nil
local space_age_enabled = script.active_mods["space-age"] ~= nil

--------------------------------------------------------------------------------
-- Persistent state initialization
--------------------------------------------------------------------------------
local function ensure_persistent_state()
  storage.facc_gui_state = storage.facc_gui_state or {}
  local s = storage.facc_gui_state
  s.tab      = s.tab      or "essentials"  -- default tab
  s.sliders  = s.sliders  or {}            -- slider values
  s.switches = s.switches or {}            -- switch states
  s.is_open  = s.is_open  or false         -- GUI open flag
end

--------------------------------------------------------------------------------
-- Save all slider values in storage (recursive)
--------------------------------------------------------------------------------
local function save_all_sliders(element)
  if element.type == "slider" then
    storage.facc_gui_state.sliders[element.name] = element.slider_value
  end
  if element.children then
    for _, child in ipairs(element.children) do
      save_all_sliders(child)
    end
  end
end

--------------------------------------------------------------------------------
-- Determine if a given GUI control should be enabled
--------------------------------------------------------------------------------
local function is_feature_enabled(name)
  -- Platform Distance only when Space Age is active
  if name == "facc_set_platform_distance" then
    return space_age_enabled
  end
  -- Legendary Armor requires both Quality & Space Age
  if name == "facc_create_legendary_armor" then
    return quality_enabled and space_age_enabled
  end
  -- Blueprint / conversion tools require Quality mod
  if name == "facc_convert_inventory"
      or name == "facc_upgrade_blueprints"
      or name == "facc_convert_to_legendary" then
    return quality_enabled
  end
  -- All others always enabled
  return true
end

--------------------------------------------------------------------------------
-- Add a labelled control block: label + optional slider + switch/button
--------------------------------------------------------------------------------
local function add_function_block(parent, elem)
  local enabled = is_feature_enabled(elem.name)

  -- separator line
  parent.add{ type="line", direction="horizontal" }

  -- flow container
  local flow = parent.add{ type="flow", direction="horizontal" }
  flow.style.vertical_align           = "center"
  flow.style.horizontally_stretchable = true
  flow.style.horizontal_spacing       = 6

  -- left area: caption + slider (if present)
  local left = flow.add{ type="flow", direction="vertical" }
  left.style.horizontally_stretchable = true
  left.style.vertical_spacing         = 4
  left.add{ type="label", caption = elem.caption }

  if elem.slider then
    local slider_flow = left.add{ type="flow", direction="horizontal" }
    slider_flow.style.horizontal_spacing = 6
    slider_flow.style.vertical_align    = "center"

    local saved = storage.facc_gui_state.sliders[elem.slider.name]
    local init  = saved ~= nil and saved or elem.slider.default

    -- slider widget
    local slider = slider_flow.add{
      type            = "slider",
      name            = elem.slider.name,
      minimum_value   = elem.slider.min,
      maximum_value   = elem.slider.max,
      value           = init,
      discrete_slider = true
    }
    slider.style.horizontally_stretchable = true
    slider.enabled = enabled

    -- numeric text box
    local box = slider_flow.add{
      type      = "textfield",
      name      = elem.slider.name .. "_value",
      text      = tostring(init),
      numeric   = true,
      read_only = true,
      style     = "short_number_textfield"
    }
    box.style.width = 40
    box.enabled = enabled
  end

  -- right area: switch or confirm button
  local right = flow.add{ type="flow", direction="horizontal" }
  right.style.horizontal_align = "right"

  if elem.switch then
    local state = storage.facc_gui_state.switches[elem.name] and "right" or "left"
    local sw = right.add{
      type                = "switch",
      name                = elem.name,
      switch_state        = state,
      left_label_caption  = {"facc.switch-off"},
      right_label_caption = {"facc.switch-on"}
    }
    sw.enabled = enabled

  else
    local btn = right.add{
      type    = "sprite-button",
      name    = elem.name,
      sprite  = "utility.confirm_slot",
      style   = "item_and_count_select_confirm",
      tooltip = {"facc.confirm-button"}
    }
    btn.enabled = enabled
  end
end

--------------------------------------------------------------------------------
-- Tab order and definitions
--------------------------------------------------------------------------------
local TAB_ORDER = {
  "essentials", "switchers", "automation",
  "character", "blueprint",
  "map", "misc", "unlocks"
}

local TABS = {
  essentials = {
    label    = {"facc.tab-essentials"},
    elements = {
      { name="facc_toggle_editor",  caption={"facc.toggle-editor"} },
      { name="facc_console",        caption={"facc.console"} }
    }
  },
  switchers = {
    label    = {"facc.tab-switchers"},
    elements = {
      { name="facc_indestructible_builds", caption={"facc.indestructible-builds"}, switch=true },
      { name="facc_cheat_mode",            caption={"facc.cheat-mode"},          switch=true },
      { name="facc_always_day",            caption={"facc.always-day"},          switch=true },
      { name="facc_disable_pollution",     caption={"facc.disable-pollution"},   switch=true },
      { name="facc_disable_friendly_fire", caption={"facc.disable-friendly-fire"},switch=true },
      { name="facc_peaceful_mode",         caption={"facc.peaceful-mode"},       switch=true },
      { name="facc_enemy_expansion",       caption={"facc.enemy-expansion"},     switch=true },
      { name="facc_toggle_minable",        caption={"facc.toggle-minable"},      switch=true }
    }
  },
  automation = {
    label    = {"facc.tab-automation"},
    elements = {
      {
        name   = "facc_auto_clean_pollution",
        caption= {"facc.auto-clean-pollution"},
        slider = { name="slider_auto_clean_pollution", min=1, max=300, default=1 },
        switch = true
      },
      {
        name   = "facc_auto_instant_research",
        caption= {"facc.auto-instant-research"},
        slider = { name="slider_auto_instant_research", min=1, max=300, default=1 },
        switch = true
      }
    }
  },
  character = {
    label    = {"facc.tab-character"},
    elements = {
      { name="facc_delete_ownerless", caption={"facc.delete-ownerless"} }
    }
  },
  blueprint = {
    label    = {"facc.tab-blueprint"},
    elements = {
      { name="facc_build_all_ghosts", caption={"facc.build-all-ghosts"} }
    }
  },
  map = {
    label    = {"facc.tab-map"},
    elements = {
      {
        name   = "facc_remove_cliffs",
        caption= {"facc.remove-cliffs"},
        slider = { name="slider_remove_cliffs", min=1, max=150, default=50 }
      },
      {
        name   = "facc_remove_nests",
        caption= {"facc.remove-nests"},
        slider = { name="slider_remove_nests", min=1, max=150, default=50 }
      },
      {
        name   = "facc_reveal_map",
        caption= {"facc.reveal-map"},
        slider = { name="slider_reveal_map", min=1, max=150, default=150 }
      },
      { name="facc_hide_map",         caption={"facc.hide-map"} },
      { name="facc_remove_decon",     caption={"facc.remove-decon"} },
      { name="facc_remove_pollution", caption={"facc.remove-pollution"} }
    }
  },
  misc = {
    label    = {"facc.tab-misc"},
    elements = {
      { name="facc_repair_rebuild",    caption={"facc.repair-rebuild"} },
      { name="facc_recharge_energy",   caption={"facc.recharge-energy"} },
      { name="facc_ammo_turrets",      caption={"facc.ammo-turrets"} },
      { name="facc_increase_resources",caption={"facc.increase-resources"} },
      -- Platform Distance control (slider + confirm)
      {
        name   = "facc_set_platform_distance",
        caption= {"facc.platform-distance"},
        slider = { name="slider_platform_distance", min=0.0, max=1.0, default=0.99 }
      }
    }
  },
  unlocks = {
    label    = {"facc.tab-unlocks"},
    elements = {
      { name="facc_unlock_recipes",      caption={"facc.unlock-recipes"} },
      { name="facc_unlock_technologies", caption={"facc.unlock-technologies"} }
    }
  }
}

-- inject Quality-only features (will be disabled if missing)
table.insert(TABS.character.elements,
  { name="facc_convert_inventory", caption={"facc.convert-inventory"} }
)
table.insert(TABS.character.elements,
  { name="facc_create_legendary_armor", caption={"facc.create-legendary-armor"} }
)
table.insert(TABS.blueprint.elements,
  { name="facc_upgrade_blueprints", caption={"facc.upgrade-blueprints"} }
)
table.insert(TABS.map.elements, {
  name   = "facc_convert_to_legendary",
  caption= {"facc.convert-to-legendary"},
  slider = { name="slider_convert_to_legendary", min=1, max=150, default=75 }
})

--------------------------------------------------------------------------------
-- GUI open/close helpers
--------------------------------------------------------------------------------
local function close_gui(player)
  local frame = player.gui.screen["facc_main_frame"]
  if frame then frame.destroy() end
end

local function open_gui(player)
  if not (player and player.valid and (not game.is_multiplayer() or player.admin)) then
    player.print({"facc.not-allowed"})
    return
  end
  ensure_persistent_state()

  local frame = player.gui.screen.add{
    type      = "frame",
    name      = "facc_main_frame",
    caption   = {"facc.main-title"},
    direction = "vertical"
  }
  frame.auto_center = true

  -- header with close button
  local header = frame.add{ type="flow", direction="horizontal" }
  header.style.horizontal_align         = "right"
  header.style.horizontally_stretchable = true
  header.add{
    type    = "sprite-button",
    name    = "facc_close_main_gui",
    sprite  = "utility/close_fat",
    style   = "tool_button_red",
    tooltip = {"facc.close-menu"}
  }

  -- tabbed pane
  local pane = frame.add{ type="tabbed-pane", name="facc_tabbed_pane" }
  local tab_indices = {}
  for idx, key in ipairs(TAB_ORDER) do
    local def = TABS[key]
    local btn = pane.add{ type="tab", name="facc_tab_btn_"..key, caption=def.label }
    local content = pane.add{ type="flow", direction="vertical", name="facc_tab_content_"..key }
    content.style.vertically_stretchable = true
    content.style.padding               = 8
    pane.add_tab(btn, content)
    tab_indices[key] = idx

    for _, elem in ipairs(def.elements) do
      add_function_block(content, elem)
    end
  end

  -- restore last-opened tab
  local saved = storage.facc_gui_state.tab
  if tab_indices[saved] then
    pane.selected_tab_index = tab_indices[saved]
  end
end

--------------------------------------------------------------------------------
-- Public: toggle the main GUI
--------------------------------------------------------------------------------
function M.toggle_main_gui(player)
  ensure_persistent_state()
  if player.gui.screen["facc_main_frame"] then
    -- save state
    local pane = player.gui.screen["facc_main_frame"]["facc_tabbed_pane"]
    if pane then
      storage.facc_gui_state.tab = TAB_ORDER[pane.selected_tab_index]
      save_all_sliders(pane)
    end
    storage.facc_gui_state.is_open = false
    close_gui(player)
  else
    open_gui(player)
    storage.facc_gui_state.is_open = true
  end
end

M.ensure_persistent_state = ensure_persistent_state
return M
