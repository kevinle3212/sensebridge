import type { ThemeMode, Translations } from "./types";

const modeName: Record<ThemeMode, string> = {
  system: "hệ thống",
  light: "sáng",
  dark: "tối",
};

export const vi: Translations = {
  meta: {
    title: "SenseBridge — trợ năng mã nguồn mở, xử lý trên thiết bị và riêng tư",
    description:
      "SenseBridge là một ứng dụng iPhone miễn phí, mã nguồn mở, chuyển đổi môi trường xung quanh của người khiếm thị hoặc thị lực kém thành thông tin nói rõ ràng, được xử lý hoàn toàn trên thiết bị.",
  },
  layout: {
    skipLink: "Bỏ qua để đến nội dung chính",
  },
  header: {
    nav: {
      features: "Tính năng",
      privacy: "Quyền riêng tư",
      accessibility: "Trợ năng",
      github: "GitHub",
    },
    themeToggle: {
      modeName,
      // `current`/`next` are the closed `ThemeMode` union, not arbitrary input.
      ariaLabel: (current, next) =>
        // eslint-disable-next-line security/detect-object-injection
        `Giao diện: ${modeName[current]}. Kích hoạt để dùng giao diện ${modeName[next]}.`,
    },
    languageSwitcher: {
      label: "Ngôn ngữ",
    },
  },
  hero: {
    heading: "Cảm nhận nhiều hơn. Không chia sẻ gì cả.",
    lede: "SenseBridge là một ứng dụng iPhone miễn phí, mã nguồn mở, chuyển đổi môi trường xung quanh của người khiếm thị hoặc thị lực kém thành thông tin nói rõ ràng — được xử lý hoàn toàn trên thiết bị, để camera và môi trường xung quanh của bạn không bao giờ rời khỏi điện thoại.",
    status:
      "SenseBridge đang trong quá trình phát triển mở và chưa có sẵn để tải xuống. Bạn có thể theo dõi quá trình xây dựng trên GitHub ngay hôm nay.",
    visuallyHiddenDescription:
      "Nếu bạn đang nghe trang này thay vì nhìn thấy nó: hình minh họa ở đây cho thấy một tín hiệu di chuyển từ camera của điện thoại, qua một cây cầu cách điệu, và đến như một câu nói — cùng hành trình mà trang này mô tả.",
    cta: "Theo dõi tiến độ trên GitHub",
  },
  features: {
    heading: "Những gì nó làm được hôm nay",
    intro: "Năm khả năng, tất cả đều chạy hoàn toàn trên điện thoại.",
    items: [
      "Đọc to văn bản in và tài liệu.",
      "Nhận diện các vật thể và bề mặt thông thường.",
      "Mô tả một cảnh bằng một câu tự nhiên.",
      "Cung cấp nhận thức thận trọng về chướng ngại vật bằng LiDAR — không bao giờ là điều hướng.",
      "Thông báo các sự kiện âm thanh quan trọng gần đó.",
    ],
  },
  privacy: {
    heading: "Riêng tư nhờ kiến trúc, không phải nhờ chính sách",
    body: "Không có backend, không có hệ thống tài khoản, và không có telemetry theo mặc định. Nhận thức và suy luận chạy trên thiết bị; không có gì về môi trường xung quanh của bạn rời khỏi điện thoại nếu không có sự đồng ý rõ ràng và có thể thu hồi của bạn.",
    supporting:
      "Một chính sách quyền riêng tư có thể thay đổi. Một kiến trúc không có máy chủ thì không thể.",
  },
  accessibility: {
    heading: "Được xây dựng theo cách mà nó mong muốn được đánh giá",
    body: "Trang web này được xây dựng ưu tiên trình đọc màn hình, theo cùng tiêu chuẩn mà ứng dụng cam kết: cấu trúc ngữ nghĩa, mọi điều khiển đều có nhãn, hỗ trợ đầy đủ bàn phím, WCAG 2.2 AA. Nếu bạn dùng VoiceOver hoặc NVDA, trang này hẳn đã cảm thấy quen thuộc.",
    leadIn: "Bạn thích nghe hơn? Trang này có thể tự đọc to.",
  },
  readAloud: {
    deviceIdleLabel: "Nghe (giọng thiết bị)",
    naturalIdleLabel: "Nghe (giọng tự nhiên)",
    stopLabel: "Dừng đọc",
    readingPage: "Đang đọc trang…",
    finishedReading: "Đã đọc xong.",
    readingStopped: "Đã dừng đọc.",
    stopped: "Đã dừng.",
    readingPageNatural: "Đang đọc trang bằng giọng tự nhiên…",
    naturalPlaybackError: "Không thể phát bản đọc bằng giọng tự nhiên.",
  },
  bridge: {
    heading: "Được xây dựng đúng như tên gọi",
    body: "SenseBridge tồn tại để kết nối hai thứ: tín hiệu thô từ camera, và câu nói đơn giản mà một người đang cố nghe. Mọi thứ ở giữa — nhận thức, suy luận, hiển thị — là nhịp cầu đó, được lắp ráp hoàn toàn trên điện thoại của bạn.",
    supporting:
      "Không băng qua đám mây. Không có rào cản tài khoản. Chỉ là con đường ngắn nhất từ cảm nhận đến thấu hiểu.",
  },
  phone: {
    heading: "Toàn bộ hệ thống chính là chiếc điện thoại trong túi bạn",
    lede: "Không cần phần cứng bổ sung, không cần đám mây. SenseBridge đang được xây dựng để chạy hoàn toàn trên cảm biến và chip riêng của iPhone — đây là cách mỗi phần truyền tải tín hiệu.",
    diagramDescription:
      "Sơ đồ: một chiếc iPhone được vẽ dưới dạng khung dây tách thành ba lớp. Camera và máy quét LiDAR ở mặt sau ghi lại cảnh vật. Neural Engine ở giữa chạy các mô hình nhận thức và suy luận trên thiết bị. Loa và Taptic Engine ở mặt trước biến sự thấu hiểu thành giọng nói và rung nhẹ.",
    annotations: [
      {
        label: "01 · CẢM BIẾN",
        title: "Camera + LiDAR",
        body: "Ánh sáng và độ sâu đi vào đây. Camera và máy quét LiDAR lấy mẫu hình dạng của cảnh vật để ứng dụng có điều gì đó chân thực để mô tả. Trong kiến trúc, đây là ranh giới SensingSource — cánh cửa duy nhất mà thế giới đi vào.",
      },
      {
        label: "02 · SUY LUẬN",
        title: "Neural Engine",
        body: "Các mô hình trên thiết bị chuyển đổi pixel và độ sâu thành mô tả có rào chắn, bằng ngôn ngữ đơn giản. Nhận thức và suy luận chạy hoàn toàn trên chip của chính điện thoại — không có gì được tải lên, không có gì rời khỏi tay bạn.",
      },
      {
        label: "03 · HIỂN THỊ",
        title: "Loa + Taptic Engine",
        body: "Những gì điện thoại hiểu được sẽ trở lại dưới dạng giọng nói và rung nhẹ — ranh giới RenderTarget. Luôn được diễn đạt như nhận thức, không bao giờ là lời hứa về an toàn.",
      },
    ],
  },
  future: {
    kicker: "Một hướng đi tương lai — không phải một sản phẩm",
    heading: "Cây cầu có thể đi đến đâu tiếp theo",
    lede: "SenseBridge đang được xây dựng cho điện thoại trước tiên. Nhưng cùng một quy trình trên thiết bị — cảm nhận, suy luận, hiển thị — một ngày nào đó có thể chạy trên phần cứng nhẹ hơn, gần hơn với các giác quan mà nó phục vụ.",
    body: "Các thiết bị đeo như kính có camera có thể giúp những mô tả có rào chắn, riêng tư tương tự đến mà không cần dùng tay. Không có gì về tương lai đó được hứa hẹn; các ranh giới giao thức chỉ đơn giản là đang được thiết kế để điều đó vẫn khả thi.",
    illustrationDescription:
      "Minh họa: một cặp kính được vẽ dưới dạng khung dây trong mờ xoay chậm. Cứ vài giây, một chấm sáng xanh nhỏ di chuyển dọc khung — xuống một càng kính, quanh tròng kính đó, qua cầu kính, quanh tròng kính còn lại, rồi xuống càng kính xa — ấm dần sang màu hổ phách khi đến nơi.",
  },
  followProgress: {
    heading: "Được phát triển công khai",
    body: "Mọi điều quan trọng bạn vừa đọc đều có thể kiểm chứng: mã nguồn, các quyết định kiến trúc, và chặng đường còn lại đều công khai. Nếu SenseBridge khiến bạn quan tâm, cách để hành động ngay hôm nay là theo dõi quá trình xây dựng diễn ra.",
    link: "Theo dõi quá trình xây dựng trên GitHub",
  },
  footer: {
    tagline: "SenseBridge miễn phí và mã nguồn mở. Không bao giờ có phí đăng ký.",
    githubLink: "SenseBridge trên GitHub",
    notAvailable:
      "Chưa có sẵn trên App Store — SenseBridge đang ở giai đoạn trước khi ra mắt và đang trong quá trình phát triển mở.",
  },
  disclaimer: {
    ariaLabel: "Cảnh báo an toàn",
    text: "SenseBridge giúp bạn nhận thức rõ hơn về môi trường xung quanh. Đây không phải là thiết bị an toàn hỗ trợ di chuyển hay định hướng, và các mô tả của nó có thể sai — hãy luôn sử dụng cùng với phán đoán của chính bạn, gậy dò đường, hoặc chó dẫn đường.",
  },
};
