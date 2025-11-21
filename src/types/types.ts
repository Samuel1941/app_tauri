export type LayoutType = "vertical" | "horizontal";

export interface LayoutSpec {
    type: LayoutType;
    padding?: "sm" | "md" | "lg" | string;
    horizontal_alignment?: "start" | "center" | "end" | "stretch" | string;
    spacing?: "small" | "medium" | "large" | string;
    align?: "start" | "center" | "end";
}

export type ComponentType =
    | "image"
    | "text_field"
    | "button"
    | "text"
    | "spacer"
    | "table";

export interface BaseComponent {
    id: string;
    type: ComponentType;
}

export interface ImageComponent extends BaseComponent {
    type: "image";
    file?: string;
    fit_mode?: "contain" | "cover" | "fill" | string;
    size?: "sm" | "md" | "lg" | string;
}

export interface TextFieldComponent extends BaseComponent {
    type: "text_field";
    label?: string;
    placeholder?: string;
    data_model?: string;
    data_type?: "email" | "password" | "string" | string;
    required?: boolean;
    validations?: {
        min_length?: number;
        [key: string]: unknown;
    };
}

export interface ButtonOnClickAction {
    rule?: string;
    [key: string]: unknown;
}

export interface ButtonComponent extends BaseComponent {
    type: "button";
    text: string;
    icon?: string;
    style?: string;
    width?: "full" | "auto";
    on_click?: ButtonOnClickAction[];
}

export interface TextComponent extends BaseComponent {
    type: "text";
    text: string;
    text_variant?: string;
    align?: "left" | "center" | "right" | string;
}

export interface SpacerComponent extends BaseComponent {
    type: "spacer";
    height?: number;
}

export interface TableComponent extends BaseComponent {
    type: "table";
    columns?: Array<{ id: string; title: string;[key: string]: unknown }>;
    rows?: Array<Record<string, unknown>>;
}

export type ComponentSpec =
    | ImageComponent
    | TextFieldComponent
    | ButtonComponent
    | TextComponent
    | SpacerComponent
    | TableComponent
    | BaseComponent;

export interface ConditionSpec {
    field: string;
    comparator: string;
    value?: unknown;
}

export interface RuleStepValidateFields {
    type: "validate_fields";
    fields: string[];
    show_errors?: boolean;
    stop_on_error?: boolean;
}

export interface RuleStepStartOperation {
    type: "start_operation";
    operation: string;
    params?: Record<string, unknown>;
    success_event?: string;
    error_event?: string;
}

export type RuleStep = RuleStepValidateFields | RuleStepStartOperation;

export interface RuleSpec {
    id: string;
    scope?: "screen" | "global";
    screen_id?: string;
    on_event: string;
    when?: ConditionSpec[];
    steps: RuleStep[];
}

export interface ScreenSpec {
    id: string;
    title?: string;
    description?: string;
    targets?: string[];
    access_control?: {
        requires_authentication?: boolean;
        [key: string]: unknown;
    };
    lifecycle_events?: {
        on_enter?: string[];
        on_leave?: string[];
        on_resume?: string[];
        [key: string]: unknown;
    };
    data_sources?: Array<{
        id: string;
        kind: string;
        resource: string;
        [key: string]: unknown;
    }>;
    layout: LayoutSpec;
    components: ComponentSpec[];
}

export interface TransitionSpec {
    id: string;
    event: string;
    from: string;
    to: string;
    clear_stack?: boolean;
}

export type Transition = TransitionSpec;

export interface OperationalRules {
    printing?: Record<string, unknown>;
    connectivity?: Record<string, unknown>;
    access?: {
        login_screen?: string;
        unauthorized_screen?: string;
        [key: string]: unknown;
    };
    [key: string]: unknown;
}

export interface MetalanguageMeta {
    dsl_version: string;
    bundle_version?: string;
    min_engine_version?: string;
    app_name?: string;
    environment?: string;
    [key: string]: unknown;
}

export interface DeviceProfile {
    id: string;
    capabilities?: Record<string, unknown>;
    commerce?: {
        enabled_operations?: string[];
        [key: string]: unknown;
    };
    [key: string]: unknown;
}

export interface OperationSpec {
    id: string;
    group?: string;
    requires?: Record<string, unknown>;
    device_requirements?: Record<string, unknown>;
    [key: string]: unknown;
}

export interface ThemeSpec {
    id: string;
    tokens: Record<string, unknown>;
}

export interface MetalanguageRoot {
    meta: MetalanguageMeta;
    theme?: ThemeSpec;
    device_profiles?: DeviceProfile[];
    operations_catalog?: OperationSpec[];
    operational_rules?: OperationalRules;
    screens: ScreenSpec[];
    rules: RuleSpec[];
    transitions: TransitionSpec[];
}
