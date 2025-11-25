// src/App.tsx
import { useMemo, useState, CSSProperties } from "react";
import "./App.css";
import rawMeta from "./version_v1.0.10/bundle.json";
import {
  ButtonComponent,
  ComponentSpec,
  ImageComponent,
  MetalanguageRoot,
  RuleSpec,
  ScreenSpec,
  SpacerComponent,
  TextComponent,
  TextFieldComponent,
  Transition,
  RuleStepValidateFields,
  ConditionSpec,
} from "./types/types";

type ValuesMap = Record<string, string>;
type ErrorsMap = Record<string, string>;

const meta = rawMeta as unknown as MetalanguageRoot;
const screens: ScreenSpec[] = meta.screens;
const transitions: Transition[] = meta.transitions;
const rules: RuleSpec[] = meta.rules;

const initialScreenId: string =
  meta.operational_rules?.access?.login_screen ?? screens[0]?.id ?? "";

function findScreen(screenId: string): ScreenSpec {
  const screen = screens.find((s) => s.id === screenId);
  if (!screen) {
    throw new Error(`Screen no encontrada: ${screenId}`);
  }
  return screen;
}

const imageBase64Modules = import.meta.glob(
  "./version_v1.0.10/images_base64/*.b64.txt",
  {
    as: "raw",
    eager: true,
  }
) as Record<string, string>;

function validateField(
  component: TextFieldComponent,
  value: string
): string | null {
  if (component.required && (!value || value.trim() === "")) {
    return "Este campo es requerido";
  }

  const minLen = component.validations?.min_length;
  if (typeof minLen === "number" && value && value.length < minLen) {
    return `Debe tener al menos ${minLen} caracteres`;
  }

  if (component.data_type === "email" && value) {
    const emailRegex = /\S+@\S+\.\S+/;
    if (!emailRegex.test(value)) {
      return "Correo electrónico inválido";
    }
  }

  if (component.data_type === "password" && value && value.length < 8) {
    return "La contraseña debe tener al menos 8 caracteres";
  }

  return null;
}

function evaluateCondition(cond: ConditionSpec, values: ValuesMap): boolean {
  const current = values[cond.field] ?? "";

  switch (cond.comparator) {
    case "is_not_empty":
      return current.trim().length > 0;
    case "is_empty":
      return current.trim().length === 0;
    default:
      console.warn("Comparator no soportado:", cond.comparator);
      return true;
  }
}

function runValidateFieldsStep(
  step: RuleStepValidateFields,
  screen: ScreenSpec,
  values: ValuesMap,
  errors: ErrorsMap
): { hasErrors: boolean; newErrors: ErrorsMap } {
  const newErrors: ErrorsMap = { ...errors };
  let hasErrors = false;

  for (const fieldModel of step.fields) {
    const comp = screen.components.find(
      (c) =>
        c.type === "text_field" &&
        (c as TextFieldComponent).data_model === fieldModel
    ) as TextFieldComponent | undefined;

    if (!comp) {
      console.warn(
        "No se encontró componente para el modelo de datos:",
        fieldModel
      );
      continue;
    }

    const value = values[fieldModel] ?? "";
    const errorMsg = validateField(comp, value);

    if (errorMsg) {
      newErrors[fieldModel] = errorMsg;
      hasErrors = true;
    } else {
      delete newErrors[fieldModel];
    }
  }

  return { hasErrors, newErrors };
}

function findRulesForEvent(screenId: string, eventName: string): RuleSpec[] {
  return rules.filter((rule) => {
    const scopeOk =
      !rule.scope ||
      rule.scope === "global" ||
      (rule.scope === "screen" && rule.screen_id === screenId);

    return scopeOk && rule.on_event === eventName;
  });
}

function interpolateText(template: string, values: ValuesMap): string {
  return template.replace(/{{\s*([^}]+)\s*}}/g, (_, expr) => {
    const key = (expr as string).trim();
    const val = values[key];
    return val !== undefined && val !== null ? String(val) : "";
  });
}

function getImageSrc(img: ImageComponent): string {
  const file = img.file;
  if (!file) return "";

  if (file.startsWith("data:")) {
    return file;
  }

  if (file.endsWith(".b64.txt")) {
    const candidates = [
      `./version_v1.0.10/${file}`,
      `./version_v1.0.10/images_base64/${file}`,
    ];

    for (const key of candidates) {
      const content = imageBase64Modules[key];
      if (content) {
        return `data:image/png;base64,${content.trim()}`;
      }
    }

    console.warn("[getImageSrc] No se encontró el archivo base64 para", file);
    return "";
  }

  return `data:image/png;base64,${file}`;
}

function App() {
  const [currentScreenId, setCurrentScreenId] =
    useState<string>(initialScreenId);
  const [values, setValues] = useState<ValuesMap>({});
  const [errors, setErrors] = useState<ErrorsMap>({});

  const currentScreen = useMemo(
    () => findScreen(currentScreenId),
    [currentScreenId]
  );

  const handleInputChange = (component: TextFieldComponent, value: string) => {
    const modelKey = component.data_model ?? component.id;

    setValues((prev) => ({
      ...prev,
      [modelKey]: value,
    }));

    const errorMsg = validateField(component, value);
    setErrors((prev) => {
      const next: ErrorsMap = { ...prev };
      if (errorMsg) {
        next[modelKey] = errorMsg;
      } else {
        delete next[modelKey];
      }
      return next;
    });
  };

  const handleButtonClick = (component: ButtonComponent) => {
    const eventName = `${component.id}.click`;
    const relatedRules = findRulesForEvent(currentScreen.id, eventName);

    if (relatedRules.length === 0) {
      console.warn("No hay reglas para el evento:", eventName);
      return;
    }

    let workingErrors: ErrorsMap = { ...errors };
    let workingValues: ValuesMap = { ...values };
    let shouldStop = false;

    const navigateByEvent = (flowEvent: string) => {
      const tr = transitions.find(
        (t) => t.event === flowEvent && t.from === currentScreen.id
      );
      if (tr) {
        setCurrentScreenId(tr.to);
        workingErrors = {};
      } else {
        console.warn("No se encontró transición para el evento:", flowEvent);
      }
    };

    for (const rule of relatedRules) {
      if (rule.when && rule.when.length > 0) {
        const allOk = rule.when.every((cond) =>
          evaluateCondition(cond, workingValues)
        );
        if (!allOk) {
          continue;
        }
      }

      for (const step of rule.steps || []) {
        if (step.type === "validate_fields") {
          const result = runValidateFieldsStep(
            step,
            currentScreen,
            workingValues,
            workingErrors
          );
          workingErrors = result.newErrors;

          if (result.hasErrors && step.stop_on_error) {
            shouldStop = true;
            break;
          }
        } else if (step.type === "start_operation") {
          if (step.success_event) {
            navigateByEvent(step.success_event);
          }
        } else {
          console.warn("Tipo de step no soportado:", (step as any).type);
        }
      }

      if (shouldStop) {
        break;
      }
    }

    setErrors(workingErrors);
  };

  const renderComponent = (component: ComponentSpec) => {
    switch (component.type) {
      case "image": {
        const img = component as ImageComponent;
        return (
          <div
            style={{
              textAlign: "center",
              marginBottom: "1rem",
            }}
          >
            <img
              src={getImageSrc(img)}
              alt={img.id}
              style={{
                maxWidth: img.size === "md" ? "150px" : "100%",
                objectFit:
                  (img.fit_mode as CSSProperties["objectFit"]) ?? "contain",
              }}
            />
          </div>
        );
      }

      case "text_field": {
        const input = component as TextFieldComponent;
        const modelKey = input.data_model ?? input.id;
        const value = values[modelKey] ?? "";
        const isPassword = input.data_type === "password";

        return (
          <div style={{ marginBottom: "0.75rem", width: "100%" }}>
            {input.label && (
              <label
                htmlFor={input.id}
                style={{ display: "block", marginBottom: "0.25rem" }}
              >
                {input.label}
              </label>
            )}
            <input
              id={input.id}
              type={isPassword ? "password" : "text"}
              placeholder={input.placeholder}
              value={value}
              onChange={(e) => handleInputChange(input, e.target.value)}
              style={{
                width: "100%",
                padding: "0.5rem 0.75rem",
                borderRadius: 8,
                border: "1px solid #ccc",
                boxSizing: "border-box",
              }}
            />
            {errors[modelKey] && (
              <p
                style={{
                  color: "#ff4d4f",
                  fontSize: "0.8rem",
                  marginTop: "0.25rem",
                }}
              >
                {errors[modelKey]}
              </p>
            )}
          </div>
        );
      }

      case "button": {
        const btn = component as ButtonComponent;
        return (
          <button
            type="button"
            onClick={() => handleButtonClick(btn)}
            style={{
              width: btn.width === "full" ? "100%" : "auto",
              padding: "0.5rem 1rem",
              borderRadius: 8,
              border: "none",
              cursor: "pointer",
              marginTop: "0.5rem",
              background:
                btn.style === "primary"
                  ? "#2563EB"
                  : btn.style === "secondary"
                  ? "#6B7280"
                  : "transparent",
              color: btn.style === "text" ? "#2563EB" : "#fff",
            }}
          >
            {btn.text}
          </button>
        );
      }

      case "text": {
        const txt = component as TextComponent;
        const fontSize =
          txt.text_variant === "title_large"
            ? 20
            : txt.text_variant === "body_small"
            ? 12
            : 14;

        const renderedText = interpolateText(txt.text, values);

        return (
          <p
            style={{
              textAlign: (txt.align as CSSProperties["textAlign"]) ?? "left",
              fontSize,
              marginBottom: "0.5rem",
              color: "#111827",
            }}
          >
            {renderedText}
          </p>
        );
      }

      case "spacer": {
        const sp = component as SpacerComponent;
        return <div style={{ height: sp.height ?? 8 }} />;
      }

      default:
        return (
          <pre style={{ fontSize: 10, color: "#f97316" }}>
            Componente no soportado: {component.type}
          </pre>
        );
    }
  };

  return (
    <main
      style={{
        minHeight: "100vh",
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        background: "#F3F4F6",
        padding: "1rem",
      }}
    >
      <div
        style={{
          width: 380,
          maxWidth: "100%",
          background: "#1F2937",
          borderRadius: 16,
          padding: "1.5rem",
          color: "#fff",
          boxShadow: "0 10px 30px rgba(0,0,0,0.25)",
        }}
      >
        <h1 style={{ textAlign: "center", marginBottom: "1rem" }}>
          {currentScreen.title}
        </h1>

        <div
          style={{
            display: "flex",
            flexDirection:
              currentScreen.layout.type === "vertical" ? "column" : "row",
            gap: "1rem",
            width: "100%",
            maxWidth: 320,
            margin: "0 auto",
            alignItems: "stretch",
          }}
        >
          {currentScreen.components.map((c) => (
            <div key={c.id} style={{ width: "100%" }}>
              {renderComponent(c)}
            </div>
          ))}
        </div>
      </div>
    </main>
  );
}

export default App;
