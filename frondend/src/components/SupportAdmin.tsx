"use client";
import {useCallback, useEffect, useRef, useState} from 'react';
import SupportRoleChat from './SupportRoleChat';
import styles from './SupportAdmin.module.css';

type Role = 'partner' | 'customer';
interface Props {
 fullPage?: boolean;
 visible?: boolean;
 onNewMessage?: () => void;
 onUnreadChange?: (count: number, name: string) => void;
 onClose?: () => void;
}

export default function SupportAdmin(props: Props) {
 const [role,setRole]=useState<Role>('partner');
 const [unread,setUnread]=useState({partner:{count:0,name:''},customer:{count:0,name:''}});
 const unreadCallback=useRef(props.onUnreadChange);
 unreadCallback.current=props.onUnreadChange;
 const partnerUnread=useCallback((count:number,name:string)=>setUnread(prev=>({...prev,partner:{count,name}})),[]);
 const customerUnread=useCallback((count:number,name:string)=>setUnread(prev=>({...prev,customer:{count,name}})),[]);
 useEffect(()=>{unreadCallback.current?.(unread.partner.count+unread.customer.count,unread.partner.count?unread.partner.name:unread.customer.name);},[unread]);
 return <div style={{display:'flex',flexDirection:'column',height:'100%',minHeight:0}}>
  <div className={styles.tabContainer}>
   <div className={styles.tabsSegmented} role="tablist" aria-label="Hộp thư CSKH theo role">
    <button role="tab" id="support-partner-tab" aria-controls="support-partner-panel" aria-selected={role==='partner'} className={`${styles.tabBtn} ${role==='partner'?styles.activePartner:''}`} onClick={()=>setRole('partner')}>Partner • Đối tác {unread.partner.count>0&&<span className={styles.tabBadge}>{unread.partner.count}</span>}</button>
    <button role="tab" id="support-customer-tab" aria-controls="support-customer-panel" aria-selected={role==='customer'} className={`${styles.tabBtn} ${role==='customer'?styles.activeCustomer:''}`} onClick={()=>setRole('customer')}>Customer • Khách hàng {unread.customer.count>0&&<span className={styles.tabBadge}>{unread.customer.count}</span>}</button>
   </div>
  </div>
  <div role="tabpanel" id="support-partner-panel" aria-labelledby="support-partner-tab" hidden={role!=='partner'} style={{flex:1,minHeight:0}}>
   <SupportRoleChat role="partner" {...props} visible={props.visible!==false&&role==='partner'} onUnreadChange={partnerUnread}/>
  </div>
  <div role="tabpanel" id="support-customer-panel" aria-labelledby="support-customer-tab" hidden={role!=='customer'} style={{flex:1,minHeight:0}}>
   <SupportRoleChat role="customer" {...props} visible={props.visible!==false&&role==='customer'} onUnreadChange={customerUnread}/>
  </div>
 </div>;
}
