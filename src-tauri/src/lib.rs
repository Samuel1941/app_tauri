use mlua::{Lua, Table as LuaTable, Value as LuaValue};
use serde_json::{Map as JsonMap, Number, Value as JsonValue};
use std::path::Path;
use std::sync::Mutex;

fn lua_value_to_json(value: LuaValue) -> Result<JsonValue, mlua::Error> {
    Ok(match value {
        LuaValue::Nil => JsonValue::Null,
        LuaValue::Boolean(b) => JsonValue::Bool(b),
        LuaValue::Integer(i) => JsonValue::Number(i.into()),
        LuaValue::Number(n) => {
            let num = Number::from_f64(n).unwrap_or_else(|| Number::from_f64(0.0).unwrap());
            JsonValue::Number(num)
        }
        LuaValue::String(s) => JsonValue::String(s.to_str()?.to_string()),
        LuaValue::Table(t) => {
            let mut is_array = true;
            let mut max_index = 0i64;
            let mut arr_elems: Vec<(i64, LuaValue)> = Vec::new();
            let mut obj_map: JsonMap<String, JsonValue> = JsonMap::new();

            for pair in t.pairs::<LuaValue, LuaValue>() {
                let (k, v) = pair?;
                match k {
                    LuaValue::Integer(i) => {
                        if i > max_index {
                            max_index = i;
                        }
                        arr_elems.push((i, v));
                    }
                    LuaValue::String(s) => {
                        is_array = false;
                        let key_str = s.to_str()?.to_string();
                        obj_map.insert(key_str, lua_value_to_json(v)?);
                    }
                    other_key => {
                        is_array = false;
                        let key_str = format!("{:?}", other_key);
                        obj_map.insert(key_str, lua_value_to_json(v)?);
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

fn json_to_lua(lua: &Lua, value: &JsonValue) -> Result<LuaValue, mlua::Error> {
    Ok(match value {
        JsonValue::Null => LuaValue::Nil,
        JsonValue::Bool(b) => LuaValue::Boolean(*b),
        JsonValue::Number(n) => {
            if let Some(i) = n.as_i64() {
                LuaValue::Integer(i)
            } else {
                let f = n.as_f64().unwrap_or(0.0);
                LuaValue::Number(f)
            }
        }
        JsonValue::String(s) => LuaValue::String(lua.create_string(s)?),
        JsonValue::Array(arr) => {
            let table = lua.create_table()?;
            for (idx, item) in arr.iter().enumerate() {
                let v = json_to_lua(lua, item)?;
                table.set((idx + 1) as i64, v)?;
            }
            LuaValue::Table(table)
        }
        JsonValue::Object(map) => {
            let table = lua.create_table()?;
            for (k, v) in map.iter() {
                let v = json_to_lua(lua, v)?;
                table.set(k.as_str(), v)?;
            }
            LuaValue::Table(table)
        }
    })
}

struct LuaAppState {
    lua: Mutex<Lua>,
}

impl LuaAppState {
    fn new() -> Self {
        let lua = Lua::new();

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

        let meta_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap_or_else(|| Path::new(".."))
            .join("src")
            .join("meta.json");

        match std::fs::read_to_string(&meta_path) {
            Ok(meta_str) => match serde_json::from_str::<JsonValue>(&meta_str) {
                Ok(meta_json) => match json_to_lua(&lua, &meta_json) {
                    Ok(lua_meta) => {
                        if let Err(e) = lua.globals().set("META", lua_meta) {
                            eprintln!("Error exponiendo META a Lua: {e}");
                        }
                    }
                    Err(e) => {
                        eprintln!("Error convirtiendo meta.json a Lua: {e}");
                    }
                },
                Err(e) => {
                    eprintln!(
                        "Error parseando meta.json ({}): {e}",
                        meta_path.to_string_lossy()
                    );
                }
            },
            Err(e) => {
                eprintln!(
                    "No se pudo leer meta.json en {}: {e}",
                    meta_path.to_string_lossy()
                );
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

    let _state: LuaValue = on_input_change_fn
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

    let _state: LuaValue = on_button_click_fn
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
    format!("Hello, {}!", name)
}

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
