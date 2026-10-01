"use client";

import { useCallback, useEffect, useState, type FormEvent } from "react";
import {
  categoryAction,
  createCategory,
  createService,
  deleteCategory,
  deleteService,
  getAdminCategories,
  getAdminServices,
  reorderCategory,
  reorderService,
  serviceAction,
  updateCategory,
  updateService,
} from "./api";
import type {
  Category,
  CategoryInput,
  ServiceInput,
  ServiceItem,
} from "./types";

const emptyCategory: CategoryInput = {
  slug: "",
  name: "",
  description: "",
  displayOrder: 0,
};
const emptyService: ServiceInput = {
  categoryId: "",
  slug: "",
  name: "",
  shortDescription: "",
  description: "",
  suggestedPriceMin: 0,
  suggestedPriceMax: 0,
  currency: "VND",
  estimatedDurationMinutes: null,
  displayOrder: 0,
};

export function AdminCataloguePanel({ allowed }: { allowed: boolean }) {
  const [categories, setCategories] = useState<Category[]>([]);
  const [services, setServices] = useState<ServiceItem[]>([]);
  const [categoryForm, setCategoryForm] =
    useState<CategoryInput>(emptyCategory);
  const [serviceForm, setServiceForm] = useState<ServiceInput>(emptyService);
  const [editingCategory, setEditingCategory] = useState<string | null>(null);
  const [editingService, setEditingService] = useState<string | null>(null);
  const [loading, setLoading] = useState(allowed);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!allowed) return;
    setError(null);
    try {
      const [categoryResponse, serviceResponse] = await Promise.all([
        getAdminCategories(),
        getAdminServices(),
      ]);
      setCategories(categoryResponse.data);
      setServices(serviceResponse.data);
    } catch (caught) {
      setError(message(caught));
    } finally {
      setLoading(false);
    }
  }, [allowed]);

  useEffect(() => {
    if (!allowed) return;
    let active = true;
    Promise.all([getAdminCategories(), getAdminServices()])
      .then(([c, s]) => {
        if (active) {
          setCategories(c.data);
          setServices(s.data);
        }
      })
      .catch((caught: unknown) => {
        if (active) setError(message(caught));
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [allowed]);

  if (!allowed)
    return (
      <p
        className="mt-8 rounded-xl bg-amber-50 p-5 text-amber-900"
        role="alert"
      >
        Tài khoản không có quyền SERVICE_MANAGE. Catalogue Admin không tải dữ
        liệu.
      </p>
    );

  async function run(action: () => Promise<unknown>, success: string) {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await action();
      setNotice(success);
      await load();
    } catch (caught) {
      setError(message(caught));
    } finally {
      setBusy(false);
    }
  }

  function submitCategory(event: FormEvent) {
    event.preventDefault();
    void run(
      async () => {
        if (editingCategory)
          await updateCategory(editingCategory, categoryForm);
        else await createCategory(categoryForm);
        setEditingCategory(null);
        setCategoryForm(emptyCategory);
      },
      editingCategory
        ? "Đã cập nhật danh mục."
        : "Đã tạo danh mục ở trạng thái chưa kích hoạt.",
    );
  }
  function submitService(event: FormEvent) {
    event.preventDefault();
    void run(
      async () => {
        if (editingService) await updateService(editingService, serviceForm);
        else await createService(serviceForm);
        setEditingService(null);
        setServiceForm(emptyService);
      },
      editingService
        ? "Đã cập nhật dịch vụ."
        : "Đã tạo dịch vụ ở trạng thái chưa kích hoạt.",
    );
  }

  if (loading)
    return (
      <p className="mt-8" role="status">
        Đang tải catalogue…
      </p>
    );
  return (
    <div className="mt-8 grid gap-10">
      {error && (
        <p
          className="rounded-lg bg-red-50 p-3 text-sm text-red-800"
          role="alert"
        >
          {error}
        </p>
      )}
      {notice && (
        <p
          className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-800"
          role="status"
        >
          {notice}
        </p>
      )}
      <section className="grid gap-6 lg:grid-cols-[2fr_1fr]">
        <div>
          <h2 className="text-2xl font-bold">Danh mục</h2>
          {categories.length === 0 ? (
            <Empty />
          ) : (
            <div className="mt-4 grid gap-3">
              {categories.map((item) => (
                <article className="rounded-xl border p-4" key={item.id}>
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <h3 className="font-bold">{item.name}</h3>
                      <p className="text-sm text-slate-500">
                        /{item.slug} · thứ tự {item.displayOrder} ·{" "}
                        {item.active ? "đang hiện" : "đang ẩn"}
                      </p>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <Action
                        disabled={busy}
                        onClick={() => {
                          setEditingCategory(item.id);
                          setCategoryForm({
                            slug: item.slug,
                            name: item.name,
                            description: item.description ?? "",
                            displayOrder: item.displayOrder,
                          });
                        }}
                        text="Sửa"
                      />
                      <Action
                        disabled={busy}
                        onClick={() =>
                          void run(
                            () =>
                              categoryAction(
                                item.id,
                                item.active ? "deactivate" : "activate",
                              ),
                            item.active
                              ? "Đã ẩn danh mục."
                              : "Đã kích hoạt danh mục.",
                          )
                        }
                        text={item.active ? "Ẩn" : "Kích hoạt"}
                      />
                      <Action
                        disabled={busy}
                        onClick={() =>
                          void run(
                            () =>
                              reorderCategory(item.id, item.displayOrder + 1),
                            "Đã tăng thứ tự danh mục.",
                          )
                        }
                        text="Xuống"
                      />
                      <Action
                        danger
                        disabled={busy}
                        onClick={() =>
                          void run(
                            () => deleteCategory(item.id),
                            "Đã xóa danh mục.",
                          )
                        }
                        text="Xóa"
                      />
                    </div>
                  </div>
                </article>
              ))}
            </div>
          )}
        </div>
        <form
          className="grid content-start gap-3 rounded-2xl border p-5"
          onSubmit={submitCategory}
        >
          <h3 className="font-bold">
            {editingCategory ? "Sửa danh mục" : "Thêm danh mục"}
          </h3>
          <Input
            label="Slug"
            value={categoryForm.slug}
            onChange={(value) =>
              setCategoryForm({ ...categoryForm, slug: value })
            }
            pattern="[a-z0-9]+(?:-[a-z0-9]+)*"
          />
          <Input
            label="Tên"
            value={categoryForm.name}
            onChange={(value) =>
              setCategoryForm({ ...categoryForm, name: value })
            }
          />
          <label className="grid gap-1 text-sm font-semibold">
            Mô tả
            <textarea
              className="rounded-lg border p-2 font-normal"
              maxLength={1000}
              onChange={(e) =>
                setCategoryForm({
                  ...categoryForm,
                  description: e.target.value,
                })
              }
              value={categoryForm.description}
            />
          </label>
          <NumberInput
            label="Thứ tự"
            value={categoryForm.displayOrder}
            onChange={(value) =>
              setCategoryForm({ ...categoryForm, displayOrder: value })
            }
          />
          <button
            className="rounded-lg bg-emerald-700 px-4 py-2 font-semibold text-white disabled:opacity-50"
            disabled={busy}
            type="submit"
          >
            Lưu danh mục
          </button>
          {editingCategory && (
            <button
              className="text-sm"
              onClick={() => {
                setEditingCategory(null);
                setCategoryForm(emptyCategory);
              }}
              type="button"
            >
              Hủy sửa
            </button>
          )}
        </form>
      </section>
      <section className="grid gap-6 lg:grid-cols-[2fr_1fr]">
        <div>
          <h2 className="text-2xl font-bold">Dịch vụ</h2>
          {services.length === 0 ? (
            <Empty />
          ) : (
            <div className="mt-4 grid gap-3">
              {services.map((item) => (
                <article className="rounded-xl border p-4" key={item.id}>
                  <h3 className="font-bold">{item.name}</h3>
                  <p className="text-sm text-slate-500">
                    {item.category.name} · /{item.slug} ·{" "}
                    {item.active ? "đang hiện" : "đang ẩn"}
                  </p>
                  <p className="mt-1 text-sm">
                    {item.suggestedPriceMin.toLocaleString("vi-VN")}–
                    {item.suggestedPriceMax.toLocaleString("vi-VN")}{" "}
                    {item.currency}
                  </p>
                  <div className="mt-3 flex flex-wrap gap-2">
                    <Action
                      disabled={busy}
                      onClick={() => {
                        setEditingService(item.id);
                        setServiceForm({
                          categoryId: item.category.id,
                          slug: item.slug,
                          name: item.name,
                          shortDescription: item.shortDescription,
                          description: item.description ?? "",
                          suggestedPriceMin: item.suggestedPriceMin,
                          suggestedPriceMax: item.suggestedPriceMax,
                          currency: item.currency,
                          estimatedDurationMinutes:
                            item.estimatedDurationMinutes,
                          displayOrder: item.displayOrder,
                        });
                      }}
                      text="Sửa"
                    />
                    <Action
                      disabled={busy}
                      onClick={() =>
                        void run(
                          () =>
                            serviceAction(
                              item.id,
                              item.active ? "deactivate" : "activate",
                            ),
                          item.active
                            ? "Đã ẩn dịch vụ."
                            : "Đã kích hoạt dịch vụ.",
                        )
                      }
                      text={item.active ? "Ẩn" : "Kích hoạt"}
                    />
                    <Action
                      disabled={busy}
                      onClick={() =>
                        void run(
                          () => reorderService(item.id, item.displayOrder + 1),
                          "Đã tăng thứ tự dịch vụ.",
                        )
                      }
                      text="Xuống"
                    />
                    <Action
                      danger
                      disabled={busy}
                      onClick={() =>
                        void run(
                          () => deleteService(item.id),
                          "Đã xóa dịch vụ.",
                        )
                      }
                      text="Xóa"
                    />
                  </div>
                </article>
              ))}
            </div>
          )}
        </div>
        <form
          className="grid content-start gap-3 rounded-2xl border p-5"
          onSubmit={submitService}
        >
          <h3 className="font-bold">
            {editingService ? "Sửa dịch vụ" : "Thêm dịch vụ"}
          </h3>
          <label className="grid gap-1 text-sm font-semibold">
            Danh mục
            <select
              className="rounded-lg border p-2 font-normal"
              onChange={(e) =>
                setServiceForm({ ...serviceForm, categoryId: e.target.value })
              }
              required
              value={serviceForm.categoryId}
            >
              <option value="">Chọn danh mục</option>
              {categories.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}
                </option>
              ))}
            </select>
          </label>
          <Input
            label="Slug"
            value={serviceForm.slug}
            onChange={(value) =>
              setServiceForm({ ...serviceForm, slug: value })
            }
            pattern="[a-z0-9]+(?:-[a-z0-9]+)*"
          />
          <Input
            label="Tên"
            value={serviceForm.name}
            onChange={(value) =>
              setServiceForm({ ...serviceForm, name: value })
            }
          />
          <Input
            label="Mô tả ngắn"
            value={serviceForm.shortDescription}
            onChange={(value) =>
              setServiceForm({ ...serviceForm, shortDescription: value })
            }
          />
          <label className="grid gap-1 text-sm font-semibold">
            Mô tả đầy đủ
            <textarea
              className="rounded-lg border p-2 font-normal"
              maxLength={4000}
              onChange={(e) =>
                setServiceForm({ ...serviceForm, description: e.target.value })
              }
              value={serviceForm.description}
            />
          </label>
          <NumberInput
            label="Giá tối thiểu"
            value={serviceForm.suggestedPriceMin}
            onChange={(value) =>
              setServiceForm({ ...serviceForm, suggestedPriceMin: value })
            }
          />
          <NumberInput
            label="Giá tối đa"
            value={serviceForm.suggestedPriceMax}
            onChange={(value) =>
              setServiceForm({ ...serviceForm, suggestedPriceMax: value })
            }
          />
          <Input
            label="Tiền tệ"
            value={serviceForm.currency}
            onChange={(value) =>
              setServiceForm({ ...serviceForm, currency: value.toUpperCase() })
            }
            pattern="[A-Z]{3}"
          />
          <NumberInput
            label="Thời lượng (phút)"
            min={15}
            value={serviceForm.estimatedDurationMinutes ?? 15}
            onChange={(value) =>
              setServiceForm({
                ...serviceForm,
                estimatedDurationMinutes: value,
              })
            }
          />
          <NumberInput
            label="Thứ tự"
            value={serviceForm.displayOrder}
            onChange={(value) =>
              setServiceForm({ ...serviceForm, displayOrder: value })
            }
          />
          <button
            className="rounded-lg bg-emerald-700 px-4 py-2 font-semibold text-white disabled:opacity-50"
            disabled={busy || categories.length === 0}
            type="submit"
          >
            Lưu dịch vụ
          </button>
          {editingService && (
            <button
              className="text-sm"
              onClick={() => {
                setEditingService(null);
                setServiceForm(emptyService);
              }}
              type="button"
            >
              Hủy sửa
            </button>
          )}
        </form>
      </section>
    </div>
  );
}
function Action({
  text,
  onClick,
  disabled,
  danger = false,
}: {
  text: string;
  onClick: () => void;
  disabled: boolean;
  danger?: boolean;
}) {
  return (
    <button
      className={`rounded-lg border px-3 py-1 text-sm font-semibold ${danger ? "text-red-700" : ""}`}
      disabled={disabled}
      onClick={onClick}
      type="button"
    >
      {text}
    </button>
  );
}
function Input({
  label,
  value,
  onChange,
  pattern,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  pattern?: string;
}) {
  return (
    <label className="grid gap-1 text-sm font-semibold">
      {label}
      <input
        className="rounded-lg border p-2 font-normal"
        maxLength={500}
        onChange={(e) => onChange(e.target.value)}
        pattern={pattern}
        required
        value={value}
      />
    </label>
  );
}
function NumberInput({
  label,
  value,
  onChange,
  min = 0,
}: {
  label: string;
  value: number;
  onChange: (value: number) => void;
  min?: number;
}) {
  return (
    <label className="grid gap-1 text-sm font-semibold">
      {label}
      <input
        className="rounded-lg border p-2 font-normal"
        min={min}
        onChange={(e) => onChange(Number(e.target.value))}
        required
        type="number"
        value={value}
      />
    </label>
  );
}
function Empty() {
  return (
    <p className="mt-4 rounded-xl border border-dashed p-6 text-center text-slate-500">
      Chưa có dữ liệu.
    </p>
  );
}
function message(value: unknown) {
  return value instanceof Error ? value.message : "Không thể hoàn tất yêu cầu.";
}
