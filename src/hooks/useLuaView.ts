import { useEffect, useState, useCallback } from "react";
import { invoke } from "@tauri-apps/api/core";

export function useLuaView() {
    const [view, setView] = useState<any | null>(null);
    const [loading, setLoading] = useState(true);

    const refresh = useCallback(async () => {
        setLoading(true);
        const v = await invoke("get_view");
        setView(v);
        setLoading(false);
    }, []);

    useEffect(() => {
        refresh();
    }, [refresh]);

    const onInputChange = useCallback(
        async (screenId: string, fieldId: string, value: string) => {
            const v = await invoke("input_change", { screenId, fieldId, value });
            setView(v);
        },
        []
    );

    const onButtonClick = useCallback(
        async (screenId: string, buttonId: string) => {
            const v = await invoke("button_click", { screenId, buttonId });
            setView(v);
        },
        []
    );

    return { view, loading, onInputChange, onButtonClick, refresh };
}
