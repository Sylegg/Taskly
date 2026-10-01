import { Badge } from "@/components/ui/badge";
import type { TaskPriority } from "./types";
import { AlertCircle, ArrowUp, ArrowRight, ArrowDown } from "lucide-react";

export function TaskPriorityBadge({ priority }: { priority: TaskPriority }) {
  switch (priority) {
    case "URGENT":
      return (
        <Badge variant="danger" className="gap-1">
          <AlertCircle className="size-3" />
          Khẩn cấp
        </Badge>
      );
    case "HIGH":
      return (
        <Badge variant="warning" className="gap-1">
          <ArrowUp className="size-3" />
          Ưu tiên cao
        </Badge>
      );
    case "MEDIUM":
      return (
        <Badge variant="info" className="gap-1">
          <ArrowRight className="size-3" />
          Trung bình
        </Badge>
      );
    case "LOW":
      return (
        <Badge variant="neutral" className="gap-1">
          <ArrowDown className="size-3" />
          Thấp
        </Badge>
      );
    default:
      return <Badge variant="neutral">{priority}</Badge>;
  }
}
