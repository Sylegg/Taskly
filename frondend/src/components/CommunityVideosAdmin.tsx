'use client';
import {useEffect,useState} from 'react';
import CataloguePopup from './CataloguePopup';
import {Eye,Heart,Plus,RefreshCw,Clapperboard,EyeOff,Trash2} from 'lucide-react';
type Video={id:string;caption:string;hashtag:string;videoUrl:string;active:boolean;views:number;likes:number};
async function api(path='',method='GET',body?:BodyInit){const result=await fetch('/api/admin/community-videos'+path,{method,body,headers:method==='PATCH'?{'Content-Type':'application/json'}:{},cache:'no-store'});const json=await result.json();if(!result.ok)throw new Error(json.error?.message||json.error||'Không thể xử lý video.');return json.data;}
export default function CommunityVideosAdmin({ tabSwitcher }: { tabSwitcher?: React.ReactNode } = {}){
 const [items,setItems]=useState<Video[]>([]),[open,setOpen]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(''),[caption,setCaption]=useState(''),[hashtag,setHashtag]=useState('#TaskLyNews'),[file,setFile]=useState<File|null>(null);
 async function load(){try{setItems(await api());}catch(e){setError((e as Error).message);}}
 useEffect(()=>{void load();},[]);
 async function publish(){if(!file||!caption.trim()||!/^#[\p{L}\p{N}_]{1,60}(\s+#[\p{L}\p{N}_]{1,60})*$/u.test(hashtag.trim())){setError('Nhập nội dung, hashtag và chọn video MP4.');return;}if(file.size>100*1024*1024){setError('Video tối đa 100 MB.');return;}setBusy(true);setError('');try{const body=new FormData();body.set('caption',caption.trim());body.set('hashtag',hashtag.trim().replace(/\s+/g,' '));body.set('video',file);await api('','POST',body);setOpen(false);setCaption('');setFile(null);await load();}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 async function action(video:Video,remove=false){if(remove&&!confirm('Xóa video này?'))return;setBusy(true);try{await api('/'+video.id,remove?'DELETE':'PATCH',remove?undefined:JSON.stringify({active:!video.active}));await load();}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 return <section>
  <div className="community-top-bar">
   {tabSwitcher}
   <div className="community-heading-actions">
    <button className="btn community-refresh" disabled={busy} aria-label="Tải lại video" title="Tải lại" onClick={() => void load()}><RefreshCw size={15}/></button>
    <button className="btn btn-primary" disabled={busy} onClick={() => { setError(''); setOpen(true); }}><Plus size={15}/> Đăng video</button>
   </div>
  </div>
  <div className="community-toolbar community-video-toolbar">
   <div className="community-video-hint">
    <span>Tối đa 100 MB · MP4</span>
    <span className="dot">•</span>
    <span>Hiển thị trên Khám phá TaskLy</span>
   </div>
   <div className="community-count-badge">Tổng cộng <b>{items.length}</b> video</div>
  </div>{error&&!open&&<p role="alert" className="api-error">{error}</p>}
 {open&&<CataloguePopup title="Đăng video ngắn" eyebrow="CỘNG ĐỒNG TASKLY" busy={busy} onClose={()=>setOpen(false)}><form className="community-editor community-composer" onSubmit={e=>{e.preventDefault();void publish();}}><label>Nội dung<textarea required maxLength={2000} rows={4} value={caption} onChange={e=>setCaption(e.target.value)} placeholder="Viết chú thích cho video…"/></label><label>Hashtag<input required maxLength={500} value={hashtag} onChange={e=>setHashtag(e.target.value)}/></label><label>Video MP4<input required type="file" accept="video/mp4" onChange={e=>{const selected=e.target.files?.[0];if(!selected)return;if(selected.size>100*1024*1024){setError('Video tối đa 100 MB.');setFile(null);return;}const preview=document.createElement('video');const address=URL.createObjectURL(selected);preview.preload='metadata';preview.onloadedmetadata=()=>{URL.revokeObjectURL(address);if(!Number.isFinite(preview.duration)||preview.duration<=0){setError('Không đọc được thời lượng video.');setFile(null);}else{setError('');setFile(selected);}};preview.onerror=()=>{URL.revokeObjectURL(address);setError('Không đọc được video.');setFile(null);};preview.src=address;}}/></label>{file&&<small>Đã chọn: {file.name}</small>}{error&&<p role="alert" className="api-error">{error}</p>}<div className="row"><button type="button" className="btn" disabled={busy} onClick={()=>setOpen(false)}>Hủy</button><button className="btn btn-primary" disabled={busy||!file}>{busy?'Đang tải và đăng…':'Đăng video'}</button></div></form></CataloguePopup>}
 <div className="community-grid community-video-grid">{items.map(video=><article className="community-item" key={video.id}><div className="community-cover"><video controls preload="none" src={video.videoUrl.replace('/api/v1/public/','/api/public/')}/><span className={'community-status '+(video.active?'published':'hidden')}>{video.active?'Đã đăng':'Đang ẩn'}</span></div><div className="community-item-body"><div className="community-video-stats"><span title="Số tài khoản đã xem"><Eye size={16}/>{video.views??0} lượt xem</span><span title="Lượt thích"><Heart size={16}/>{video.likes??0} tim</span></div><p className="community-excerpt video-caption" title={video.caption}>{video.caption}</p><div className="community-tags">{video.hashtag.split(/\s+/).filter(Boolean).map((tag,i)=><span key={i}>{tag}</span>)}</div><footer className="community-card-actions"><button className="btn" disabled={busy} onClick={()=>void action(video)}>{video.active?<EyeOff size={15}/>:<Eye size={15}/>} {video.active?'Ẩn video':'Hiển thị'}</button><button className="community-icon-action danger" disabled={busy} title="Xóa video" aria-label="Xóa video" onClick={()=>void action(video,true)}><Trash2 size={17}/></button></footer></div></article>)}</div>{!items.length&&<div className="community-empty"><Clapperboard size={30}/><h3>Chưa có video</h3><p>Đăng video đầu tiên để bắt đầu Khám phá TaskLy.</p></div>}</section>;
}
