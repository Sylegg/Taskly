// Danh mục 63 Tỉnh / Thành phố và các Quận / Huyện của Việt Nam chuẩn hóa
export type VietnamProvince = {
  name: string;
  region: 'Miền Bắc' | 'Miền Trung' | 'Miền Nam';
  districts: string[];
};

export const VIETNAM_PROVINCES: VietnamProvince[] = [
  {
    "name": "Hà Nội",
    "region": "Miền Bắc",
    "districts": [
      "Ba Đình",
      "Hoàn Kiếm",
      "Tây Hồ",
      "Long Biên",
      "Cầu Giấy",
      "Đống Đa",
      "Hai Bà Trưng",
      "Hoàng Mai",
      "Thanh Xuân",
      "Sóc Sơn",
      "Đông Anh",
      "Gia Lâm",
      "Nam Từ Liêm",
      "Thanh Trì",
      "Bắc Từ Liêm",
      "Mê Linh",
      "Hà Đông",
      "Thị xã Sơn Tây",
      "Ba Vì",
      "Phúc Thọ",
      "Đan Phượng",
      "Hoài Đức",
      "Quốc Oai",
      "Thạch Thất",
      "Chương Mỹ",
      "Thanh Oai",
      "Thường Tín",
      "Phú Xuyên",
      "Ứng Hòa",
      "Mỹ Đức"
    ]
  },
  {
    "name": "Hải Phòng",
    "region": "Miền Bắc",
    "districts": [
      "Hồng Bàng",
      "Ngô Quyền",
      "Lê Chân",
      "Hải An",
      "Kiến An",
      "Đồ Sơn",
      "Dương Kinh",
      "An Dương",
      "An Lão",
      "Kiến Thụy",
      "Thủy Nguyên",
      "Tiên Lãng",
      "Vĩnh Bảo",
      "Cát Hải",
      "Bạch Long Vĩ"
    ]
  },
  {
    "name": "Bắc Ninh",
    "region": "Miền Bắc",
    "districts": [
      "TP. Bắc Ninh",
      "TP. Từ Sơn",
      "TX. Quế Võ",
      "TX. Thuận Thành",
      "Gia Bình",
      "Lương Tài",
      "Tiên Du",
      "Yên Phong"
    ]
  },
  {
    "name": "Hải Dương",
    "region": "Miền Bắc",
    "districts": [
      "TP. Hải Dương",
      "TP. Chí Linh",
      "TX. Kinh Môn",
      "Bình Giang",
      "Cẩm Giàng",
      "Gia Lộc",
      "Kim Thành",
      "Nam Sách",
      "Ninh Giang",
      "Thanh Hà",
      "Thanh Miện",
      "Tứ Kỳ"
    ]
  },
  {
    "name": "Hưng Yên",
    "region": "Miền Bắc",
    "districts": [
      "TP. Hưng Yên",
      "TX. Mỹ Hào",
      "Ân Thi",
      "Khoái Châu",
      "Kim Động",
      "Phù Cừ",
      "Tiên Lữ",
      "Văn Giang",
      "Văn Lâm",
      "Yên Mỹ"
    ]
  },
  {
    "name": "Quảng Ninh",
    "region": "Miền Bắc",
    "districts": [
      "TP. Hạ Long",
      "TP. Cẩm Phả",
      "TP. Móng Cái",
      "TP. Uông Bí",
      "TX. Đông Triều",
      "TX. Quảng Yên",
      "Ba Chẽ",
      "Bình Liêu",
      "Cô Tô",
      "Đầm Hà",
      "Hải Hà",
      "Tiên Yên",
      "Vân Đồn"
    ]
  },
  {
    "name": "Vĩnh Phúc",
    "region": "Miền Bắc",
    "districts": [
      "TP. Vĩnh Yên",
      "TP. Phúc Yên",
      "Bình Xuyên",
      "Lập Thạch",
      "Sông Lô",
      "Tam Đảo",
      "Tam Dương",
      "Vĩnh Tường",
      "Yên Lạc"
    ]
  },
  {
    "name": "Thái Nguyên",
    "region": "Miền Bắc",
    "districts": [
      "TP. Thái Nguyên",
      "TP. Sông Công",
      "TP. Phổ Yên",
      "Đại Từ",
      "Định Hóa",
      "Đồng Hỷ",
      "Phú Bình",
      "Phú Lương",
      "Võ Nhai"
    ]
  },
  {
    "name": "Bắc Giang",
    "region": "Miền Bắc",
    "districts": [
      "TP. Bắc Giang",
      "TX. Việt Yên",
      "Hiệp Hòa",
      "Lạng Giang",
      "Lục Nam",
      "Lục Ngạn",
      "Sơn Động",
      "Tân Yên",
      "Yên Dũng",
      "Yên Thế"
    ]
  },
  {
    "name": "Hà Nam",
    "region": "Miền Bắc",
    "districts": [
      "TP. Phủ Lý",
      "TX. Duy Tiên",
      "Bình Lục",
      "Kim Bảng",
      "Lý Nhân",
      "Thanh Liêm"
    ]
  },
  {
    "name": "Nam Định",
    "region": "Miền Bắc",
    "districts": [
      "TP. Nam Định",
      "Giao Thủy",
      "Hải Hậu",
      "Mỹ Lộc",
      "Nam Trực",
      "Nghĩa Hưng",
      "Trực Ninh",
      "Vụ Bản",
      "Xuân Trường",
      "Ý Yên"
    ]
  },
  {
    "name": "Thái Bình",
    "region": "Miền Bắc",
    "districts": [
      "TP. Thái Bình",
      "Đông Hưng",
      "Hưng Hà",
      "Kiến Xương",
      "Quỳnh Phụ",
      "Thái Thụy",
      "Tiền Hải",
      "Vũ Thư"
    ]
  },
  {
    "name": "Ninh Bình",
    "region": "Miền Bắc",
    "districts": [
      "TP. Ninh Bình",
      "TP. Tam Điệp",
      "Gia Viễn",
      "Hoa Lư",
      "Kim Sơn",
      "Nho Quan",
      "Yên Khánh",
      "Yên Mô"
    ]
  },
  {
    "name": "Phú Thọ",
    "region": "Miền Bắc",
    "districts": [
      "TP. Việt Trì",
      "TX. Phú Thọ",
      "Cẩm Khê",
      "Đoan Hùng",
      "Hạ Hòa",
      "Lâm Thao",
      "Phù Ninh",
      "Tam Nông",
      "Tân Sơn",
      "Thanh Ba",
      "Thanh Sơn",
      "Thanh Thủy",
      "Yên Lập"
    ]
  },
  {
    "name": "Lào Cai",
    "region": "Miền Bắc",
    "districts": [
      "TP. Lào Cai",
      "TX. Sa Pa",
      "Bát Xát",
      "Bảo Thắng",
      "Bảo Yên",
      "Bắc Hà",
      "Mường Khương",
      "Si Ma Cai",
      "Văn Bàn"
    ]
  },
  {
    "name": "Yên Bái",
    "region": "Miền Bắc",
    "districts": [
      "TP. Yên Bái",
      "TX. Nghĩa Lộ",
      "Lục Yên",
      "Mù Cang Chải",
      "Trạm Tấu",
      "Trấn Yên",
      "Văn Chấn",
      "Văn Yên",
      "Yên Bình"
    ]
  },
  {
    "name": "Hòa Bình",
    "region": "Miền Bắc",
    "districts": [
      "TP. Hòa Bình",
      "Cao Phong",
      "Đà Bắc",
      "Kim Bôi",
      "Lạc Sơn",
      "Lạc Thủy",
      "Lương Sơn",
      "Mai Châu",
      "Tân Lạc",
      "Yên Thủy"
    ]
  },
  {
    "name": "Sơn La",
    "region": "Miền Bắc",
    "districts": [
      "TP. Sơn La",
      "Bắc Yên",
      "Mai Sơn",
      "Mộc Châu",
      "Mường La",
      "Phù Yên",
      "Quỳnh Nhai",
      "Sông Mã",
      "Sốp Cộp",
      "Thuận Châu",
      "Vân Hồ",
      "Yên Châu"
    ]
  },
  {
    "name": "Điện Biên",
    "region": "Miền Bắc",
    "districts": [
      "TP. Điện Biên Phủ",
      "TX. Mường Lay",
      "Điện Biên",
      "Điện Biên Đông",
      "Mường Ảng",
      "Mường Chà",
      "Mường Nhé",
      "Nậm Pồ",
      "Tủa Chùa",
      "Tuần Giáo"
    ]
  },
  {
    "name": "Lai Châu",
    "region": "Miền Bắc",
    "districts": [
      "TP. Lai Châu",
      "Mường Tè",
      "Nậm Nhùn",
      "Phong Thổ",
      "Sìn Hồ",
      "Tam Đường",
      "Tân Uyên",
      "Than Uyên"
    ]
  },
  {
    "name": "Hà Giang",
    "region": "Miền Bắc",
    "districts": [
      "TP. Hà Giang",
      "Bắc Mê",
      "Bắc Quang",
      "Đồng Văn",
      "Hoàng Su Phì",
      "Mèo Vạc",
      "Quản Bạ",
      "Quang Bình",
      "Vị Xuyên",
      "Xín Mần",
      "Yên Minh"
    ]
  },
  {
    "name": "Cao Bằng",
    "region": "Miền Bắc",
    "districts": [
      "TP. Cao Bằng",
      "Bảo Lạc",
      "Bảo Lâm",
      "Hạ Lang",
      "Hà Quảng",
      "Hòa An",
      "Nguyên Bình",
      "Quảng Hòa",
      "Thạch An",
      "Trùng Khánh"
    ]
  },
  {
    "name": "Bắc Kạn",
    "region": "Miền Bắc",
    "districts": [
      "TP. Bắc Kạn",
      "Ba Bể",
      "Bạch Thông",
      "Chợ Đồn",
      "Chợ Mới",
      "Na Rì",
      "Ngân Sơn",
      "Pác Nặm"
    ]
  },
  {
    "name": "Lạng Sơn",
    "region": "Miền Bắc",
    "districts": [
      "TP. Lạng Sơn",
      "Bắc Sơn",
      "Bình Gia",
      "Cao Lộc",
      "Chi Lăng",
      "Đình Lập",
      "Hữu Lũng",
      "Lộc Bình",
      "Tràng Định",
      "Văn Lãng",
      "Văn Quan"
    ]
  },
  {
    "name": "Tuyên Quang",
    "region": "Miền Bắc",
    "districts": [
      "TP. Tuyên Quang",
      "Chiêm Hóa",
      "Hàm Yên",
      "Lâm Bình",
      "Na Hang",
      "Sơn Dương",
      "Yên Sơn"
    ]
  },
  {
    "name": "Đà Nẵng",
    "region": "Miền Trung",
    "districts": [
      "Hải Châu",
      "Thanh Khê",
      "Sơn Trà",
      "Ngũ Hành Sơn",
      "Liên Chiểu",
      "Cẩm Lệ",
      "Hòa Vang",
      "Hoàng Sa"
    ]
  },
  {
    "name": "Thừa Thiên Huế",
    "region": "Miền Trung",
    "districts": [
      "TP. Huế",
      "TX. Hương Thủy",
      "TX. Hương Trà",
      "A Lưới",
      "Nam Đông",
      "Phong Điền",
      "Phú Lộc",
      "Phú Vang",
      "Quảng Điền"
    ]
  },
  {
    "name": "Khánh Hòa",
    "region": "Miền Trung",
    "districts": [
      "TP. Nha Trang",
      "TP. Cam Ranh",
      "TX. Ninh Hòa",
      "Cam Lâm",
      "Diên Khánh",
      "Khánh Sơn",
      "Khánh Vĩnh",
      "Trường Sa",
      "Vạn Ninh"
    ]
  },
  {
    "name": "Thanh Hóa",
    "region": "Miền Trung",
    "districts": [
      "TP. Thanh Hóa",
      "TP. Sầm Sơn",
      "TX. Bỉm Sơn",
      "TX. Nghi Sơn",
      "Bá Thước",
      "Cẩm Thủy",
      "Đông Sơn",
      "Hà Trung",
      "Hậu Lộc",
      "Hoằng Hóa",
      "Lang Chánh",
      "Mường Lát",
      "Nga Sơn",
      "Ngọc Lặc",
      "Như Thanh",
      "Như Xuân",
      "Nông Cống",
      "Quan Hóa",
      "Quan Sơn",
      "Quảng Xương",
      "Thạch Thành",
      "Thiệu Hóa",
      "Thọ Xuân",
      "Thường Xuân",
      "Triệu Sơn",
      "Vĩnh Lộc",
      "Yên Định"
    ]
  },
  {
    "name": "Nghệ An",
    "region": "Miền Trung",
    "districts": [
      "TP. Vinh",
      "TX. Cửa Lò",
      "TX. Hoàng Mai",
      "TX. Thái Hòa",
      "Anh Sơn",
      "Con Cuông",
      "Diễn Châu",
      "Đô Lương",
      "Hưng Nguyên",
      "Kỳ Sơn",
      "Nam Đàn",
      "Nghi Lộc",
      "Nghĩa Đàn",
      "Quế Phong",
      "Quỳ Châu",
      "Quỳ Hợp",
      "Quỳnh Lưu",
      "Tân Kỳ",
      "Thanh Chương",
      "Tương Dương",
      "Yên Thành"
    ]
  },
  {
    "name": "Hà Tĩnh",
    "region": "Miền Trung",
    "districts": [
      "TP. Hà Tĩnh",
      "TX. Hồng Lĩnh",
      "TX. Kỳ Anh",
      "Cẩm Xuyên",
      "Can Lộc",
      "Đức Thọ",
      "Hương Khê",
      "Hương Sơn",
      "Kỳ Anh",
      "Lộc Hà",
      "Nghi Xuân",
      "Thạch Hà",
      "Vũ Quang"
    ]
  },
  {
    "name": "Quảng Bình",
    "region": "Miền Trung",
    "districts": [
      "TP. Đồng Hới",
      "TX. Ba Đồn",
      "Bố Trạch",
      "Lệ Thủy",
      "Minh Hóa",
      "Quảng Ninh",
      "Quảng Trạch",
      "Tuyên Hóa"
    ]
  },
  {
    "name": "Quảng Trị",
    "region": "Miền Trung",
    "districts": [
      "TP. Đông Hà",
      "TX. Quảng Trị",
      "Cam Lộ",
      "Cồn Cỏ",
      "Đakrông",
      "Gio Linh",
      "Hải Lăng",
      "Hướng Hóa",
      "Triệu Phong",
      "Vĩnh Linh"
    ]
  },
  {
    "name": "Quảng Nam",
    "region": "Miền Trung",
    "districts": [
      "TP. Tam Kỳ",
      "TP. Hội An",
      "TX. Điện Bàn",
      "Bắc Trà My",
      "Duy Xuyên",
      "Đại Lộc",
      "Đông Giang",
      "Hiệp Đức",
      "Nam Giang",
      "Nam Trà My",
      "Nông Sơn",
      "Núi Thành",
      "Phú Ninh",
      "Phước Sơn",
      "Quế Sơn",
      "Tây Giang",
      "Thăng Bình",
      "Tiên Phước"
    ]
  },
  {
    "name": "Quảng Ngãi",
    "region": "Miền Trung",
    "districts": [
      "TP. Quảng Ngãi",
      "TX. Đức Phổ",
      "Ba Tơ",
      "Bình Sơn",
      "Lý Sơn",
      "Minh Long",
      "Mộ Đức",
      "Nghĩa Hành",
      "Sơn Hà",
      "Sơn Tây",
      "Sơn Tịnh",
      "Trà Bồng",
      "Tư Nghĩa"
    ]
  },
  {
    "name": "Bình Định",
    "region": "Miền Trung",
    "districts": [
      "TP. Quy Nhơn",
      "TX. An Nhơn",
      "TX. Hoài Nhơn",
      "An Lão",
      "Hoài Ân",
      "Phù Cát",
      "Phù Mỹ",
      "Tây Sơn",
      "Tuy Phước",
      "Vân Canh",
      "Vĩnh Thạnh"
    ]
  },
  {
    "name": "Phú Yên",
    "region": "Miền Trung",
    "districts": [
      "TP. Tuy Hòa",
      "TX. Sông Cầu",
      "TX. Đông Hòa",
      "Đồng Xuân",
      "Phú Hòa",
      "Sơn Hòa",
      "Sông Hinh",
      "Tây Hòa",
      "Tuy An"
    ]
  },
  {
    "name": "Ninh Thuận",
    "region": "Miền Trung",
    "districts": [
      "TP. Phan Rang - Tháp Chàm",
      "Bác Ái",
      "Ninh Hải",
      "Ninh Phước",
      "Ninh Sơn",
      "Thuận Bắc",
      "Thuận Nam"
    ]
  },
  {
    "name": "Bình Thuận",
    "region": "Miền Trung",
    "districts": [
      "TP. Phan Thiết",
      "TX. La Gi",
      "Bắc Bình",
      "Đức Linh",
      "Hàm Tân",
      "Hàm Thuận Bắc",
      "Hàm Thuận Nam",
      "Phú Quý",
      "Tánh Linh",
      "Tuy Phong"
    ]
  },
  {
    "name": "Kon Tum",
    "region": "Miền Trung",
    "districts": [
      "TP. Kon Tum",
      "Đắk Glei",
      "Đắk Hà",
      "Đắk Tô",
      "Ia H\\'Drai",
      "Kon Plông",
      "Kon Rẫy",
      "Ngọc Hồi",
      "Sa Thầy",
      "Tu Mơ Rông"
    ]
  },
  {
    "name": "Gia Lai",
    "region": "Miền Trung",
    "districts": [
      "TP. Pleiku",
      "TX. An Khê",
      "TX. Ayun Pa",
      "Chư Păh",
      "Chư Prông",
      "Chư Pưh",
      "Chư Sê",
      "Đắk Đoa",
      "Đắk Pơ",
      "Đức Cơ",
      "Ia Grai",
      "Ia Pa",
      "KBang",
      "Kông Chro",
      "Krông Pa",
      "Mang Yang",
      "Phú Thiện"
    ]
  },
  {
    "name": "Đắk Lắk",
    "region": "Miền Trung",
    "districts": [
      "TP. Buôn Ma Thuột",
      "TX. Buôn Hồ",
      "Buôn Đôn",
      "Cư Kuin",
      "Cư M\\'gar",
      "Ea H\\'leo",
      "Ea Kar",
      "Ea Súp",
      "Krông Ana",
      "Krông Bông",
      "Krông Búk",
      "Krông Năng",
      "Krông Pắc",
      "Lắk",
      "M\\'Drắk"
    ]
  },
  {
    "name": "Đắk Nông",
    "region": "Miền Trung",
    "districts": [
      "TP. Gia Nghĩa",
      "Cư Jút",
      "Đắk Glong",
      "Đắk Mil",
      "Đắk R\\'lấp",
      "Đắk Song",
      "Krông Nô",
      "Tuy Đức"
    ]
  },
  {
    "name": "Lâm Đồng",
    "region": "Miền Trung",
    "districts": [
      "TP. Đà Lạt",
      "TP. Bảo Lộc",
      "Bảo Lâm",
      "Cát Tiên",
      "Di Linh",
      "Đạ Huoai",
      "Đạ Tẻh",
      "Đam Rông",
      "Đơn Dương",
      "Đức Trọng",
      "Lạc Dương",
      "Lâm Hà"
    ]
  },
  {
    "name": "TP. Hồ Chí Minh",
    "region": "Miền Nam",
    "districts": [
      "Quận 1",
      "Quận 3",
      "Quận 4",
      "Quận 5",
      "Quận 6",
      "Quận 7",
      "Quận 8",
      "Quận 10",
      "Quận 11",
      "Quận 12",
      "Bình Tân",
      "Bình Thạnh",
      "Gò Vấp",
      "Phú Nhuận",
      "Tân Bình",
      "Tân Phú",
      "TP. Thủ Đức",
      "Huyện Bình Chánh",
      "Huyện Cần Giờ",
      "Huyện Củ Chi",
      "Huyện Hóc Môn",
      "Huyện Nhà Bè"
    ]
  },
  {
    "name": "Bình Dương",
    "region": "Miền Nam",
    "districts": [
      "TP. Thủ Dầu Một",
      "TP. Dĩ An",
      "TP. Thuận An",
      "TP. Tân Uyên",
      "TP. Bến Cát",
      "Bàu Bàng",
      "Bắc Tân Uyên",
      "Dầu Tiếng",
      "Phú Giáo"
    ]
  },
  {
    "name": "Đồng Nai",
    "region": "Miền Nam",
    "districts": [
      "TP. Biên Hòa",
      "TP. Long Khánh",
      "Long Thành",
      "Nhơn Trạch",
      "Trảng Bom",
      "Vĩnh Cửu",
      "Cẩm Mỹ",
      "Định Quán",
      "Thống Nhất",
      "Tân Phú",
      "Xuân Lộc"
    ]
  },
  {
    "name": "Bà Rịa - Vũng Tàu",
    "region": "Miền Nam",
    "districts": [
      "TP. Vũng Tàu",
      "TP. Bà Rịa",
      "TX. Phú Mỹ",
      "Châu Đức",
      "Côn Đảo",
      "Đất Đỏ",
      "Long Điền",
      "Xuyên Mộc"
    ]
  },
  {
    "name": "Cần Thơ",
    "region": "Miền Nam",
    "districts": [
      "Ninh Kiều",
      "Bình Thủy",
      "Cái Răng",
      "Ô Môn",
      "Thốt Nốt",
      "Phong Điền",
      "Cờ Đỏ",
      "Thới Lai",
      "Vĩnh Thạnh"
    ]
  },
  {
    "name": "Long An",
    "region": "Miền Nam",
    "districts": [
      "TP. Tân An",
      "TX. Kiến Tường",
      "Bến Lức",
      "Cần Đước",
      "Cần Giuộc",
      "Châu Thành",
      "Đức Hòa",
      "Đức Huệ",
      "Mộc Hóa",
      "Tân Hưng",
      "Tân Thạnh",
      "Tân Trụ",
      "Thạnh Hóa",
      "Thủ Thừa",
      "Vĩnh Hưng"
    ]
  },
  {
    "name": "Tiền Giang",
    "region": "Miền Nam",
    "districts": [
      "TP. Mỹ Tho",
      "TX. Gò Công",
      "TX. Cai Lậy",
      "Cái Bè",
      "Cai Lậy",
      "Châu Thành",
      "Chợ Gạo",
      "Gò Công Đông",
      "Gò Công Tây",
      "Tân Phú Đông",
      "Tân Phước"
    ]
  },
  {
    "name": "Bến Tre",
    "region": "Miền Nam",
    "districts": [
      "TP. Bến Tre",
      "Ba Tri",
      "Bình Đại",
      "Châu Thành",
      "Chợ Lách",
      "Giồng Trôm",
      "Mỏ Cày Bắc",
      "Mỏ Cày Nam",
      "Thạnh Phú"
    ]
  },
  {
    "name": "Đồng Tháp",
    "region": "Miền Nam",
    "districts": [
      "TP. Cao Lãnh",
      "TP. Sa Đéc",
      "TP. Hồng Ngự",
      "Cao Lãnh",
      "Châu Thành",
      "Hồng Ngự",
      "Lai Vung",
      "Lấp Vò",
      "Tam Nông",
      "Tân Hồng",
      "Thanh Bình",
      "Tháp Mười"
    ]
  },
  {
    "name": "An Giang",
    "region": "Miền Nam",
    "districts": [
      "TP. Long Xuyên",
      "TP. Châu Đốc",
      "TX. Tân Châu",
      "TX. Tịnh Biên",
      "An Phú",
      "Châu Phú",
      "Châu Thành",
      "Chợ Mới",
      "Phú Tân",
      "Thoại Sơn",
      "Tri Tôn"
    ]
  },
  {
    "name": "Kiên Giang",
    "region": "Miền Nam",
    "districts": [
      "TP. Rạch Giá",
      "TP. Hà Tiên",
      "TP. Phú Quốc",
      "An Biên",
      "An Minh",
      "Châu Thành",
      "Giang Thành",
      "Giồng Riềng",
      "Gò Quao",
      "Hòn Đất",
      "Kiên Hải",
      "Kiên Lương",
      "Tân Hiệp",
      "U Minh Thượng",
      "Vĩnh Thuận"
    ]
  },
  {
    "name": "Vĩnh Long",
    "region": "Miền Nam",
    "districts": [
      "TP. Vĩnh Long",
      "TX. Bình Minh",
      "Bình Tân",
      "Long Hồ",
      "Mang Thít",
      "Tam Bình",
      "Trà Ôn",
      "Vũng Liêm"
    ]
  },
  {
    "name": "Trà Vinh",
    "region": "Miền Nam",
    "districts": [
      "TP. Trà Vinh",
      "TX. Duyên Hải",
      "Càng Long",
      "Cầu Kè",
      "Cầu Ngang",
      "Châu Thành",
      "Duyên Hải",
      "Tiểu Cần",
      "Trà Cú"
    ]
  },
  {
    "name": "Hậu Giang",
    "region": "Miền Nam",
    "districts": [
      "TP. Vị Thanh",
      "TP. Ngã Bảy",
      "TX. Long Mỹ",
      "Châu Thành",
      "Châu Thành A",
      "Phụng Hiệp",
      "Vị Thủy",
      "Long Mỹ"
    ]
  },
  {
    "name": "Sóc Trăng",
    "region": "Miền Nam",
    "districts": [
      "TP. Sóc Trăng",
      "TX. Ngã Năm",
      "TX. Vĩnh Châu",
      "Châu Thành",
      "Cù Lao Dung",
      "Kế Sách",
      "Long Phú",
      "Mỹ Tú",
      "Mỹ Xuyên",
      "Thạnh Trị",
      "Trần Đề"
    ]
  },
  {
    "name": "Bạc Liêu",
    "region": "Miền Nam",
    "districts": [
      "TP. Bạc Liêu",
      "TX. Giá Rai",
      "Đông Hải",
      "Hòa Bình",
      "Hồng Dân",
      "Phước Long",
      "Vĩnh Lợi"
    ]
  },
  {
    "name": "Cà Mau",
    "region": "Miền Nam",
    "districts": [
      "TP. Cà Mau",
      "Cái Nước",
      "Đầm Dơi",
      "Năm Căn",
      "Ngọc Hiển",
      "Phú Tân",
      "Thới Bình",
      "Trần Văn Thời",
      "U Minh"
    ]
  },
  {
    "name": "Tây Ninh",
    "region": "Miền Nam",
    "districts": [
      "TP. Tây Ninh",
      "TX. Hòa Thành",
      "TX. Trảng Bàng",
      "Bến Cầu",
      "Châu Thành",
      "Dương Minh Châu",
      "Gò Dầu",
      "Tân Biên",
      "Tân Châu"
    ]
  },
  {
    "name": "Bình Phước",
    "region": "Miền Nam",
    "districts": [
      "TP. Đồng Xoài",
      "TX. Bình Long",
      "TX. Phước Long",
      "TX. Chơn Thành",
      "Bù Đăng",
      "Bù Đốp",
      "Bù Gia Mập",
      "Đồng Phú",
      "Hớn Quản",
      "Lộc Ninh",
      "Phú Riềng"
    ]
  }
];

export const ALL_CITY_NAMES: string[] = VIETNAM_PROVINCES.map(p => p.name);

export function getDistricts(cityName: string): string[] {
  const p = VIETNAM_PROVINCES.find(prov => prov.name.toLowerCase() === cityName.toLowerCase());
  return p ? p.districts : [];
}

export function getRegion(cityName: string): string {
  const p = VIETNAM_PROVINCES.find(prov => prov.name.toLowerCase() === cityName.toLowerCase());
  return p ? p.region : '';
}
