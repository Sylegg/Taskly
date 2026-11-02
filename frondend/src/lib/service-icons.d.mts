export const serviceIconPresets: { key: string; label: string }[];
export function resolveServiceIconKey(iconKey: string | null | undefined, slug: string): string;
export function serviceIconProxyUrl(iconUrl: string | null | undefined): string | null;
export function validateServiceIconFile(file: { type: string; size: number }): string | null;
