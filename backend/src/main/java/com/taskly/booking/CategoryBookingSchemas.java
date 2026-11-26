package com.taskly.booking;

import com.taskly.common.exception.DomainException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
public class CategoryBookingSchemas {
    private static final Set<String> EXCLUDED_CATEGORY_FIELDS = Set.of("floor", "budget");

    private final JdbcTemplate db;
    private final ObjectMapper json;

    public CategoryBookingSchemas(JdbcTemplate db, ObjectMapper json) {
        this.db = db;
        this.json = json;
    }

    public List<BookingSchemas.Field> fields(UUID category) {
        var saved = db.queryForList("SELECT fields FROM category_quantity_fields WHERE category_id = ?",
                String.class, category);
        if (!saved.isEmpty()) {
            return readFields(saved.getFirst());
        }
        var slugs = db.queryForList("SELECT slug FROM services WHERE category_id = ? AND deleted_at IS NULL",
                String.class, category);
        return defaultCategoryFields(slugs);
    }

    public List<BookingSchemas.Schema> all() {
        var rows = db.query("""
                SELECT s.slug, s.category_id,
                       c.fields AS category_fields, COALESCE(c.version, 0) AS category_version,
                       f.fields AS service_fields, COALESCE(f.version, 0) AS service_version
                FROM services s
                LEFT JOIN category_quantity_fields c ON c.category_id = s.category_id
                LEFT JOIN service_booking_fields f ON f.service_id = s.id
                WHERE s.deleted_at IS NULL
                """, (rs, row) -> new SchemaRow(
                rs.getString("slug"), rs.getObject("category_id", UUID.class),
                rs.getString("category_fields"), rs.getInt("category_version"),
                rs.getString("service_fields"), rs.getInt("service_version")));
        var byCategory = rows.stream().collect(Collectors.groupingBy(SchemaRow::category));
        var categoryFields = new LinkedHashMap<UUID, List<BookingSchemas.Field>>();
        var result = new ArrayList<BookingSchemas.Schema>(rows.size());
        for (var row : rows) {
            var original = originalSchema(row.slug());
            var fields = new ArrayList<>(row.serviceFields() == null
                    ? defaultServiceFields(original) : readFields(row.serviceFields()));
            var numbers = categoryFields.computeIfAbsent(row.category(), category ->
                    row.categoryFields() == null
                            ? defaultCategoryFields(byCategory.get(category).stream().map(SchemaRow::slug).toList())
                            : readFields(row.categoryFields()));
            for (var number : numbers) {
                if (fields.stream().noneMatch(field -> field.key().equals(number.key()))) {
                    fields.add(number);
                }
            }
            int version = row.categoryVersion() + 1 + 1000 * row.serviceVersion();
            String key = original == null ? "category-" + row.category() : original.key();
            result.add(new BookingSchemas.Schema(key, version, List.of(row.slug()), fields));
        }
        return result;
    }

    public List<BookingSchemas.Field> serviceFields(UUID service) {
        var saved = db.queryForList("SELECT fields FROM service_booking_fields WHERE service_id = ?",
                String.class, service);
        if (!saved.isEmpty()) {
            return readFields(saved.getFirst());
        }
        var slugs = db.queryForList("SELECT slug FROM services WHERE id = ?", String.class, service);
        return slugs.isEmpty() ? List.of() : defaultServiceFields(originalSchema(slugs.getFirst()));
    }

    public BookingSchemas.Schema require(String key, int version, String slug) {
        return all().stream()
                .filter(schema -> schema.key().equals(key) && schema.version() == version
                        && schema.serviceSlugs().contains(slug))
                .findFirst()
                .orElseThrow(() -> new DomainException("INVALID_BOOKING_DETAILS",
                        "Biểu mẫu đã thay đổi. Vui lòng tải lại dịch vụ.", HttpStatus.UNPROCESSABLE_ENTITY));
    }

    private List<BookingSchemas.Field> readFields(String fields) {
        return json.readValue(fields, new TypeReference<List<BookingSchemas.Field>>() {});
    }

    private static BookingSchemas.Schema originalSchema(String slug) {
        return BookingSchemas.ALL.stream().filter(schema -> schema.serviceSlugs().contains(slug))
                .findFirst().orElse(null);
    }

    private static List<BookingSchemas.Field> defaultServiceFields(BookingSchemas.Schema original) {
        return original == null ? List.of()
                : original.fields().stream().filter(field -> !field.type().equals("number")).toList();
    }

    private static List<BookingSchemas.Field> defaultCategoryFields(List<String> slugs) {
        var fields = new LinkedHashMap<String, BookingSchemas.Field>();
        for (var schema : BookingSchemas.ALL) {
            if (schema.serviceSlugs().stream().anyMatch(slugs::contains)) {
                for (var field : schema.fields()) {
                    if (field.type().equals("number") && !EXCLUDED_CATEGORY_FIELDS.contains(field.key())) {
                        fields.putIfAbsent(field.key(), field);
                    }
                }
            }
        }
        return List.copyOf(fields.values());
    }

    private record SchemaRow(String slug, UUID category, String categoryFields, int categoryVersion,
                             String serviceFields, int serviceVersion) {}
}
