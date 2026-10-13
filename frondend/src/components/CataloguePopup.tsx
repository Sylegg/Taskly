'use client';

import { useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';

export default function CataloguePopup({ title, children, onClose, busy = false, compact = false, drawer = false, wide = false, eyebrow = 'QUẢN LÝ DỊCH VỤ' }: {
  title: string; children: React.ReactNode; onClose: () => void; busy?: boolean; compact?: boolean; drawer?: boolean; wide?: boolean; eyebrow?: string;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const dialog = ref.current;
    const previous = document.activeElement as HTMLElement | null;
    dialog?.showModal();
    const overflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => { dialog?.close(); document.body.style.overflow = overflow; previous?.focus(); };
  }, []);
  return createPortal(<dialog ref={ref} className={'catalogue-admin catalogue-native ' + (compact ? 'catalogue-compact' : '') + (drawer ? ' catalogue-drawer' : '') + (wide ? ' catalogue-wide' : '')}
    aria-label={title} onCancel={event => { event.preventDefault(); if (!busy) onClose(); }}
    onClick={event => { if (event.target === ref.current && !busy) { const bounds = ref.current!.getBoundingClientRect(); if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) onClose(); } }}>
    <header className="catalogue-popup-header"><div><small>{eyebrow}</small><h2>{title}</h2></div><button type="button" className="catalogue-icon-button" aria-label="Đóng popup" disabled={busy} onClick={onClose}><X size={20}/></button></header>
    <div className="catalogue-popup-body">{children}</div>
  </dialog>, document.body);
}
