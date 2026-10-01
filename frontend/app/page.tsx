import Link from "next/link";
import {
  Sparkles,
  ShieldCheck,
  CheckCircle2,
  Clock,
  ArrowRight,
  Briefcase,
  Users,
  Star,
  MapPin,
} from "lucide-react";
import { TasklyLogo } from "@/components/brand/taskly-logo";

export default function Home() {
  const categories = [
    {
      name: "Dọn dẹp nhà cửa",
      desc: "Lau dọn theo giờ, tổng vệ sinh căn hộ, văn phòng chuyên nghiệp.",
      price: "Từ 80.000đ/giờ",
      icon: "🧹",
      slug: "cleaning",
    },
    {
      name: "Lắp ráp nội thất",
      desc: "Lắp bàn ghế, tủ quần áo, kệ tivi, đồ gỗ thông minh IKEA.",
      price: "Từ 150.000đ/món",
      icon: "🪑",
      slug: "assembly",
    },
    {
      name: "Chuyển nhà & Đồ đạc",
      desc: "Bốc xếp, chuyển trọ sinh viên, vận chuyển đồ đạc an toàn.",
      price: "Từ 250.000đ/chuyến",
      icon: "📦",
      slug: "moving",
    },
    {
      name: "Sửa chữa điện nước",
      desc: "Xử lý rò rỉ nước, thay ổ cắm điện, sửa quạt, thiết bị vệ sinh.",
      price: "Từ 120.000đ/lần",
      icon: "⚡",
      slug: "handyman",
    },
  ];

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 flex flex-col antialiased">
      {/* Navigation */}
      <header className="sticky top-0 z-50 border-b border-slate-200/80 bg-white/95 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-8">
          <Link href="/" className="flex items-center gap-2 group">
            <TasklyLogo />
          </Link>

          <nav className="hidden md:flex items-center gap-6 text-sm font-semibold text-slate-600">
            <Link href="/services" className="hover:text-emerald-700 transition-colors">
              Dịch vụ
            </Link>
            <Link href="/customer" className="hover:text-emerald-700 transition-colors">
              Bảng quản lý việc
            </Link>
            <Link href="/tasker" className="hover:text-emerald-700 transition-colors">
              Dành cho Tasker
            </Link>
          </nav>

          <div className="flex items-center gap-3">
            <Link
              href="/auth/login"
              className="text-xs sm:text-sm font-semibold text-slate-700 hover:text-emerald-700 px-3 py-2"
            >
              Đăng nhập
            </Link>
            <Link
              href="/customer"
              className="rounded-xl bg-emerald-600 px-4 py-2 text-xs sm:text-sm font-bold text-white shadow-xs hover:bg-emerald-700 transition-colors flex items-center gap-1.5"
            >
              Mở Dashboard <ArrowRight className="size-3.5" />
            </Link>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="relative overflow-hidden pt-12 pb-16 sm:pt-20 sm:pb-24 border-b border-slate-200/60 bg-gradient-to-b from-white to-slate-50">
        <div className="mx-auto max-w-7xl px-4 sm:px-8">
          <div className="mx-auto max-w-3xl text-center">
            <div className="inline-flex items-center gap-2 rounded-full bg-emerald-50 px-3.5 py-1 text-xs font-bold text-emerald-800 border border-emerald-200 mb-6 shadow-2xs">
              <Sparkles className="size-3.5 text-emerald-600" />
              Nền tảng kết nối việc làm ngắn hạn chuẩn mực & bảo hộ 100%
            </div>

            <h1 className="text-4xl sm:text-6xl font-extrabold tracking-tight text-slate-900 leading-[1.15]">
              Giải quyết mọi việc nhà <br className="hidden sm:inline" />
              với <span className="text-emerald-600 underline decoration-emerald-200 decoration-wavy">Tasker đáng tin cậy</span>
            </h1>

            <p className="mt-6 text-base sm:text-lg text-slate-600 leading-relaxed max-w-2xl mx-auto">
              Từ dọn dẹp, lắp ráp nội thất đến chuyển nhà và sửa chữa. 
              Đặt lịch nhanh trong 60 giây, kiểm soát ngân sách minh bạch và tiền chỉ chuyển đi khi bạn hài lòng.
            </p>

            <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3.5">
              <Link
                href="/customer"
                className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-xl bg-emerald-600 px-6 py-3.5 text-sm font-bold text-white shadow-lg shadow-emerald-600/25 hover:bg-emerald-700 transition-all hover:-translate-y-0.5"
              >
                Trải nghiệm Bảng quản lý ngay
                <ArrowRight className="size-4" />
              </Link>
              <Link
                href="/services"
                className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-xl border border-slate-200 bg-white px-6 py-3.5 text-sm font-bold text-slate-700 hover:bg-slate-50 transition-colors"
              >
                Xem danh mục dịch vụ
              </Link>
            </div>

            {/* Trust metrics */}
            <div className="mt-12 grid grid-cols-3 gap-4 border-t border-slate-200 pt-8 max-w-lg mx-auto text-center">
              <div>
                <div className="text-2xl font-extrabold text-slate-900">100%</div>
                <div className="text-xs text-slate-500 font-medium mt-0.5">Xác minh căn cước KYC</div>
              </div>
              <div>
                <div className="text-2xl font-extrabold text-emerald-600">4.9★</div>
                <div className="text-xs text-slate-500 font-medium mt-0.5">Đánh giá trung bình</div>
              </div>
              <div>
                <div className="text-2xl font-extrabold text-slate-900">0đ</div>
                <div className="text-xs text-slate-500 font-medium mt-0.5">Rủi ro tiền ứng trước</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Popular Categories */}
      <section className="py-16 sm:py-20 bg-white">
        <div className="mx-auto max-w-7xl px-4 sm:px-8">
          <div className="flex flex-col md:flex-row md:items-end justify-between mb-12">
            <div>
              <p className="text-xs font-bold uppercase tracking-wider text-emerald-700">Dịch vụ phổ biến</p>
              <h2 className="mt-1 text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
                Các hạng mục công việc được tin chọn nhiều nhất
              </h2>
            </div>
            <Link
              href="/services"
              className="mt-3 md:mt-0 inline-flex items-center gap-1.5 text-sm font-bold text-emerald-700 hover:underline"
            >
              Xem toàn bộ danh mục <ArrowRight className="size-4" />
            </Link>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {categories.map((c) => (
              <div
                key={c.slug}
                className="group rounded-2xl border border-slate-200/90 bg-white p-6 shadow-xs hover:border-emerald-400 hover:shadow-lg transition-all duration-200 flex flex-col justify-between"
              >
                <div>
                  <div className="text-3xl mb-4 p-3 rounded-2xl bg-emerald-50/80 w-fit group-hover:scale-110 transition-transform">
                    {c.icon}
                  </div>
                  <h3 className="font-bold text-lg text-slate-900 group-hover:text-emerald-700 transition-colors">
                    {c.name}
                  </h3>
                  <p className="mt-2 text-xs sm:text-sm text-slate-500 leading-relaxed">
                    {c.desc}
                  </p>
                </div>
                <div className="mt-6 pt-4 border-t border-slate-100 flex items-center justify-between">
                  <span className="text-xs font-bold text-emerald-700">{c.price}</span>
                  <Link
                    href="/customer"
                    className="text-xs font-semibold text-slate-600 group-hover:text-emerald-700 flex items-center gap-1"
                  >
                    Đặt việc <ChevronRight className="size-3.5" />
                  </Link>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Safety & Guarantees */}
      <section className="py-16 bg-slate-50 border-t border-slate-200/80">
        <div className="mx-auto max-w-7xl px-4 sm:px-8">
          <div className="rounded-3xl bg-gradient-to-br from-emerald-900 to-teal-950 p-8 sm:p-14 text-white shadow-xl">
            <div className="max-w-2xl">
              <span className="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-emerald-300">
                <ShieldCheck className="size-4" />
                Đảm bảo an toàn tuyệt đối
              </span>
              <h2 className="mt-3 text-3xl sm:text-4xl font-extrabold tracking-tight">
                Không lo thất lạc, rủi ro hay phát sinh chi phí ngoài ý muốn
              </h2>
              <p className="mt-4 text-emerald-100/90 text-sm sm:text-base leading-relaxed">
                TaskLy xây dựng cơ chế ký quỹ độc lập và sổ cái kế toán bất biến. 
                Tasker chỉ nhận tiền khi bạn trực tiếp bấm nút Nghiệm thu trên ứng dụng hoặc Web.
              </p>

              <div className="mt-8 grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs sm:text-sm">
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="size-4 text-emerald-400 shrink-0" />
                  <span>Xác minh danh tính CCCD & mặt chụp</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="size-4 text-emerald-400 shrink-0" />
                  <span>Cam kết bồi hoàn nếu không hài lòng</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="size-4 text-emerald-400 shrink-0" />
                  <span>Đồng bộ tức thì giữa Mobile App & Web</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="size-4 text-emerald-400 shrink-0" />
                  <span>Hỗ trợ tranh chấp 24/7 từ Admin</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="mt-auto border-t border-slate-200 bg-white py-10 text-xs text-slate-500">
        <div className="mx-auto max-w-7xl px-4 sm:px-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <span className="font-bold text-slate-800">TaskLy Platform</span>
            <span>• Nền tảng dịch vụ & công việc ngắn hạn thế hệ mới</span>
          </div>
          <div className="flex items-center gap-6">
            <Link href="/services" className="hover:underline">Dịch vụ</Link>
            <Link href="/customer" className="hover:underline">Khách hàng</Link>
            <Link href="/tasker" className="hover:underline">Dành cho Tasker</Link>
            <Link href="/auth/login" className="hover:underline">Đăng nhập</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}

function ChevronRight({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <polyline points="9 18 15 12 9 6" />
    </svg>
  );
}
