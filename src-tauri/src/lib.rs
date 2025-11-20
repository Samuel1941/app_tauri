// src-tauri/src/lib.rs
use mlua::{Lua, Table as LuaTable, Value as LuaValue};
use serde_json::{Map as JsonMap, Number, Value as JsonValue};
use std::fs;
use std::path::Path;
use std::sync::Mutex;

fn lua_value_to_json(value: LuaValue) -> Result<JsonValue, mlua::Error> {
    Ok(match value {
        LuaValue::Nil => JsonValue::Null,
        LuaValue::Boolean(b) => JsonValue::Bool(b),
        LuaValue::Integer(i) => JsonValue::Number(i.into()),
        LuaValue::Number(n) => {
            let num = Number::from_f64(n).unwrap_or_else(|| Number::from(0));
            JsonValue::Number(num)
        }
        LuaValue::String(s) => JsonValue::String(s.to_str()?.to_string()),
        LuaValue::Table(t) => {
            let mut is_array = true;
            let mut max_index = 0i64;
            let mut arr_elems: Vec<(i64, LuaValue)> = Vec::new();
            let mut obj_map: JsonMap<String, JsonValue> = JsonMap::new();

            for pair in t.clone().pairs::<LuaValue, LuaValue>() {
                let (k, v) = pair?;
                match k {
                    LuaValue::Integer(i) => {
                        if i <= 0 {
                            is_array = false;
                        } else {
                            if i > max_index {
                                max_index = i;
                            }
                            arr_elems.push((i, v));
                        }
                    }
                    LuaValue::String(ks) => {
                        is_array = false;
                        obj_map.insert(ks.to_str()?.to_string(), lua_value_to_json(v)?);
                    }
                    _ => {
                        is_array = false;
                    }
                }
            }

            if is_array && !arr_elems.is_empty() {
                arr_elems.sort_by_key(|(i, _)| *i);
                let mut arr = Vec::with_capacity(max_index as usize);
                let mut idx = 1i64;

                for (i, v) in arr_elems {
                    while idx < i {
                        arr.push(JsonValue::Null);
                        idx += 1;
                    }
                    arr.push(lua_value_to_json(v)?);
                    idx += 1;
                }

                JsonValue::Array(arr)
            } else {
                JsonValue::Object(obj_map)
            }
        }
        _ => JsonValue::Null,
    })
}

struct LuaAppState {
    lua: Mutex<Lua>,
}

impl LuaAppState {
    fn new() -> Self {
        let lua = Lua::new();

        // Configurar package.path para src-tauri/lua y src-tauri/lua/utils
        let lua_base_dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("lua");
        let lua_base_dir_str = lua_base_dir.to_string_lossy().replace("\\", "/");

        let code = format!(
            r#"
            package.path = package.path
              .. ";{0}/?.lua"
              .. ";{0}/?/init.lua"
        "#,
            lua_base_dir_str
        );

        lua.load(&code)
            .exec()
            .expect("No se pudo configurar package.path de Lua");

        // Leer meta.json y exponer MAIN_LOGO_BASE64 en Lua
        let meta_path = Path::new(env!("CARGO_MANIFEST_DIR")).join("meta.json");

        if let Ok(meta_str) = fs::read_to_string(&meta_path) {
            if let Ok(meta_json) = serde_json::from_str::<JsonValue>(&meta_str) {
                let mut logo_b64 = String::new();

                if let Some(screens) = meta_json.get("screens").and_then(|v| v.as_array()) {
                    'outer: for screen in screens {
                        if screen.get("id").and_then(|v| v.as_str()) == Some("login") {
                            if let Some(components) =
                                screen.get("components").and_then(|v| v.as_array())
                            {
                                for comp in components {
                                    let is_main_logo = comp.get("id").and_then(|v| v.as_str())
                                        == Some("main_logo")
                                        && comp.get("type").and_then(|v| v.as_str())
                                            == Some("image");

                                    if is_main_logo {
                                        if let Some(file) =
                                            comp.get("file").and_then(|v| v.as_str())
                                        {
                                            logo_b64 = file.to_string();
                                            break 'outer;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if !logo_b64.is_empty() {
                    // Usamos un string largo de Lua [[...]] para no preocuparnos
                    // de caracteres especiales del base64.
                    let set_code = format!("MAIN_LOGO_BASE64 = [[{}]]", logo_b64);
                    if let Err(e) = lua.load(&set_code).exec() {
                        eprintln!("Error setting MAIN_LOGO_BASE64 in Lua via code: {e}");
                    }
                }
            }
        }

        LuaAppState {
            lua: Mutex::new(lua),
        }
    }
}

#[tauri::command]
fn get_view(lua_state: tauri::State<LuaAppState>) -> Result<JsonValue, String> {
    let lua = lua_state
        .lua
        .lock()
        .map_err(|_| "No se pudo bloquear la VM de Lua".to_string())?;

    let ui_rules: LuaTable = lua
        .load("return require('utils.ui_rules')")
        .eval()
        .map_err(|e| e.to_string())?;

    let init_state_fn: mlua::Function = ui_rules.get("init_state").map_err(|e| e.to_string())?;

    init_state_fn
        .call::<()>(()) // inicializa el estado global en Lua
        .map_err(|e| e.to_string())?;

    let build_view_fn: mlua::Function = ui_rules
        .get("build_current_view")
        .map_err(|e| e.to_string())?;
    let view: LuaValue = build_view_fn.call(()).map_err(|e| e.to_string())?;

    lua_value_to_json(view).map_err(|e| e.to_string())
}

#[tauri::command]
fn input_change(
    lua_state: tauri::State<LuaAppState>,
    screen_id: String,
    field_id: String,
    value: String,
) -> Result<JsonValue, String> {
    let lua = lua_state
        .lua
        .lock()
        .map_err(|_| "No se pudo bloquear la VM de Lua".to_string())?;

    let ui_rules: LuaTable = lua
        .load("return require('utils.ui_rules')")
        .eval()
        .map_err(|e| e.to_string())?;

    let on_input_change_fn: mlua::Function =
        ui_rules.get("on_input_change").map_err(|e| e.to_string())?;

    let _ret: (LuaValue, LuaValue) = on_input_change_fn
        .call((screen_id.as_str(), field_id.as_str(), value.as_str()))
        .map_err(|e| e.to_string())?;

    let build_view_fn: mlua::Function = ui_rules
        .get("build_current_view")
        .map_err(|e| e.to_string())?;
    let view: LuaValue = build_view_fn.call(()).map_err(|e| e.to_string())?;

    lua_value_to_json(view).map_err(|e| e.to_string())
}

#[tauri::command]
fn button_click(
    lua_state: tauri::State<LuaAppState>,
    screen_id: String,
    button_id: String,
) -> Result<JsonValue, String> {
    let lua = lua_state
        .lua
        .lock()
        .map_err(|_| "No se pudo bloquear la VM de Lua".to_string())?;

    let ui_rules: LuaTable = lua
        .load("return require('utils.ui_rules')")
        .eval()
        .map_err(|e| e.to_string())?;

    let on_button_click_fn: mlua::Function =
        ui_rules.get("on_button_click").map_err(|e| e.to_string())?;

    let _ret: (LuaValue, LuaValue) = on_button_click_fn
        .call((screen_id.as_str(), button_id.as_str()))
        .map_err(|e| e.to_string())?;

    let build_view_fn: mlua::Function = ui_rules
        .get("build_current_view")
        .map_err(|e| e.to_string())?;
    let view: LuaValue = build_view_fn.call(()).map_err(|e| e.to_string())?;

    lua_value_to_json(view).map_err(|e| e.to_string())
}

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let lua_state = LuaAppState::new();

    tauri::Builder::default()
        .manage(lua_state)
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            greet,
            get_view,
            input_change,
            button_click
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
