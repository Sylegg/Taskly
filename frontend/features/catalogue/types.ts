import type { ApiEnvelope } from "@/features/auth/types";

export type Category = Readonly<{
  id: string;
  slug: string;
  name: string;
  description: string | null;
  active: boolean;
  displayOrder: number;
  createdAt: string;
}>;
export type ServiceItem = Readonly<{
  id: string;
  category: Category;
  slug: string;
  name: string;
  shortDescription: string;
  description: string | null;
  suggestedPriceMin: number;
  suggestedPriceMax: number;
  currency: string;
  estimatedDurationMinutes: number | null;
  active: boolean;
  displayOrder: number;
  createdAt: string;
}>;
export type Catalogue = Readonly<{
  categories: Category[];
  services: ServiceItem[];
}>;
export type CategoryInput = {
  slug: string;
  name: string;
  description: string;
  displayOrder: number;
};
export type ServiceInput = {
  categoryId: string;
  slug: string;
  name: string;
  shortDescription: string;
  description: string;
  suggestedPriceMin: number;
  suggestedPriceMax: number;
  currency: string;
  estimatedDurationMinutes: number | null;
  displayOrder: number;
};
export type Envelope<T> = ApiEnvelope<T>;
