'use client';

import { useState } from 'react';
import { resolveServiceIconKey } from '@/lib/service-icons.mjs';

export default function CategoryIcon({ iconKey, iconUrl, slug = '', previewUrl, size = 24 }: {
  iconKey?: string | null; iconUrl?: string | null; slug?: string; previewUrl?: string | null; size?: number;
}) {
  const [failedSource, setFailedSource] = useState<string | null>(null);
  const source = previewUrl || (iconUrl?.match(/^\/api\/v1\/public\/category-icons\/([0-9a-f-]{36})\/([0-9a-f]{64}\.png)$/i) ? iconUrl.replace('/api/v1/public/', '/api/public/') : null);
  const preset = resolveServiceIconKey(iconKey, slug);
  return source && source !== failedSource
    ? <img className="catalogue-custom-icon" src={source} alt="" width={size} height={size} onError={() => setFailedSource(source)}/>
    : <img className="catalogue-custom-icon" src={'/category-icons/' + preset + '.png'} alt="" width={size} height={size}/>;
}
