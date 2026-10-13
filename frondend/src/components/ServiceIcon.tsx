'use client';

import { useState } from 'react';
import { resolveServiceIconKey, serviceIconProxyUrl } from '@/lib/service-icons.mjs';

export default function ServiceIcon({ iconKey, iconUrl, slug = '', previewUrl, size = 24 }: {
  iconKey?: string | null; iconUrl?: string | null; slug?: string; previewUrl?: string | null; size?: number;
}) {
  const [failedSource, setFailedSource] = useState<string | null>(null);
  const source = previewUrl || serviceIconProxyUrl(iconUrl);
  const preset = resolveServiceIconKey(iconKey, slug);
  return source && source !== failedSource
    ? <img className="catalogue-custom-icon" src={source} alt="" width={size} height={size} onError={() => setFailedSource(source)}/>
    : <img className="catalogue-custom-icon" src={'/service-icons/' + preset + '.png'} alt="" width={size} height={size}/>;
}
