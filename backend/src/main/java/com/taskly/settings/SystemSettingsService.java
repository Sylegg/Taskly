package com.taskly.settings;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class SystemSettingsService {
    private final JdbcTemplate db;
    private final Map<String, String> cache = new ConcurrentHashMap<>();

    public SystemSettingsService(JdbcTemplate db) {
        this.db = db;
    }

    public String getSetting(String key, String defaultValue) {
        String cached = cache.get(key);
        if (cached != null) return cached;
        var rows = db.queryForList("SELECT setting_value FROM system_settings WHERE setting_key = ?", String.class, key);
        if (rows.isEmpty()) return defaultValue;
        String val = rows.getFirst();
        cache.put(key, val);
        return val;
    }

    public int getIntSetting(String key, int defaultValue) {
        try {
            return Integer.parseInt(getSetting(key, String.valueOf(defaultValue)));
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    public void setSetting(String key, String value, String description) {
        int updated = db.update("""
            UPDATE system_settings
            SET setting_value = ?, description = COALESCE(?, description), updated_at = CURRENT_TIMESTAMP
            WHERE setting_key = ?
            """, value, description, key);
        if (updated == 0) {
            db.update("""
                INSERT INTO system_settings (setting_key, setting_value, description, updated_at)
                VALUES (?, ?, ?, CURRENT_TIMESTAMP)
                """, key, value, description);
        }
        cache.put(key, value);
    }

    public int getMinBufferMinutes() {
        return getIntSetting("partner.min_buffer_minutes", 60);
    }

    public int getTravelSafetyMinutes() {
        return getIntSetting("partner.travel_safety_minutes", 15);
    }

    public int getEarlyCheckinWindowMinutes() {
        int val = getIntSetting("partner.early_checkin_window_minutes", -1);
        if (val >= 0) return val;
        return getIntSetting("operations.early_checkin_window_minutes", 15);
    }

    public int getMaxEarlyStartMinutes() {
        int val = getIntSetting("partner.max_early_start_minutes", -1);
        if (val >= 0) return val;
        return getIntSetting("operations.max_early_start_minutes", 60);
    }

    public int getEarlyStartExpiryMinutes() {
        int val = getIntSetting("partner.early_start_expiry_minutes", -1);
        if (val >= 0) return val;
        return getIntSetting("operations.early_start_expiry_minutes", 15);
    }

    public Map<String, Object> getOperationsSettings() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("minBufferMinutes", getMinBufferMinutes());
        map.put("travelSafetyMinutes", getTravelSafetyMinutes());
        map.put("earlyCheckinWindowMinutes", getEarlyCheckinWindowMinutes());
        map.put("maxEarlyStartMinutes", getMaxEarlyStartMinutes());
        map.put("earlyStartExpiryMinutes", getEarlyStartExpiryMinutes());
        return map;
    }

    public Map<String, Object> updateOperationsSettings(int minBufferMinutes, int travelSafetyMinutes) {
        return updateOperationsSettings(minBufferMinutes, travelSafetyMinutes, null, null, null);
    }

    public Map<String, Object> updateOperationsSettings(
        int minBufferMinutes,
        int travelSafetyMinutes,
        Integer earlyCheckinWindowMinutes,
        Integer maxEarlyStartMinutes,
        Integer earlyStartExpiryMinutes
    ) {
        if (minBufferMinutes < 15 || minBufferMinutes > 360) {
            throw new IllegalArgumentException("Khoảng thời gian đệm tối thiểu phải từ 15 đến 360 phút.");
        }
        if (travelSafetyMinutes < 0 || travelSafetyMinutes > 180) {
            throw new IllegalArgumentException("Thời gian an toàn di chuyển phải từ 0 đến 180 phút.");
        }
        setSetting("partner.min_buffer_minutes", String.valueOf(minBufferMinutes), "Khoảng thời gian tối thiểu giữa 2 công việc của Partner (phút)");
        setSetting("partner.travel_safety_minutes", String.valueOf(travelSafetyMinutes), "Thời gian đệm an toàn di chuyển bổ sung (phút)");

        if (earlyCheckinWindowMinutes != null) {
            if (earlyCheckinWindowMinutes < 0 || earlyCheckinWindowMinutes > 120) {
                throw new IllegalArgumentException("Cửa sổ check-in sớm phải từ 0 đến 120 phút.");
            }
            setSetting("partner.early_checkin_window_minutes", String.valueOf(earlyCheckinWindowMinutes), "Khoảng thời gian cho phép check-in sớm trước giờ bắt đầu (phút)");
        }
        if (maxEarlyStartMinutes != null) {
            if (maxEarlyStartMinutes < 0 || maxEarlyStartMinutes > 240) {
                throw new IllegalArgumentException("Số phút tối đa được đề nghị bắt đầu sớm phải từ 0 đến 240 phút.");
            }
            setSetting("partner.max_early_start_minutes", String.valueOf(maxEarlyStartMinutes), "Số phút tối đa Partner được đề nghị bắt đầu sớm (phút)");
        }
        if (earlyStartExpiryMinutes != null) {
            if (earlyStartExpiryMinutes < 1 || earlyStartExpiryMinutes > 120) {
                throw new IllegalArgumentException("Thời hạn hết hạn của đề nghị bắt đầu sớm phải từ 1 đến 120 phút.");
            }
            setSetting("partner.early_start_expiry_minutes", String.valueOf(earlyStartExpiryMinutes), "Thời hạn tự động hết hạn của đề nghị bắt đầu sớm (phút)");
        }

        return getOperationsSettings();
    }
}
