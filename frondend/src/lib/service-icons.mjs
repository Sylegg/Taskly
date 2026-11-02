export const serviceIconPresets = [
  { key: 'cleaning', label: 'Dọn dẹp' },
  { key: 'sparkles', label: 'Tổng vệ sinh' },
  { key: 'sofa', label: 'Sofa' },
  { key: 'bed', label: 'Nệm / giường' },
  { key: 'aircon', label: 'Máy lạnh' },
  { key: 'repair', label: 'Sửa chữa' },
  { key: 'laundry', label: 'Giặt ủi' },
  { key: 'kitchen', label: 'Nhà bếp' },
  { key: 'assembly', label: 'Lắp đặt' },
  { key: 'moving', label: 'Chuyển nhà' },
  { key: 'packing', label: 'Đóng gói' },
  { key: 'shopping', label: 'Mua sắm' },
  { key: 'pets', label: 'Thú cưng' },
  { key: 'computer', label: 'Máy tính' },
  { key: 'wifi', label: 'Wi-Fi' },
  { key: 'iron', label: 'Ủi đồ' },
  { key: 'grid', label: 'Dịch vụ chung' },
];

export const automaticIconKeys = {
  clean: 'cleaning', cleaning: 'cleaning', 'home-cleaning': 'cleaning',
  deep: 'sparkles', 'deep-cleaning': 'sparkles',
  'sofa-cleaning': 'sofa', 'mattress-cleaning': 'bed',
  move: 'moving', moving: 'moving', packing: 'packing', delivery: 'packing',
  repair: 'repair', assembly: 'assembly', 'furniture-disassembly': 'assembly',
  'washing-machine-repair': 'laundry', laundry: 'laundry', 'refrigerator-repair': 'kitchen', ironing: 'iron',
  shop: 'shopping', shopping: 'shopping', 'grocery-delivery': 'shopping',
  ac: 'aircon', aircon: 'aircon', 'air-conditioning': 'aircon', 'aircon-repair': 'repair',
  pets: 'pets', 'pet-care': 'pets', 'dog-walking': 'pets',
  it: 'computer', 'it-support': 'computer', 'wifi-setup': 'wifi',
};

export function resolveServiceIconKey(iconKey, slug) {
  return serviceIconPresets.some(preset => preset.key === iconKey) ? iconKey
    : Object.hasOwn(automaticIconKeys, slug) ? automaticIconKeys[slug] : 'grid';
}

const publicIconPath = /^\/api\/v1\/public\/service-icons\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/([0-9a-f]{64}\.png)$/i;

export function serviceIconProxyUrl(iconUrl) {
  if (typeof iconUrl !== 'string') return null;
  const match = publicIconPath.exec(iconUrl);
  return match ? `/api/public/service-icons/${match[1]}/${match[2]}` : null;
}

export function validateServiceIconFile(file) {
  if (!['image/png', 'image/jpeg'].includes(file.type)) return 'Chọn ảnh PNG hoặc JPG.';
  if (!file.size || file.size > 1024 * 1024) return 'Ảnh phải có dung lượng từ 1 byte đến 1 MB.';
  return null;
}
