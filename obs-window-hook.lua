--- window hook for obs-studio ---
--- mtxwrz / mtxwrz@gmail.com / mtxwrz#5848 ---

local obs = obslua
local ffi = require("ffi")

--- config
local srcs_number = 4
local polling_rate = 2 --- seconds

local ID_PREFIX = 'src_'
local TARGET_TYPE = 'window_capture'
local TARGET_CLASS = 'GLFW30'
local TARGET_EXE = 'PokerStars.exe'

local srcs_map = {}

-----------------------------------------------------------------------

ffi.cdef[[
  int GetWindowThreadProcessId(void* hWnd, void* lpdwProcessId);
  int GetWindowTextLengthA(void* hWnd);
  int GetWindowTextA(void* hWnd, char* str, int count);
  int GetClassNameA(void* hWnd, char* str, int count);
  bool IsWindowVisible(void* hWnd);
  typedef int (__stdcall *WNDENUMPROC)(void *hwnd, intptr_t l);
  int EnumWindows(WNDENUMPROC func, intptr_t l);
]]

-----------------------------------------------------------------------

local function get_window_title(hWnd)
  local size = ffi.C.GetWindowTextLengthA(hWnd) + 1
  local res = ffi.new('char[?]', size)

  ffi.C.GetWindowTextA(hWnd, res, size)

  res = ffi.string(res)
  local word = '.([%d%p]+)%/.([%d%p]+)'
  if res:match("EUR") then res = res:gsub(word, '€%1/€%2') end
  if res:match("GBP") then res = res:gsub(word, '£%1/£%2') end
  res = res:gsub('ante.', 'ante ')

  return res
end

local function get_window_class(hwnd)
  local res = ffi.new('char[?]', 64)
  ffi.C.GetClassNameA(hwnd, res, 64)
  return ffi.string(res)
end

local function get_window_list()
  local res = {}

  local function callback(hWnd, l)
    if not ffi.C.IsWindowVisible(hWnd) then
      return true end

    local window_class = get_window_class(hWnd)
    if window_class == TARGET_CLASS then
      table.insert(res, hWnd) end

    return true
  end

  local ffi_callback = ffi.cast("WNDENUMPROC", callback)
  ffi.C.EnumWindows(ffi_callback, 0)
  ffi_callback:free()

  return res
end

-----------------------------------------------------------------------

local function is_value_in_table(value, table)
  for _, v in pairs(table) do
    if value == v then return true end
  end
  return false
end

local function map_src_to_window(src, targets)
  for _, hwnd in pairs(targets) do
    if not is_value_in_table(hwnd, srcs_map) then
      srcs_map[src] = hwnd
      break
    end
  end
end

-----------------------------------------------------------------------

local function update_sources()
  local current_scene = obs.obs_frontend_get_current_scene()
  local scene = obs.obs_scene_from_source(current_scene)

  for src_name, hwnd in pairs(srcs_map) do
    local source = obs.obs_scene_find_source(scene, src_name)

    if not source then goto continue end

    local scene_item = obs.obs_sceneitem_get_source(source)
    local data = obs.obs_source_get_settings(scene_item)

    if hwnd then
      local window_title = get_window_title(hwnd)
                           .. ':' .. TARGET_CLASS
                           .. ':' .. TARGET_EXE
      local current_title = obs.obs_data_get_string(data, 'window')

      if window_title == current_title then
        obs.obs_data_release(data)
        goto continue
      end

      obs.obs_data_set_string(data, 'window', window_title)
      obs.obs_source_update(scene_item, data)
      obs.obs_source_set_enabled(scene_item, true)
    end
    
    obs.obs_data_release(data)
    ::continue::
  end
end


local function main()
  local matches = 0
  local not_matches_table = {}
  local target_windows_table = get_window_list()

  for src, hwnd in pairs(srcs_map) do
    if is_value_in_table(hwnd, target_windows_table) then
      matches = matches + 1
    else
      table.insert(not_matches_table, src)
    end
  end

  if matches == srcs_number then
    goto finish
  end

  if matches == #target_windows_table then
    for _, src in pairs(not_matches_table) do
      srcs_map[src] = false
    end
    goto finish
  end

  for _, src in pairs(not_matches_table) do
    map_src_to_window(src, target_windows_table)
  end

  update_sources()

  ::finish::
end

-----------------------------------------------------------------------

local function add_source_dropdown(id, props, sources)
  local list = obs.obs_properties_add_list(props, ID_PREFIX .. id, 'Source ' .. id,
                                           obs.OBS_COMBO_TYPE_EDITABLE,
                                           obs.OBS_COMBO_FORMAT_STRING)
  for _, source in pairs(sources) do
    local name = obs.obs_source_get_name(source)
    local source_id = obs.obs_source_get_unversioned_id(source)
    if source_id == TARGET_TYPE then
      obs.obs_property_list_add_string(list, name, name)
    end
  end
end

-----------------------------------------------------------------------

function script_description()
  return '<h1>Hook to window</h1>'
         .. '<p><font color=#666>author: mtxwrz / mtxwrz@gmail.com / mtxwrz#5848</p><br>'
         .. '<i>ps. Window Match Priority must be set to Window title must match.</i>'
end

function script_defaults(settings)
  srcs_map = {}
  for i = 1, srcs_number do
    obs.obs_data_set_default_string(settings, ID_PREFIX .. i, '')
  end
end

function script_update(settings)
  local start_check = true

  for i = 1, srcs_number do
    local id = obs.obs_data_get_string(settings, ID_PREFIX .. i)
    if id == '' then
      start_check = false
    else
      srcs_map[id] = false
    end
  end

  if start_check then
    main()
    obs.timer_remove(main)
    obs.timer_add(main, polling_rate * 1000)
  else
    obs.timer_remove(main)
  end

end

function script_unload()
  obs.timer_remove(main)  
end

function script_properties(settings)
  local sources = obs.obs_enum_sources()
  local props = obs.obs_properties_create()

  for id = 1, srcs_number do
    add_source_dropdown(id, props, sources)
  end

  obs.source_list_release(sources)
  return props
end
