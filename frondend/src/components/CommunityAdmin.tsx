"use client";
import { useEffect, useState } from 'react';
import { Plus, RefreshCw, ImagePlus, Search, FileText, Clapperboard, Pencil, Eye, EyeOff, Trash2, Heart, MessageCircle } from 'lucide-react';
import CataloguePopup from './CataloguePopup';
import CommunityVideosAdmin from './CommunityVideosAdmin';
import CommunityArticleComments from './CommunityArticleComments';
import './catalogue-admin.css';
import './banner-admin.css';
import './community-admin.css';
type Article={id:string;title:string;summary:string;content:string;imageUrl:string;active:boolean;createdAt:string;authorName:string;hashtag:string;featured:boolean;likes:number;comments:number};
const url=(s:string)=>s.replace('/api/v1/public/','/api/public/');
async function api(path='',method='GET',body?:unknown){const response=await fetch('/api/admin/catalogue/articles'+path,{method,cache:'no-store',headers:{'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});const result=await response.json();if(!response.ok)throw new Error(result.error||'Không thể lưu bài viết.');return result.data;}
export default function CommunityAdmin(){
 const [page,setPage]=useState('posts');
 const [search,setSearch]=useState('');
 const [discussion,setDiscussion]=useState<Article|null>(null);
 const [items,setItems]=useState<Article[]>([]),[busy,setBusy]=useState(false),[error,setError]=useState('');
 const [editing,setEditing]=useState<Article|null|undefined>(),[deleting,setDeleting]=useState<Article|null>(null);
 const [title,setTitle]=useState(''),[content,setContent]=useState(''),[image,setImage]=useState(''),[reading,setReading]=useState(false);
 const [authorName,setAuthorName]=useState('TaskLy'),[hashtag,setHashtag]=useState('#TaskLyNews'),[filter,setFilter]=useState('all');
 async function load(){setBusy(true);setError('');try{setItems(await api());}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 useEffect(()=>{void load();},[]);
 function open(a:Article|null){setEditing(a);setTitle(a?.title||'');setContent(a?.content||'');setAuthorName(a?.authorName||'TaskLy');setHashtag('#'+(a?.hashtag||'TaskLyNews').replace(/^#/,''));setImage('');setError('');}
 function close(){setEditing(undefined);setError('');}
 async function read(file?:File){if(!file)return;setError('');if(!['image/png','image/jpeg'].includes(file.type)||file.size>5*1024*1024){setError('Chọn ảnh PNG/JPG tối đa 5 MB.');return;}setReading(true);try{const data=await new Promise<string>((resolve,reject)=>{const r=new FileReader();r.onload=()=>resolve(String(r.result));r.onerror=()=>reject(new Error('Không đọc được ảnh.'));r.readAsDataURL(file);});setImage(data);}catch(e){setError((e as Error).message);}finally{setReading(false);}}
 async function save(){if(!title.trim()||!content.trim()||!authorName.trim()||(!editing&&!image)){setError('Nhập người đăng, tiêu đề, nội dung và chọn ảnh bài đăng.');return;}if(!/^#[\p{L}\p{N}_]{1,60}(\s+#[\p{L}\p{N}_]{1,60})*$/u.test(hashtag.trim())){setError('Mỗi hashtag bắt đầu bằng # và cách nhau bằng khoảng trắng. Ví dụ: #TaskLyNews #hello.');return;}setBusy(true);setError('');try{const a:Article=await api(editing?'/'+editing.id:'',editing?'PATCH':'POST',{title:title.trim(),summary:"",content:content.trim(),active:true,authorName,hashtag:hashtag.trim().replace(/\s+/g," ").slice(1),featured:editing?.featured??false,...(image?{imageDataUrl:image}:{})});setItems(prev=>editing?prev.map(x=>x.id===a.id?a:x):[a,...prev]);close();}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 async function toggle(a:Article){setBusy(true);setError('');try{const saved:Article=await api('/'+a.id,'PATCH',{active:!a.active});setItems(prev=>prev.map(x=>x.id===a.id?saved:x));}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 async function remove(){if(!deleting)return;setBusy(true);try{await api('/'+deleting.id,'DELETE');setItems(prev=>prev.filter(x=>x.id!==deleting.id));setDeleting(null);}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 const visibleItems=items.filter(a=>(filter==='all'||(filter==='published'?a.active:!a.active)) && `${a.title} ${a.content} ${a.hashtag}`.toLocaleLowerCase('vi').includes(search.toLocaleLowerCase('vi')));
 const preview=image||(editing?.imageUrl?url(editing.imageUrl):'');
  const tabSwitcher = (
  <nav className="community-page-tabs" aria-label="Nội dung Cộng đồng">
   <button className={page === 'posts' ? 'selected' : ''} onClick={() => setPage('posts')}><FileText size={15}/> Bài viết</button>
   <button className={page === 'videos' ? 'selected' : ''} onClick={() => setPage('videos')}><Clapperboard size={15}/> Video ngắn</button>
  </nav>
 );
 return <section className="community-manager">
  {page === 'videos' ? <CommunityVideosAdmin tabSwitcher={tabSwitcher}/> : <>
  <div className="community-top-bar">
   {tabSwitcher}
   <div className="community-heading-actions">
    <button className="btn community-refresh" aria-label="Tải lại bài viết" title="Tải lại" disabled={busy} onClick={() => void load()}><RefreshCw size={15}/></button>
    <button className="btn btn-primary" disabled={busy} onClick={() => open(null)}><Plus size={15}/> Đăng bài viết</button>
   </div>
  </div>
  <div className="community-toolbar">
   <div className="community-filters" role="group" aria-label="Lọc bài đăng">{[['all', 'Tất cả'], ['published', 'Đã đăng'], ['hidden', 'Đang ẩn']].map(([key, label]) => <button className={filter === key ? 'selected' : ''} key={key} onClick={() => setFilter(key)}>{label}<span>{items.filter(a => key === 'all' || (key === 'published' ? a.active : !a.active)).length}</span></button>)}</div>
   <label className="community-search"><Search size={15}/><input aria-label="Tìm bài viết" placeholder="Tìm tiêu đề, nội dung, hashtag…" value={search} onChange={e => setSearch(e.target.value)}/></label>
  </div>
  {error&&editing===undefined&&<p role="alert" className="api-error">{error}</p>}
  {editing!==undefined&&<CataloguePopup title={editing?'Sửa bài viết':'Tạo bài đăng'} eyebrow="CỘNG ĐỒNG TASKLY" busy={busy||reading} onClose={close}>
   <form className="community-editor community-composer" onSubmit={e=>{e.preventDefault();void save();}}>
    <label>Tiêu đề<input required maxLength={160} value={title} onChange={e=>setTitle(e.target.value)} placeholder="Tiêu đề bài viết"/></label>
    <label>Tên người đăng<input required maxLength={100} value={authorName} onChange={e=>setAuthorName(e.target.value)} placeholder="TaskLy"/></label>
    <div className="community-fields"><label>Hashtag<input required maxLength={500} value={hashtag} onChange={e=>setHashtag(e.target.value)} placeholder="#TaskLyNews"/><small>Có thể nhập nhiều hashtag: #TaskLyNews #hello.</small></label></div>
    <label>Nội dung<textarea required maxLength={50000} rows={6} value={content} onChange={e=>setContent(e.target.value)} placeholder="Bạn muốn chia sẻ điều gì với khách hàng?"/></label>
    <label className={'banner-image-frame article-cover'+(preview?' has-image':'')}>
     {preview?<img src={preview} alt="Xem trước ảnh bìa"/>:<span className="banner-image-placeholder"><ImagePlus size={32}/><b>Chọn ảnh bìa</b><small>PNG / JPG · tối đa 5 MB</small></span>}
     <input className="banner-file-input" type="file" accept="image/png,image/jpeg" aria-label="Ảnh bìa bài viết" disabled={busy||reading} onChange={e=>{void read(e.target.files?.[0]);e.target.value='';}}/>
    </label>
    <details className="community-preview-toggle"><summary>Xem trước bài đăng</summary><div className="community-mobile-preview"><header><span className="community-avatar">{authorName.trim().slice(0,1)||'T'}</span><div><b>{authorName||'TaskLy'}</b><small>Cộng đồng TaskLy · Vừa xong</small></div><span>•••</span></header><h3>{title||'Tiêu đề bài đăng'}</h3><p>{content||'Nội dung bài đăng sẽ xuất hiện tại đây.'}</p>{hashtag&&<p className="community-tag">{hashtag}</p>}{preview&&<img src={preview} alt="Xem trước bài đăng trên app"/>}<footer>♡ &nbsp; Bình luận &nbsp; ↻ &nbsp; Chia sẻ</footer></div></details>
    {error&&<p role="alert" className="api-error">{error}</p>}
    <div className="row"><button type="button" className="btn" disabled={busy||reading} onClick={close}>Hủy</button><button className="btn btn-primary" disabled={busy||reading}>{reading?'Đang đọc ảnh…':busy?'Đang đăng…':'Đăng bài'}</button></div>
   </form>
  </CataloguePopup>}
  {deleting&&<CataloguePopup title="Xóa bài viết?" eyebrow="CỘNG ĐỒNG" compact busy={busy} onClose={()=>setDeleting(null)}><p>Bài “{deleting.title}” sẽ được gỡ khỏi Cộng đồng.</p><div className="row"><button className="btn" disabled={busy} onClick={()=>setDeleting(null)}>Hủy</button><button className="btn btn-primary" disabled={busy} onClick={()=>void remove()}>Xóa bài</button></div></CataloguePopup>}
  {discussion&&<CommunityArticleComments article={discussion} onClose={()=>{setDiscussion(null);void load();}}/>}
  <div className="community-grid" aria-busy={busy}>{visibleItems.map(a=><article className="community-item" key={a.id}><div className="community-cover"><img loading="lazy" src={url(a.imageUrl)} alt={a.title}/><span className={'community-status '+(a.active?'published':'hidden')}>{a.active?'Đã đăng':'Đang ẩn'}</span></div><div className="community-item-body"><small className="community-meta">{a.authorName} · {new Date(a.createdAt).toLocaleDateString('vi-VN')}</small><h2 title={a.title}>{a.title}</h2><p className="community-excerpt">{a.summary||a.content}</p><div className="community-tags">{a.hashtag.split(/\s+/).filter(Boolean).map((tag,i)=><span key={i}>{tag.startsWith('#')?tag:'#'+tag}</span>)}</div><div className="community-engagement"><span title="Lượt tim"><Heart size={16}/>{a.likes??0} tim</span><button type="button" onClick={()=>setDiscussion(a)}><MessageCircle size={16}/>{a.comments??0} bình luận</button></div><footer className="community-card-actions"><button className="btn" disabled={busy} onClick={()=>open(a)}><Pencil size={15}/> Sửa bài</button><div><button className="community-icon-action" title={a.active?'Ẩn bài viết':'Hiển thị bài viết'} aria-label={a.active?'Ẩn bài viết':'Hiển thị bài viết'} disabled={busy} onClick={()=>void toggle(a)}>{a.active?<EyeOff size={18}/>:<Eye size={18}/>}</button><button className="community-icon-action danger" title="Xóa bài viết" aria-label="Xóa bài viết" disabled={busy} onClick={()=>{setError('');setDeleting(a);}}><Trash2 size={17}/></button></div></footer></div></article>)}</div>
  {!busy&&!visibleItems.length&&<div className="community-empty"><FileText size={30}/><h3>{items.length?'Không tìm thấy bài viết':'Chưa có bài viết'}</h3><p>{items.length?'Thử thay đổi từ khóa hoặc bộ lọc.':'Đăng bài viết đầu tiên để bắt đầu Bảng tin TaskLy.'}</p></div>}
 </>}</section>;
}
