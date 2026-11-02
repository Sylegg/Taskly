'use client';
import { useEffect, useState } from 'react';
import { Plus, RefreshCw, ImagePlus } from 'lucide-react';
import CataloguePopup from './CataloguePopup';
import './catalogue-admin.css';
import './banner-admin.css';
type Banner = { id: string; imageUrl: string; active: boolean };
async function api(path = '', method = 'GET', body?: unknown) {
 const response = await fetch('/api/admin/catalogue/banners' + path, { method, cache: 'no-store', headers: { 'Content-Type': 'application/json' }, ...(body ? { body: JSON.stringify(body) } : {}) });
 const result = await response.json(); if (!response.ok) throw new Error(result.error || 'Không thể lưu banner.'); return result.data;
}
const imageUrl = (url: string) => url.replace('/api/v1/public/', '/api/public/');
export default function BannerAdmin() {
 const [items,setItems]=useState<Banner[]>([]), [error,setError]=useState(''), [busy,setBusy]=useState(false);
 const [editing,setEditing]=useState<Banner|null|undefined>(undefined), [deleting,setDeleting]=useState<Banner|null>(null);
 const [image,setImage]=useState(''), [reading,setReading]=useState(false);
 async function load(){setBusy(true);setError('');try{setItems(await api());}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 useEffect(()=>{void load();},[]);
 function open(item: Banner|null){setEditing(item);setImage('');setError('');}
 function close(){setEditing(undefined);setError('');setImage('');}
 async function read(file?: File){if(!file)return;setError('');if(!file.size||!['image/png','image/jpeg'].includes(file.type)||file.size>5*1024*1024){setError('Chọn ảnh PNG/JPG không quá 5 MB.');return;}
 setReading(true);try{const data=await new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result));reader.onerror=()=>reject(new Error('Không đọc được ảnh.'));reader.readAsDataURL(file);});setImage(data);}catch(e){setError((e as Error).message);}finally{setReading(false);}}
 async function save(){if(!image){setError('Vui lòng chọn ảnh banner.');return;}setBusy(true);setError('');try{const saved:Banner=await api(editing?'/'+editing.id:'',editing?'PATCH':'POST',{imageDataUrl:image});setItems(previous=>editing?previous.map(b=>b.id===saved.id?saved:b):[...previous,saved]);close();}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 async function toggle(item:Banner){setBusy(true);setError('');try{const saved=await api('/'+item.id,'PATCH',{active:!item.active});setItems(previous=>previous.map(b=>b.id===item.id?saved:b));}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 async function remove(){if(!deleting)return;setBusy(true);setError('');try{await api('/'+deleting.id,'DELETE');setItems(previous=>previous.filter(b=>b.id!==deleting.id));setDeleting(null);}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 const preview=image||(editing?.imageUrl?imageUrl(editing.imageUrl):'');
 return <section className="banner-manager">
  <p>Ảnh thêm trước hiển thị trước trên Customer. Nên dùng ảnh ngang tỷ lệ 3:1, PNG/JPG tối đa 5 MB, mỗi chiều tối đa 4096 px.</p>
  <div className="row"><button className="btn btn-primary" disabled={busy||reading} onClick={()=>open(null)}><Plus size={16}/> Thêm banner</button><button className="btn" disabled={busy||reading} onClick={()=>void load()}><RefreshCw size={16}/> Tải lại</button></div>
  {error&&editing===undefined&&!deleting&&<p role="alert" className="api-error">{error}</p>}
  {editing!==undefined&&<CataloguePopup title={editing?'Thay ảnh banner':'Thêm banner'} eyebrow="QUẢN LÝ BANNER" busy={busy||reading} onClose={close}>
   <form className="banner-editor" onSubmit={e=>{e.preventDefault();void save();}}>
    <label className={'banner-image-frame'+(preview?' has-image':'')}>
     {preview?<img src={preview} alt="Xem trước ảnh banner"/>:<span className="banner-image-placeholder"><ImagePlus size={32}/><b>Chọn ảnh banner</b><small>Nhấn để tải ảnh PNG / JPG</small></span>}
     {preview&&<span className="banner-image-change"><ImagePlus size={16}/> Chọn ảnh khác</span>}
     <input className="banner-file-input" type="file" accept="image/png,image/jpeg" aria-label="Chọn ảnh banner" disabled={reading||busy} onChange={e=>{void read(e.target.files?.[0]);e.target.value='';}}/>
    </label>
    <p className="banner-image-help">Khung xem trước tỷ lệ 3:1 • Tối đa 5 MB • Mỗi chiều tối đa 4096 px</p>
    {reading&&<p role="status">Đang đọc ảnh…</p>}
    {error&&<p role="alert" className="api-error">{error}</p>}
    <div className="row banner-editor-actions"><button className="btn btn-outline" type="button" disabled={busy||reading} onClick={close}>Hủy</button><button className="btn btn-primary" disabled={busy||reading||!image}>{busy?'Đang lưu…':'Lưu ảnh'}</button></div>
   </form>
  </CataloguePopup>}
  {deleting&&<CataloguePopup title="Xóa banner?" eyebrow="QUẢN LÝ BANNER" compact busy={busy} onClose={()=>{setDeleting(null);setError('');}}>
   <div className="banner-editor"><img className="banner-delete-preview" src={imageUrl(deleting.imageUrl)} alt="Banner cần xóa"/><p>Ảnh sẽ được gỡ khỏi app Customer.</p>{error&&<p role="alert" className="api-error">{error}</p>}<div className="row banner-editor-actions"><button className="btn btn-outline" disabled={busy} onClick={()=>setDeleting(null)}>Hủy</button><button className="btn btn-primary" disabled={busy} onClick={()=>void remove()}>Xóa banner</button></div></div>
  </CataloguePopup>}
  <div className="banner-grid">{items.map((item,index)=><article className="banner-item" key={item.id}>
   <img src={imageUrl(item.imageUrl)} alt={'Ảnh banner '+(index+1)}/>
   <div className="row"><button className="btn" disabled={busy||reading} aria-pressed={item.active} onClick={()=>void toggle(item)}>{item.active?'Đang hiển thị':'Đang ẩn'}</button><button className="btn" disabled={busy||reading} onClick={()=>open(item)}>Thay ảnh</button><button className="btn" disabled={busy||reading} onClick={()=>{setError('');setDeleting(item);}}>Xóa</button></div>
  </article>)}</div>
  {!busy&&!items.length&&<p>Chưa có banner. Thêm ảnh để hiển thị trên Customer.</p>}
 </section>;
}
