export type AdminPortal = 'customer' | 'partner';
export type NavigationGroup = [string, [string, string, string][]];
const partnerOnly = new Set(['partners', 'daily-milestones', 'recruitment', 'recruitment-areas', 'recruitment-applications', 'recruitment-exam', 'recruitment-uniforms', 'payouts', 'availability']);
const customerOnly = new Set(['customers', 'services', 'categories', 'refunds', 'community', 'banners', 'vouchers', 'rewards', 'campaigns']);

export function portalForRoute(route: string): AdminPortal | null {
  return partnerOnly.has(route) ? 'partner' : customerOnly.has(route) ? 'customer' : null;
}

export function navigationForPortal(groups: NavigationGroup[], portal: AdminPortal): NavigationGroup[] {
  return groups.map(([heading, items]): NavigationGroup => [heading, items.filter(([route]) => {
    const owner = portalForRoute(route);
    return owner === null || owner === portal;
  })]).filter(([, items]) => items.length > 0);
}
