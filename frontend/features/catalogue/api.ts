import { apiRequest } from "@/lib/api/client";
import type {
  Catalogue,
  Category,
  CategoryInput,
  Envelope,
  ServiceInput,
  ServiceItem,
} from "./types";

export const getPublicCatalogue = (category?: string) =>
  apiRequest<Envelope<Catalogue>>(
    `/public/services${category ? `?category=${encodeURIComponent(category)}` : ""}`,
  );
export const getPublicService = (slug: string) =>
  apiRequest<Envelope<ServiceItem>>(
    `/public/services/${encodeURIComponent(slug)}`,
  );
export const getAdminCategories = () =>
  apiRequest<Envelope<Category[]>>("/admin/service-categories");
export const getAdminServices = () =>
  apiRequest<Envelope<ServiceItem[]>>("/admin/services");
export const createCategory = (body: CategoryInput) =>
  apiRequest<Envelope<Category>>("/admin/service-categories", {
    method: "POST",
    body,
  });
export const updateCategory = (id: string, body: CategoryInput) =>
  apiRequest<Envelope<Category>>(`/admin/service-categories/${id}`, {
    method: "PATCH",
    body,
  });
export const categoryAction = (id: string, action: "activate" | "deactivate") =>
  apiRequest<Envelope<Category>>(`/admin/service-categories/${id}/${action}`, {
    method: "POST",
  });
export const reorderCategory = (id: string, displayOrder: number) =>
  apiRequest<Envelope<Category>>(`/admin/service-categories/${id}/order`, {
    method: "POST",
    body: { displayOrder },
  });
export const deleteCategory = (id: string) =>
  apiRequest<Envelope<null>>(`/admin/service-categories/${id}`, {
    method: "DELETE",
  });
export const createService = (body: ServiceInput) =>
  apiRequest<Envelope<ServiceItem>>("/admin/services", {
    method: "POST",
    body,
  });
export const updateService = (id: string, body: ServiceInput) =>
  apiRequest<Envelope<ServiceItem>>(`/admin/services/${id}`, {
    method: "PATCH",
    body,
  });
export const serviceAction = (id: string, action: "activate" | "deactivate") =>
  apiRequest<Envelope<ServiceItem>>(`/admin/services/${id}/${action}`, {
    method: "POST",
  });
export const reorderService = (id: string, displayOrder: number) =>
  apiRequest<Envelope<ServiceItem>>(`/admin/services/${id}/order`, {
    method: "POST",
    body: { displayOrder },
  });
export const deleteService = (id: string) =>
  apiRequest<Envelope<null>>(`/admin/services/${id}`, { method: "DELETE" });
