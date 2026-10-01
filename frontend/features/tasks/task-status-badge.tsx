import { Badge } from "@/components/ui/badge";
import type { TaskStatus } from "./types";
import {
  FileEdit,
  Send,
  Radar,
  Handshake,
  Wrench,
  CheckCircle2,
  DollarSign,
  XCircle,
} from "lucide-react";

export function TaskStatusBadge({ status }: { status: TaskStatus }) {
  switch (status) {
    case "DRAFT":
      return (
        <Badge variant="neutral" className="gap-1">
          <FileEdit className="size-3" />
          Bản nháp
        </Badge>
      );
    case "POSTED":
      return (
        <Badge variant="info" className="gap-1">
          <Send className="size-3" />
          Đã đăng
        </Badge>
      );
    case "MATCHING":
      return (
        <Badge variant="warning" className="gap-1 animate-pulse">
          <Radar className="size-3" />
          Đang ghép Tasker
        </Badge>
      );
    case "ACCEPTED":
      return (
        <Badge variant="success" className="gap-1">
          <Handshake className="size-3" />
          Đã nhận việc
        </Badge>
      );
    case "IN_PROGRESS":
      return (
        <Badge variant="warning" className="gap-1">
          <Wrench className="size-3" />
          Đang thực hiện
        </Badge>
      );
    case "COMPLETED":
      return (
        <Badge variant="success" className="gap-1">
          <CheckCircle2 className="size-3" />
          Chờ nghiệm thu
        </Badge>
      );
    case "PAID":
      return (
        <Badge variant="success" className="gap-1">
          <DollarSign className="size-3" />
          Đã hoàn tất
        </Badge>
      );
    case "CANCELLED":
      return (
        <Badge variant="danger" className="gap-1">
          <XCircle className="size-3" />
          Đã hủy
        </Badge>
      );
    default:
      return <Badge variant="neutral">{status}</Badge>;
  }
}
