import React, { useEffect, useRef } from 'react';
import { 
  Check, 
  Clock, 
  MapPin, 
  Tag, 
  ArrowRight, 
  Sparkles, 
  X,
  CreditCard
} from 'lucide-react';

export interface BookingDetails {
  bookingCode?: string;
  serviceName?: string;
  dateTime?: string;
  address?: string;
  originalPrice?: number;
  discountCode?: string;
  discountAmount?: number;
  finalPrice?: number;
  paymentMethod?: string;
}

export interface TasklyBookingSuccessProps {
  isOpen: boolean;
  onClose: () => void;
  onTrackProgress?: () => void;
  onGoHome?: () => void;
  data?: BookingDetails;
}

export const TasklyBookingSuccess: React.FC<TasklyBookingSuccessProps> = ({
  isOpen,
  onClose,
  onTrackProgress,
  onGoHome,
  data,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  // Default demo data if none provided
  const booking = {
    bookingCode: data?.bookingCode || '#TSK-84920',
    serviceName: data?.serviceName || 'Vệ sinh máy lạnh treo tường (2 máy)',
    dateTime: data?.dateTime || '09:00 - Thứ Tư, 22/10/2026',
    address: data?.address || '123 Nguyễn Trãi, P. Bến Thành, Q. 1, TP. HCM',
    originalPrice: data?.originalPrice ?? 320000,
    discountCode: data?.discountCode || 'TASKLY50K',
    discountAmount: data?.discountAmount ?? 50000,
    finalPrice: data?.finalPrice ?? 270000,
    paymentMethod: data?.paymentMethod || 'Tiền mặt khi hoàn thành',
  };

  // 3D Gravity Confetti Particle Burst Engine
  useEffect(() => {
    if (!isOpen) return;

    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animationFrameId: number;
    let width = (canvas.width = window.innerWidth);
    let height = (canvas.height = window.innerHeight);

    const handleResize = () => {
      if (!canvas) return;
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    };
    window.addEventListener('resize', handleResize);

    // Color palette: Biophilic Emerald, Champagne Amber Gold, Mint & Silver
    const colors = [
      '#059669', // Emerald
      '#10B981', // Brand Emerald
      '#34D399', // Neon Mint
      '#6EE7B7', // Frosted Mint
      '#F59E0B', // Amber Gold
      '#FBBF24', // Champagne Gold
      '#FEF3C7', // Pale Champagne
      '#FFFFFF', // Pearlescent White
    ];

    interface Particle {
      x: number;
      y: number;
      vx: number;
      vy: number;
      w: number;
      h: number;
      color: string;
      rotation: number;
      rotationSpeed: number;
      wobble: number;
      wobbleSpeed: number;
      opacity: number;
      gravity: number;
    }

    const particles: Particle[] = [];
    const count = 75;

    // Emit from center-top with spread burst
    for (let i = 0; i < count; i++) {
      const angle = (Math.PI / 2) + (Math.random() - 0.5) * 1.6;
      const speed = Math.random() * 12 + 6;
      particles.push({
        x: width / 2 + (Math.random() - 0.5) * 180,
        y: height * 0.22 + (Math.random() - 0.5) * 60,
        vx: Math.cos(angle) * speed,
        vy: -Math.sin(angle) * speed * 0.65,
        w: Math.random() * 10 + 6,
        h: Math.random() * 6 + 4,
        color: colors[Math.floor(Math.random() * colors.length)],
        rotation: Math.random() * Math.PI * 2,
        rotationSpeed: (Math.random() - 0.5) * 0.22,
        wobble: Math.random() * Math.PI * 2,
        wobbleSpeed: Math.random() * 0.12 + 0.05,
        opacity: 1,
        gravity: 0.28,
      });
    }

    let startTime = Date.now();

    const render = () => {
      const elapsed = Date.now() - startTime;
      ctx.clearRect(0, 0, width, height);

      let alive = false;
      for (let p of particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += p.gravity;
        p.vx *= 0.985; // air drag
        p.rotation += p.rotationSpeed;
        p.wobble += p.wobbleSpeed;

        // Fade out gradually after 2.8s
        if (elapsed > 2800) {
          p.opacity -= 0.018;
        }

        if (p.opacity > 0 && p.y < height + 50) {
          alive = true;
          ctx.save();
          ctx.translate(p.x, p.y);
          ctx.rotate(p.rotation);
          // 3D ribbon spin illusion via cos(wobble)
          ctx.scale(Math.cos(p.wobble), 1);
          ctx.fillStyle = p.color;
          ctx.globalAlpha = Math.max(0, p.opacity);
          ctx.beginPath();
          ctx.roundRect(-p.w / 2, -p.h / 2, p.w, p.h, 2);
          ctx.fill();
          ctx.restore();
        }
      }

      if (alive) {
        animationFrameId = requestAnimationFrame(render);
      }
    };

    animationFrameId = requestAnimationFrame(render);

    return () => {
      window.removeEventListener('resize', handleResize);
      cancelAnimationFrame(animationFrameId);
    };
  }, [isOpen]);

  if (!isOpen) return null;

  const formatVND = (amount: number) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 animate-in fade-in duration-200">
      {/* 3D Confetti Overlay Canvas */}
      <canvas
        ref={canvasRef}
        className="fixed inset-0 pointer-events-none z-50 w-full h-full"
      />

      {/* Spatial Backdrop Blur Overlay */}
      <div 
        onClick={onClose}
        className="fixed inset-0 bg-[#022C22]/50 backdrop-blur-md transition-opacity duration-300"
      />

      {/* Spatial Glass Modal Sheet */}
      <div 
        className="relative z-10 w-full max-w-lg rounded-t-[32px] sm:rounded-[32px] overflow-hidden 
                   bg-white/92 backdrop-blur-[24px] 
                   border border-white/95 
                   shadow-[0_25px_50px_-12px_rgba(3,43,34,0.25)] 
                   transition-all transform duration-300 animate-in slide-in-from-bottom-6 sm:zoom-in-95"
      >
        {/* Bioluminescent Aurora Gradient Mesh Underlay */}
        <div 
          className="absolute -top-32 left-1/2 -translate-x-1/2 w-96 h-96 rounded-full pointer-events-none"
          style={{
            background: 'radial-gradient(circle, rgba(52, 211, 153, 0.22) 0%, rgba(16, 185, 129, 0.08) 50%, transparent 75%)',
          }}
        />

        {/* Top Dismiss Button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 z-20 w-8 h-8 rounded-full bg-emerald-50/80 hover:bg-emerald-100/80 
                     border border-emerald-200/50 flex items-center justify-center text-[#065F46] 
                     transition-transform active:scale-90"
          aria-label="Đóng"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Modal Scrollable Body */}
        <div className="px-6 pt-8 pb-7 text-center relative z-10">
          
          {/* 3D Success Checkmark Badge */}
          <div className="relative inline-flex items-center justify-center mb-5">
            {/* Bioluminescent Outer Glow Rings */}
            <div className="absolute w-24 h-24 rounded-full bg-[#10B981]/25 animate-ping duration-1000" />
            <div className="absolute w-28 h-28 rounded-full bg-gradient-to-r from-emerald-400/20 to-teal-300/20 blur-xl" />
            
            {/* 3D Sphere Glass Base */}
            <div 
              className="relative w-20 h-20 rounded-full flex items-center justify-center
                         bg-gradient-to-br from-[#34D399] via-[#10B981] to-[#047857] 
                         border-[2.5px] border-[#6EE7B7] 
                         shadow-[0_14px_30px_-6px_rgba(16,185,129,0.5),inset_0_2px_4px_rgba(255,255,255,0.6)]
                         animate-in zoom-in-50 duration-500 ease-out"
            >
              {/* Animated SVG Checkmark with Spring Dasharray */}
              <svg 
                className="w-10 h-10 text-white drop-shadow-sm" 
                viewBox="0 0 24 24" 
                fill="none" 
                stroke="currentColor" 
                strokeWidth="3.2" 
                strokeLinecap="round" 
                strokeLinejoin="round"
              >
                <path 
                  d="M20 6L9 17l-5-5" 
                  style={{
                    strokeDasharray: 30,
                    strokeDashoffset: 0,
                    animation: 'drawCheck 0.55s cubic-bezier(0.65, 0, 0.45, 1) forwards',
                  }}
                />
              </svg>
            </div>
          </div>

          {/* Title */}
          <h2 className="text-2xl font-black text-[#032B22] tracking-tight mb-2">
            Đặt dịch vụ thành công! 🎉
          </h2>

          {/* Dynamic Order Code & Live Status Pill */}
          <div className="flex items-center justify-center gap-2.5 mb-6 flex-wrap">
            <span className="font-mono text-xs font-black px-2.5 py-1 rounded-lg bg-emerald-100/70 text-[#065F46] border border-emerald-200">
              {booking.bookingCode}
            </span>
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#ECFDF5] border border-[#A7F3D0] text-[#065F46] text-xs font-bold shadow-sm">
              <span className="w-2 h-2 rounded-full bg-[#10B981] animate-pulse" />
              <span>Đã xác nhận - Chuyên viên đang chuẩn bị</span>
            </div>
          </div>

          {/* Frosted Mint Glass Service Summary Card */}
          <div 
            className="text-left rounded-2xl p-4.5 mb-6 
                       bg-[#F0FDF8]/85 backdrop-blur-md 
                       border border-[#D1FAE5] 
                       shadow-[0_8px_20px_rgba(6,95,70,0.06)] space-y-3"
          >
            {/* Service Title */}
            <div className="flex items-start justify-between pb-2.5 border-b border-emerald-100">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-xl bg-emerald-600 text-white flex items-center justify-center shadow-sm">
                  <Sparkles className="w-4 h-4" />
                </div>
                <div>
                  <div className="text-[11px] font-bold uppercase tracking-wider text-emerald-700">Dịch vụ đã chọn</div>
                  <div className="text-sm font-extrabold text-[#032B22]">{booking.serviceName}</div>
                </div>
              </div>
            </div>

            {/* Time */}
            <div className="flex items-center gap-2.5 text-xs text-emerald-900 font-semibold">
              <Clock className="w-4 h-4 text-emerald-600 shrink-0" />
              <span>{booking.dateTime}</span>
            </div>

            {/* Address */}
            <div className="flex items-start gap-2.5 text-xs text-emerald-900 font-semibold">
              <MapPin className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
              <span className="line-clamp-2">{booking.address}</span>
            </div>

            {/* Pricing & Voucher Breakdown */}
            <div className="pt-2 border-t border-emerald-100/90 space-y-1.5">
              <div className="flex items-center justify-between text-xs text-emerald-800">
                <span>Giá gốc</span>
                <span className="font-semibold">{formatVND(booking.originalPrice)}</span>
              </div>

              {booking.discountAmount > 0 && (
                <div className="flex items-center justify-between text-xs">
                  <span className="inline-flex items-center gap-1 font-bold text-amber-700 bg-[#FEF3C7] border border-[#FDE68A] px-2 py-0.5 rounded-md">
                    <Tag className="w-3 h-3" />
                    {booking.discountCode}
                  </span>
                  <span className="font-bold text-emerald-700">
                    -{formatVND(booking.discountAmount)}
                  </span>
                </div>
              )}

              <div className="flex items-center justify-between text-xs text-emerald-800">
                <span className="inline-flex items-center gap-1">
                  <CreditCard className="w-3 h-3 text-emerald-600" />
                  <span>Hình thức</span>
                </span>
                <span className="font-semibold text-emerald-900">{booking.paymentMethod}</span>
              </div>

              <div className="flex items-center justify-between pt-1 text-sm font-black text-[#032B22]">
                <span>Tổng thanh toán</span>
                <span className="text-base font-black text-[#047857]">
                  {formatVND(booking.finalPrice)}
                </span>
              </div>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="space-y-2.5">
            {/* Primary Action Button (Gradient Emerald) */}
            <button
              onClick={() => {
                onClose();
                onTrackProgress?.();
              }}
              className="w-full py-3.5 px-6 rounded-2xl 
                         bg-gradient-to-r from-[#059669] via-[#10B981] to-[#047857] 
                         hover:brightness-105 active:scale-[0.98] 
                         text-white font-extrabold text-sm tracking-wide 
                         shadow-[0_12px_28px_-6px_rgba(16,185,129,0.45)] 
                         border border-emerald-300/40 
                         flex items-center justify-center gap-2 transition-all duration-150"
            >
              <span>Theo dõi tiến độ</span>
              <ArrowRight className="w-4 h-4" />
            </button>

            {/* Secondary Action Button (Frosted Mint Glass) */}
            <button
              onClick={() => {
                onClose();
                onGoHome?.();
              }}
              className="w-full py-3 px-6 rounded-2xl 
                         bg-[#F0FDF8] hover:bg-[#E6FBF2] active:scale-[0.98] 
                         text-[#065F46] font-bold text-xs tracking-wide 
                         border border-[#A7F3D0] 
                         transition-all duration-150"
            >
              Về trang chủ
            </button>
          </div>
        </div>

        {/* Global Keyframe CSS Injection for Checkmark Animation */}
        <style dangerouslySetInnerHTML={{
          __html: `
            @keyframes drawCheck {
              0% {
                stroke-dashoffset: 30;
                transform: scale(0.6);
                opacity: 0;
              }
              60% {
                transform: scale(1.15);
              }
              100% {
                stroke-dashoffset: 0;
                transform: scale(1);
                opacity: 1;
              }
            }
          `
        }} />
      </div>
    </div>
  );
};

export default TasklyBookingSuccess;
