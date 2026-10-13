package com.taskly.booking;

import com.taskly.common.exception.DomainException;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;

/** Versioned requirements only. Prices and payment policies are deliberately separate. */
public final class BookingSchemas {
    private BookingSchemas() {}
    public record Field(String key, String label, String type, boolean required,
                        Integer minimum, List<String> options) {}
    public record Schema(String key, int version, List<String> serviceSlugs, List<Field> fields) {}
    private static Field text(String key, String label) { return new Field(key, label, "text", true, null, List.of()); }
    private static Field number(String key, String label, int min) { return new Field(key, label, "number", true, min, List.of()); }
    private static Field choice(String key, String label, String... options) { return new Field(key, label, "choice", true, null, List.of(options)); }
    public static final List<Schema> ALL = List.of(
        new Schema("clean", 1, List.of("clean", "cleaning", "home-cleaning"), List.of(number("area", "Diện tích (m²)", 1), number("rooms", "Số phòng", 0), number("bathrooms", "Số phòng tắm", 0), choice("supplies", "Dụng cụ", "Nhà đã có", "Partner mang theo"))),
        new Schema("deep", 1, List.of("deep", "deep-cleaning"), List.of(number("area", "Diện tích (m²)", 1), number("rooms", "Số phòng", 0), choice("windows", "Vệ sinh cửa kính", "Có", "Không"))),
        new Schema("repair", 1, List.of("repair", "assembly", "aircon-repair", "washing-machine-repair", "refrigerator-repair", "furniture-disassembly"), List.of(text("device", "Hạng mục hoặc thiết bị"), text("issue", "Yêu cầu thực hiện"), choice("urgency", "Mức độ khẩn cấp", "Bình thường", "Cần sớm"))),
        new Schema("move", 1, List.of("move", "moving"), List.of(text("pickup", "Địa chỉ đi"), text("dropoff", "Địa chỉ đến"), number("floor", "Tầng", 0), choice("elevator", "Thang máy", "Có", "Không"), number("boxes", "Số thùng", 1))),
        new Schema("ac", 1, List.of("ac", "aircon", "air-conditioning"), List.of(number("units", "Số máy lạnh", 1), choice("type", "Loại máy", "Treo tường", "Âm trần", "Tủ đứng"), text("access", "Hướng dẫn tiếp cận máy"))),
        new Schema("shop", 1, List.of("shop", "shopping", "grocery-delivery"), List.of(text("shoppingList", "Danh sách mua hàng"), number("budget", "Ngân sách mua hàng (VND)", 1), choice("receipt", "Yêu cầu hóa đơn", "Có", "Không"))),
        new Schema("pets", 1, List.of("pets", "pet-care", "dog-walking"), List.of(text("animal", "Loại thú cưng"), number("count", "Số thú cưng", 1), text("care", "Yêu cầu chăm sóc"))),
        new Schema("it", 1, List.of("it", "it-support", "wifi-setup"), List.of(text("device", "Thiết bị"), text("issue", "Vấn đề cần hỗ trợ"), choice("remote", "Hình thức", "Tại nhà", "Từ xa"))),
        new Schema("upholstery", 1, List.of("upholstery", "sofa-cleaning", "mattress-cleaning"), List.of(number("items", "Số món cần vệ sinh", 1), text("material", "Chất liệu"), text("access", "Hướng dẫn tiếp cận đồ cần vệ sinh"))),
        new Schema("laundry", 1, List.of("laundry"), List.of(number("weightKg", "Khối lượng quần áo (kg nguyên)", 1), choice("treatment", "Hình thức giặt", "Giặt sấy", "Giặt và gấp"), text("access", "Hướng dẫn nhận và giao quần áo"))),
        new Schema("ironing", 1, List.of("ironing"), List.of(number("items", "Số món quần áo cần ủi", 1), text("clothing", "Loại quần áo và chất liệu"), text("access", "Hướng dẫn nhận và giao quần áo"))),
        new Schema("packing", 1, List.of("packing"), List.of(number("boxes", "Số thùng", 1), text("contents", "Đồ đạc cần đóng gói"), choice("fragile", "Có đồ dễ vỡ", "Có", "Không"), text("access", "Hướng dẫn tiếp cận khu vực đóng gói")))
    );
    public static Schema require(String key, int version, String slug) {
        return ALL.stream().filter(s -> s.key().equals(key) && s.version() == version && s.serviceSlugs().contains(slug))
            .findFirst().orElseThrow(() -> invalid("Dịch vụ chưa hỗ trợ biểu mẫu này."));
    }
    public static void validatePartial(Schema schema, Map<String, Object> details) {
        if (details == null) throw invalid("Thông tin dịch vụ không hợp lệ.");
        for (var entry : details.entrySet()) {
            if ("quoteSessionId".equals(entry.getKey())) continue;
            if ("selectedServiceIds".equals(entry.getKey()) || entry.getKey().startsWith("service_") || entry.getKey().startsWith("notes_") || entry.getKey().contains("_")) continue;
            var field = schema.fields().stream().filter(f -> f.key().equals(entry.getKey())).findFirst()
                .orElseThrow(() -> invalid("Trường dịch vụ không hợp lệ."));
            Object value = entry.getValue();
            if (value == null || value.toString().isBlank()) continue;
            String raw = value.toString();
            if (raw.length() > 2000) throw invalid("Thông tin quá dài.");
            if (field.type().equals("number")) {
                try {
                    long number = Long.parseLong(raw);
                    if (number < field.minimum() || number > 100000000) throw invalid("Số lượng ngoài phạm vi hợp lệ.");
                } catch (NumberFormatException e) { throw invalid("Nhập số nguyên hợp lệ."); }
            } else if (!(value instanceof String)) throw invalid("Thông tin phải là văn bản.");
            if (field.type().equals("choice") && !field.options().contains(raw)) throw invalid("Lựa chọn không hợp lệ.");
        }
        if (schema.key().equals("move") && details.get("pickup") != null && details.get("dropoff") != null
            && !details.get("pickup").toString().isBlank()
            && details.get("pickup").toString().trim().equalsIgnoreCase(details.get("dropoff").toString().trim()))
            throw invalid("Địa chỉ đi và đến phải khác nhau.");
    }
    private static DomainException invalid(String message) {
        return new DomainException("INVALID_BOOKING_DETAILS", message, HttpStatus.UNPROCESSABLE_ENTITY);
    }
}
