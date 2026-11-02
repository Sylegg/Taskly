package com.taskly.catalogue;

import com.taskly.common.exception.DomainException;
import java.awt.AlphaComposite;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Set;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.MemoryCacheImageInputStream;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class ServiceIconProcessor {
    private static final Set<String> PRESET_KEYS = Set.of(
            "cleaning", "sparkles", "sofa", "bed", "aircon", "repair", "laundry", "kitchen",
            "assembly", "moving", "packing", "shopping", "pets", "computer", "wifi", "iron", "grid");
    private static final int MAX_IMAGE_BYTES = 1_048_576;
    private static final int MAX_DATA_URL_LENGTH = 1_400_000;
    private static final int MAX_INPUT_DIMENSION = 2048;
    private static final int MAX_ICON_DIMENSION = 256;
    private static final byte[] PNG_SIGNATURE = {(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};

    public String validateKey(String key) {
        if (key.isEmpty()) return null;
        if (!PRESET_KEYS.contains(key)) {
            throw invalid("SERVICE_ICON_KEY_INVALID", "Biểu tượng dịch vụ không hợp lệ. Hãy chọn một biểu tượng trong danh sách.");
        }
        return key;
    }

    public NormalizedIcon normalize(String dataUrl) {
        return normalize(dataUrl, MAX_IMAGE_BYTES, MAX_DATA_URL_LENGTH, MAX_INPUT_DIMENSION, MAX_ICON_DIMENSION);
    }
    public NormalizedIcon normalizeBanner(String dataUrl) {
        return normalize(dataUrl, 5_242_880, 7_000_000, 4096, 1920);
    }
    private NormalizedIcon normalize(String dataUrl, int maxBytes, int maxDataUrl, int maxInput, int maxOutput) {
        if (dataUrl.length() > maxDataUrl) {
            throw invalid("SERVICE_ICON_TOO_LARGE", "Ảnh vượt quá dung lượng cho phép.");
        }
        String prefix;
        boolean png;
        if (dataUrl.startsWith("data:image/png;base64,")) {
            prefix = "data:image/png;base64,"; png = true;
        } else if (dataUrl.startsWith("data:image/jpeg;base64,")) {
            prefix = "data:image/jpeg;base64,"; png = false;
        } else if (dataUrl.startsWith("data:image/jpg;base64,")) {
            prefix = "data:image/jpg;base64,"; png = false;
        } else {
            throw invalid("SERVICE_ICON_FORMAT_INVALID", "Chỉ hỗ trợ ảnh biểu tượng PNG hoặc JPG.");
        }
        byte[] input;
        try {
            input = Base64.getDecoder().decode(dataUrl.substring(prefix.length()));
        } catch (IllegalArgumentException exception) {
            throw invalid("SERVICE_ICON_DATA_INVALID", "Dữ liệu ảnh biểu tượng bị lỗi. Hãy tải lại ảnh PNG hoặc JPG.");
        }
        if (input.length > maxBytes) {
            throw invalid("SERVICE_ICON_TOO_LARGE", "Ảnh vượt quá dung lượng cho phép.");
        }
        if (!hasSignature(input, png)) {
            throw invalid("SERVICE_ICON_FORMAT_INVALID", "Nội dung ảnh không đúng định dạng PNG hoặc JPG đã chọn.");
        }
        BufferedImage decoded = decode(input, png, maxInput);
        double scale = Math.min(1.0, (double) maxOutput / Math.max(decoded.getWidth(), decoded.getHeight()));
        int width = Math.max(1, (int) Math.round(decoded.getWidth() * scale));
        int height = Math.max(1, (int) Math.round(decoded.getHeight() * scale));
        BufferedImage normalized = new BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB);
        Graphics2D graphics = normalized.createGraphics();
        try {
            graphics.setComposite(AlphaComposite.Src);
            graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
            graphics.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
            graphics.drawImage(decoded, 0, 0, width, height, null);
        } finally {
            graphics.dispose();
        }
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            if (!ImageIO.write(normalized, "png", output)) {
                throw new IllegalStateException("PNG encoder is unavailable");
            }
            byte[] bytes = output.toByteArray();
            return new NormalizedIcon(bytes, sha256(bytes));
        } catch (IOException exception) {
            throw invalid("SERVICE_ICON_DATA_INVALID", "Không thể xử lý ảnh biểu tượng. Hãy tải lại một ảnh khác.");
        }
    }

    private BufferedImage decode(byte[] input, boolean png, int maxInput) {
        try (ImageInputStream stream = new MemoryCacheImageInputStream(new ByteArrayInputStream(input))) {
            var readers = ImageIO.getImageReaders(stream);
            if (!readers.hasNext()) throw new IOException("Unsupported image content");
            ImageReader reader = readers.next();
            try {
                String format = reader.getFormatName();
                if (png ? !"png".equalsIgnoreCase(format) : !("jpeg".equalsIgnoreCase(format) || "jpg".equalsIgnoreCase(format))) {
                    throw new IOException("Image format mismatch");
                }
                reader.setInput(stream, true, true);
                int width = reader.getWidth(0);
                int height = reader.getHeight(0);
                if (width < 1 || height < 1 || width > maxInput || height > maxInput) {
                    throw invalid("SERVICE_ICON_DIMENSIONS_INVALID", "Kích thước ảnh vượt quá giới hạn cho phép.");
                }
                BufferedImage image = reader.read(0);
                if (image == null) throw new IOException("Invalid image data");
                return image;
            } finally {
                reader.dispose();
            }
        } catch (DomainException exception) {
            throw exception;
        } catch (IOException | RuntimeException exception) {
            throw invalid("SERVICE_ICON_DATA_INVALID", "Không thể đọc ảnh biểu tượng. Hãy tải lại một ảnh PNG hoặc JPG hợp lệ.");
        }
    }

    private boolean hasSignature(byte[] input, boolean png) {
        if (png) {
            if (input.length < PNG_SIGNATURE.length) return false;
            for (int index = 0; index < PNG_SIGNATURE.length; index++) {
                if (input[index] != PNG_SIGNATURE[index]) return false;
            }
            return true;
        }
        return input.length >= 5 && (input[0] & 0xff) == 0xff && (input[1] & 0xff) == 0xd8
                && (input[2] & 0xff) == 0xff && (input[input.length - 2] & 0xff) == 0xff
                && (input[input.length - 1] & 0xff) == 0xd9;
    }

    private String sha256(byte[] bytes) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    private DomainException invalid(String code, String message) {
        return new DomainException(code, message, HttpStatus.UNPROCESSABLE_ENTITY);
    }

    public record NormalizedIcon(byte[] pngBytes, String hash) {}
}
