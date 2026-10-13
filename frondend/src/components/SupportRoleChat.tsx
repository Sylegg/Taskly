"use client";

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import {
  ChevronLeft,
  Maximize2,
  MessageCircle,
  MessageSquare,
  RefreshCw,
  Search,
  Send,
  X
} from 'lucide-react';
import styles from './SupportAdmin.module.css';

type Row = {
  user_id: string;
  task_id?: string;
  full_name?: string;
  avatar?: string;
  sender?: string;
  content?: string;
  image_data?: string;
  id?: string;
  created_at?: string;
  updated_at?: string;
  unread_count?: number;
  last_incoming_at?: string;
};

type Role = 'partner' | 'customer';

interface SupportAdminProps {
  fullPage?: boolean;
  visible?: boolean;
  onNewMessage?: () => void;
  onUnreadChange?: (count: number, name: string) => void;
  onClose?: () => void;
}

function formatTimestamp(isoString?: string): string {
  if (!isoString) return '';
  try {
    const d = new Date(isoString);
    if (isNaN(d.getTime())) return '';
    const now = new Date();
    const isToday = d.toDateString() === now.toDateString();
    const timeStr = d.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', hour12: false });
    if (isToday) return timeStr;
    const dateStr = d.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit' });
    return `${dateStr} ${timeStr}`;
  } catch {
    return '';
  }
}

function Avatar({
  person,
  role,
  small = false
}: {
  person: Row;
  role: Role;
  small?: boolean;
}) {
  const [failed, setFailed] = useState(false);
  const name = person.full_name?.trim() || '';
  const initial = name ? name.slice(0, 1).toUpperCase() : (role === 'partner' ? 'Đ' : 'K');
  const isPartner = role === 'partner';

  return (
    <span
      className={`${styles.avatar} ${small ? styles.avatarSmall : ''} ${
        isPartner ? styles.partnerAvatar : styles.customerAvatar
      }`}
    >
      {person.avatar && !failed ? (
        <img
          src={person.avatar}
          alt={person.full_name || (isPartner ? 'Đối tác' : 'Khách hàng')}
          onError={() => setFailed(true)}
        />
      ) : (
        <span>{initial}</span>
      )}
    </span>
  );
}

export default function SupportRoleChat({
  role,
  fullPage = false,
  visible = true,
  onNewMessage,
  onUnreadChange,
  onClose
}: SupportAdminProps & {role: Role}) {
  const activeRole = role;
  const [partnerQueue, setPartnerQueue] = useState<Row[]>([]);
  const [customerQueue, setCustomerQueue] = useState<Row[]>([]);
  const [selectedPerson, setSelectedPerson] = useState<Row | null>(null);
  const [messages, setMessages] = useState<Row[]>([]);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [searchQuery, setSearchQuery] = useState('');
  const [refreshing, setRefreshing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [photo, setPhoto] = useState<string | null>(null);

  const messageListRef = useRef<HTMLDivElement>(null);
  const followLatestRef = useRef(true);
  const activeUserIdRef = useRef('');
  const retryRef = useRef<{ user: string; text: string; id: string } | null>(null);

  const previousPartnerIncoming = useRef<Record<string, string> | null>(null);
  const previousCustomerIncoming = useRef<Record<string, string> | null>(null);

  const visibleRef = useRef(visible);
  visibleRef.current = visible;
  const notifyRef = useRef(onNewMessage);
  notifyRef.current = onNewMessage;
  const unreadRef = useRef(onUnreadChange);
  unreadRef.current = onUnreadChange;

  // Generic backend support API caller
  const api = useCallback(async (role: Role, path: string, body?: unknown) => {
    const url = '/api/admin/support/' + (role === 'customer' ? 'customer/' : '') + path;
    const r = await fetch(url, {
      method: body ? 'POST' : 'GET',
      cache: 'no-store',
      headers: { 'Content-Type': 'application/json' },
      ...(body ? { body: JSON.stringify(body) } : {})
    });
    const data = await r.json();
    if (!r.ok) {
      throw new Error(
        typeof data.error === 'string'
          ? data.error
          : data.error?.message || 'Không thể kết nối hỗ trợ'
      );
    }
    return data.data;
  }, []);

  // Refresh both partner and customer conversations
  const refreshAll = useCallback(async () => {
    try {
      setRefreshing(true);
      const [pRows, cRows] = await Promise.all([
        activeRole === 'partner' ? api('partner', 'conversations') : Promise.resolve([] as Row[]),
        activeRole === 'customer' ? api('customer', 'conversations') : Promise.resolve([] as Row[])
      ]);

      const pList: Row[] = Array.isArray(pRows) ? pRows : [];
      const cList: Row[] = Array.isArray(cRows) ? cRows : [];

      setPartnerQueue(pList);
      setCustomerQueue(cList);

      const pUnread = pList.reduce((sum, p) => sum + Number(p.unread_count || 0), 0);
      const cUnread = cList.reduce((sum, p) => sum + Number(p.unread_count || 0), 0);
      const totalUnread = pUnread + cUnread;

      const firstUnread =
        pList.find(p => Number(p.unread_count) > 0) ||
        cList.find(p => Number(p.unread_count) > 0);
      unreadRef.current?.(
        totalUnread,
        firstUnread?.full_name || (firstUnread ? 'Người dùng mới' : 'Người dùng')
      );

      const pNext = Object.fromEntries(pList.map(p => [p.user_id, p.last_incoming_at || '']));
      const cNext = Object.fromEntries(cList.map(p => [p.user_id, p.last_incoming_at || '']));

      const hasNewP =
        previousPartnerIncoming.current &&
        pList.some(
          p =>
            p.last_incoming_at &&
            previousPartnerIncoming.current![p.user_id] !== p.last_incoming_at &&
            Number(p.unread_count) > 0
        );

      const hasNewC =
        previousCustomerIncoming.current &&
        cList.some(
          p =>
            p.last_incoming_at &&
            previousCustomerIncoming.current![p.user_id] !== p.last_incoming_at &&
            Number(p.unread_count) > 0
        );

      if (hasNewP || hasNewC) {
        notifyRef.current?.();
      }

      previousPartnerIncoming.current = pNext;
      previousCustomerIncoming.current = cNext;
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Không thể tải hội thoại');
    } finally {
      setRefreshing(false);
    }
  }, [api, activeRole]);

  // Initial fetch and periodic polling of conversations
  useEffect(() => {
    void refreshAll();
    const timer = setInterval(() => {
      void refreshAll();
    }, 8000);
    return () => clearInterval(timer);
  }, [refreshAll]);

  // Load messages for currently selected person
  const loadMessages = useCallback(async () => {
    if (!selectedPerson) return;
    const userId = selectedPerson.user_id;
    try {
      const data: Row[] = await api(activeRole, userId + '/messages');
      if (activeUserIdRef.current === userId) {
        setMessages(Array.isArray(data) ? data : []);
        setMessagesLoading(false);
        setError('');

        if (visibleRef.current && typeof document !== 'undefined' && document.visibilityState === 'visible') {
          const userMessageIds = (Array.isArray(data) ? data : [])
            .filter(m => m.sender === 'USER' && m.id)
            .map(m => m.id as string);

          if (userMessageIds.length > 0) {
            void api(activeRole, userId + '/read', { messageIds: userMessageIds.slice(-1000) })
              .then(refreshAll)
              .catch(() => {});
          }
        }
      }
    } catch (e) {
      if (activeUserIdRef.current === userId) {
        setError(e instanceof Error ? e.message : 'Không thể tải tin nhắn');
        setMessagesLoading(false);
      }
    }
  }, [selectedPerson, activeRole, api, refreshAll]);

  // When selectedPerson changes, reset messages and load
  useEffect(() => {
    activeUserIdRef.current = selectedPerson?.user_id || '';
    followLatestRef.current = true;
    setMessages([]);
    setError('');

    if (!selectedPerson) return;

    setMessagesLoading(true);
    void loadMessages();

    const interval = setInterval(() => {
      void loadMessages();
    }, 4000);

    return () => clearInterval(interval);
  }, [selectedPerson?.user_id, loadMessages]);

  // Auto-scroll messages
  useLayoutEffect(() => {
    const list = messageListRef.current;
    if (list && followLatestRef.current) {
      list.scrollTop = list.scrollHeight;
    }
  }, [messages, messagesLoading, visible]);

  // Send message
  const handleSend = async () => {
    if (!selectedPerson) return;
    const userId = selectedPerson.user_id;
    const currentDraft = (drafts[userId] || '').trim();
    if (!currentDraft || busy) return;

    const id =
      retryRef.current?.user === userId && retryRef.current.text === currentDraft
        ? retryRef.current.id
        : crypto.randomUUID();

    retryRef.current = { user: userId, text: currentDraft, id };
    setBusy(true);

    try {
      await api(activeRole, userId + '/messages', { requestId: id, text: currentDraft });
      retryRef.current = null;
      setDrafts(prev => ({ ...prev, [userId]: '' }));

      const updatedMessages = await api(activeRole, userId + '/messages');
      if (activeUserIdRef.current === userId) {
        setMessages(Array.isArray(updatedMessages) ? updatedMessages : []);
        setError('');
      }
      void refreshAll();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Không thể gửi tin nhắn');
    } finally {
      setBusy(false);
    }
  };


  const currentQueue = activeRole === 'partner' ? partnerQueue : customerQueue;
  const filteredQueue = currentQueue.filter(p => {
    const query = searchQuery.trim().toLowerCase();
    if (!query) return true;
    const name = (p.full_name || '').toLowerCase();
    const id = (p.user_id || '').toLowerCase();
    return name.includes(query) || id.includes(query);
  });

  const currentDraftText = selectedPerson ? drafts[selectedPerson.user_id] || '' : '';

  // Render conversation sidebar / list
  const renderConversationList = () => (
    <>
      {/* 2 Tabs: Đối tác & Khách hàng */}
      <div className={styles.tabContainer}>
        <strong style={{flex:1,color:activeRole === 'partner' ? '#1e5bf8' : '#059669'}}>
          {activeRole === 'partner' ? 'CSKH Partner • Đối tác' : 'CSKH Customer • Khách hàng'}
        </strong>

        <button
          type="button"
          className={styles.refreshBtn}
          title="Làm mới danh sách"
          aria-label="Làm mới danh sách"
          onClick={refreshAll}
        >
          <RefreshCw size={15} className={refreshing ? styles.spinning : ''} />
        </button>
      </div>

      {/* Search Bar */}
      <div className={styles.searchBox}>
        <div className={styles.searchInputWrapper}>
          <Search size={14} className={styles.searchIcon} />
          <input
            type="text"
            className={styles.searchInput}
            placeholder={`Tìm kiếm ${activeRole === 'partner' ? 'đối tác' : 'khách hàng'}...`}
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
          />
          {searchQuery && (
            <button
              type="button"
              className={styles.clearSearchBtn}
              onClick={() => setSearchQuery('')}
              title="Xóa tìm kiếm"
            >
              <X size={13} />
            </button>
          )}
        </div>
      </div>

      {/* Conversation List */}
      <div className={styles.listContainer}>
        {filteredQueue.length === 0 ? (
          <div className={styles.emptyState}>
            <div className={styles.emptyIcon}>
              <MessageSquare size={26} />
            </div>
            <h4>{searchQuery ? 'Không tìm thấy' : 'Chưa có tin nhắn'}</h4>
            <p>
              {searchQuery
                ? `Không có ${activeRole === 'partner' ? 'đối tác' : 'khách hàng'} nào khớp với từ khóa.`
                : `Hộp thư của ${activeRole === 'partner' ? 'đối tác' : 'khách hàng'} hiện đang trống.`}
            </p>
          </div>
        ) : (
          filteredQueue.map(p => {
            const isSelected = selectedPerson?.user_id === p.user_id;
            const unread = Number(p.unread_count || 0);
            const defaultName = activeRole === 'partner' ? 'Đối tác Taskly' : 'Khách hàng Taskly';

            return (
              <button
                key={p.user_id}
                type="button"
                className={`${styles.conversationItem} ${isSelected ? styles.activeItem : ''}`}
                onClick={() => setSelectedPerson(p)}
              >
                <div className={styles.avatarWrapper}>
                  <Avatar person={p} role={activeRole} />
                  {unread > 0 && <span className={styles.unreadDot} />}
                </div>

                <div className={styles.conversationDetails}>
                  <div className={styles.conversationTop}>
                    <strong className={styles.contactName}>{p.full_name || defaultName}</strong>
                    {p.updated_at && (
                      <span className={styles.contactTime}>{formatTimestamp(p.updated_at)}</span>
                    )}
                  </div>

                  <div className={styles.conversationBottom}>
                    <span
                      className={`${styles.roleTag} ${
                        activeRole === 'partner' ? styles.partnerTag : styles.customerTag
                      }`}
                    >
                      {activeRole === 'partner' ? 'Đối tác' : 'Khách hàng'}
                    </span>

                    {unread > 0 ? (
                      <span className={styles.unreadCountBadge}>
                        {unread > 99 ? '99+' : unread} tin mới
                      </span>
                    ) : (
                      <span className={styles.lastActivity}>
                        {p.last_incoming_at ? 'Đã phản hồi' : 'Đang hoạt động'}
                      </span>
                    )}
                  </div>
                </div>
              </button>
            );
          })
        )}
      </div>
    </>
  );

  // Render chat pane (active conversation)
  const renderChatPane = () => {
    if (!selectedPerson) {
      return (
        <div className={styles.placeholderArea}>
          <div className={styles.placeholderIcon}>
            <MessageCircle size={34} />
          </div>
          <h3>Hộp thư hỗ trợ Taskly</h3>
          <p>
            Chọn một {activeRole === 'partner' ? 'đối tác' : 'khách hàng'} từ danh sách bên trái để
            xem tin nhắn và phản hồi.
          </p>
        </div>
      );
    }

    const defaultRoleName = activeRole === 'partner' ? 'Đối tác' : 'Khách hàng';

    return (
      <div className={styles.chatPane}>
        {/* Chat Header */}
        <header className={styles.chatHeader}>
          {!fullPage && (
            <button
              type="button"
              className={styles.backButton}
              onClick={() => setSelectedPerson(null)}
              title="Quay lại danh sách"
            >
              <ChevronLeft size={16} />
              <span>Danh sách</span>
            </button>
          )}

          <div className={styles.chatUserInfo}>
            <Avatar person={selectedPerson} role={activeRole} small />
            <div className={styles.chatUserDetails}>
              <b className={styles.chatHeaderName}>
                {selectedPerson.full_name || defaultRoleName}
              </b>
              <div className={styles.chatHeaderStatus}>
                <span className={styles.liveDot} />
                <span>Hỗ trợ {activeRole === 'partner' ? 'Đối tác' : 'Khách hàng'}</span>
              </div>
            </div>
          </div>

          <button
            type="button"
            className={styles.headerActionBtn}
            onClick={loadMessages}
            title="Làm mới tin nhắn"
            aria-label="Làm mới tin nhắn"
          >
            <RefreshCw size={15} className={messagesLoading ? styles.spinning : ''} />
          </button>
        </header>

        {/* Message Stream */}
        <div
          ref={messageListRef}
          className={styles.messagesArea}
          onScroll={e => {
            const list = e.currentTarget;
            followLatestRef.current =
              list.scrollHeight - list.scrollTop - list.clientHeight < 50;
          }}
        >
          {messagesLoading ? (
            <div className={styles.emptyState}>
              <RefreshCw size={24} className={styles.spinning} />
              <p style={{ marginTop: 10 }}>Đang tải tin nhắn…</p>
            </div>
          ) : messages.length === 0 ? (
            <div className={styles.emptyState}>
              <div className={styles.emptyIcon}>
                <MessageSquare size={24} />
              </div>
              <h4>Bắt đầu trò chuyện</h4>
              <p>Chưa có tin nhắn trong cuộc hội thoại này.</p>
            </div>
          ) : (
            messages.map(m => {
              const mine = m.sender === 'STAFF';
              return (
                <div
                  key={m.id || m.created_at || Math.random()}
                  className={`${styles.messageRow} ${mine ? styles.mine : ''}`}
                >
                  {!mine && <Avatar person={selectedPerson} role={activeRole} small />}
                  <div className={styles.bubble}>
                    {m.content && <p>{m.content}</p>}
                    {m.task_id && (
                      <a href={'?module=tasks&taskId=' + encodeURIComponent(m.task_id)}>
                        Xem đơn dịch vụ cần hỗ trợ
                      </a>
                    )}

                    {m.image_data && (
                      <button
                        type="button"
                        className={styles.imagePreviewCard}
                        onClick={() => setPhoto(m.image_data!)}
                        title="Bấm để xem ảnh phóng to"
                        aria-label="Xem ảnh đính kèm"
                      >
                        <img src={m.image_data} alt="Ảnh đính kèm" />
                        <span className={styles.imageZoomBadge}>
                          <Maximize2 size={11} />
                          <span>Xem ảnh</span>
                        </span>
                      </button>
                    )}

                    {m.created_at && (
                      <time dateTime={m.created_at}>
                        {formatTimestamp(m.created_at)}
                      </time>
                    )}
                  </div>
                </div>
              );
            })
          )}
        </div>

        {error && (
          <p role="alert" className={styles.errorAlert}>
            {error}
          </p>
        )}

        {/* Composer Form */}
        <form
          className={styles.composer}
          onSubmit={e => {
            e.preventDefault();
            void handleSend();
          }}
        >
          <textarea
            className={styles.composerTextarea}
            placeholder="Nhập tin nhắn…"
            aria-label="Nội dung tin nhắn"
            maxLength={4000}
            rows={1}
            disabled={busy}
            value={currentDraftText}
            onChange={e =>
              setDrafts(prev => ({ ...prev, [selectedPerson.user_id]: e.target.value }))
            }
            onKeyDown={e => {
              if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
                e.preventDefault();
                void handleSend();
              }
            }}
          />
          <button
            type="submit"
            className={styles.sendBtn}
            disabled={busy || !currentDraftText.trim()}
            title="Gửi tin nhắn"
            aria-label="Gửi tin nhắn"
          >
            <Send size={16} />
          </button>
        </form>
      </div>
    );
  };

  return (
    <>
      {/* Lightbox for Image Preview */}
      {photo && (
        <div
          role="dialog"
          aria-label="Ảnh đính kèm phóng to"
          className={styles.lightboxBackdrop}
          onClick={() => setPhoto(null)}
        >
          <div className={styles.lightboxCard} onClick={e => e.stopPropagation()}>
            <div className={styles.lightboxHeader}>
              <span>Ảnh đính kèm từ {activeRole === 'partner' ? 'Đối tác' : 'Khách hàng'}</span>
              <button
                type="button"
                className={styles.lightboxCloseBtn}
                onClick={() => setPhoto(null)}
                aria-label="Đóng ảnh"
              >
                <X size={18} />
              </button>
            </div>
            <img src={photo} alt="Ảnh sự cố hoặc tài liệu" className={styles.lightboxImg} />
          </div>
        </div>
      )}

      {fullPage ? (
        <div className={styles.fullPageContainer}>
          <aside className={styles.fullPageSidebar}>{renderConversationList()}</aside>
          <main className={styles.fullPageMain}>{renderChatPane()}</main>
        </div>
      ) : (
        <div className={styles.container}>
          {selectedPerson ? renderChatPane() : renderConversationList()}
        </div>
      )}
    </>
  );
}
