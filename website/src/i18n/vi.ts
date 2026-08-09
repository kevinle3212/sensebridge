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
    fullNoticeLink: "Đọc thông báo đầy đủ về quyền riêng tư và dữ liệu",
  },
  monitoring: {
    controlLabel: "Giám sát lỗi",
    stateOn: "Bật — báo cáo được gửi khi một trang gặp lỗi",
    stateOff: "Tắt — không có gì được gửi đi",
    noScript:
      "Công tắc này cần JavaScript. Khi tắt JavaScript, việc giám sát lỗi cũng không thể chạy, nên không có gì được thu thập.",
    globalPrivacyControl:
      "Trình duyệt của bạn đang gửi tín hiệu Global Privacy Control, nên việc giám sát lỗi vẫn tắt và công tắc này không hiển thị. Không có gì được thu thập.",
  },
  privacyPage: {
    title: "Quyền riêng tư và dữ liệu — SenseBridge",
    description:
      "Trang web này thu thập gì, không thu thập gì, và cách bật hoặc tắt giám sát lỗi. Không cookie, không phân tích, không quảng cáo.",
    heading: "Quyền riêng tư và dữ liệu",
    lede: "Theo mặc định, trang web này không thu thập bất cứ điều gì về bạn. Dưới đây là chính xác điều đó có nghĩa là gì, điều gì thay đổi nếu bạn chọn khác đi, và cách đổi ý.",
    updated: "Cập nhật lần cuối",
    authoritative:
      "Thông báo này được công bố bằng nhiều ngôn ngữ. Nếu có khác biệt, bản tiếng Anh là bản có hiệu lực.",
    choiceHeading: "Lựa chọn của bạn",
    choiceBody:
      "Giám sát lỗi luôn tắt cho đến khi bạn bật nó. Khi bật, nó gửi một báo cáo mỗi khi một trang trên trang web này gặp lỗi: điều gì đã sai và ở đâu trong mã của chúng tôi, không bao giờ là bạn là ai. Tắt lại sẽ dừng ngay lập tức.",
    choiceUnconfigured:
      "Bản triển khai này không có cấu hình giám sát lỗi nào, nên không có gì để bật và không có gì được thu thập.",
    sections: [
      {
        heading: "Bản tóm tắt",
        body: [
          "Không cookie. Không phân tích. Không quảng cáo. Không pixel theo dõi. Không lập hồ sơ. Không bán bất cứ thứ gì, và không chia sẻ bất cứ thứ gì cho hoạt động tiếp thị của bên khác.",
          "Điều duy nhất trang web này có thể gửi đi về lần truy cập của bạn là báo cáo rằng một trang đã gặp lỗi, và chỉ khi bạn bật nó ở trên.",
        ],
      },
      {
        heading: "Những gì được lưu trên thiết bị của bạn",
        body: [
          "Chỉ những tuỳ chọn do chính bạn đặt. Không mục nào là danh tính nhận dạng, không mục nào trang web khác đọc được, và không mục nào từng được truyền đi đâu cả:",
        ],
        bullets: [
          "Việc bạn đã bật hay tắt giám sát lỗi, sau khi bạn dùng công tắc ở trên.",
          "Giao diện sáng hay tối, nếu bạn đổi khác với mặc định của hệ thống.",
          "Một cờ gỡ lỗi dành cho nhà phát triển, chỉ khi bạn tự đặt bằng tay.",
        ],
      },
      {
        heading: "Máy chủ web nhìn thấy gì",
        body: [
          "Như mọi máy chủ web trên internet, máy chủ phục vụ các trang này xử lý địa chỉ IP của bạn, trang bạn yêu cầu, chuỗi user-agent của trình duyệt và thời điểm truy cập, bởi không có chúng thì không thể gửi trang cho bạn. Trang web này được lưu trữ trên Vercel.",
          "Dữ liệu đó chỉ dùng để phục vụ trang và bảo vệ trang web khỏi lạm dụng. Nó không được kết hợp với bất cứ thứ gì khác, không dùng để dựng hồ sơ về bạn, và chúng tôi không giữ bản sao nào.",
        ],
      },
      {
        heading: "Nếu bạn bật giám sát lỗi",
        body: [
          "Chỉ khi đó trang web mới tải Sentry, một dịch vụ báo cáo lỗi. Cho đến khi bạn đồng ý, mã đó không bao giờ được tải xuống: không phải tải rồi tắt, không phải có mặt rồi nằm im. Là hoàn toàn không có.",
        ],
        bullets: [
          "Được gửi khi một trang gặp lỗi: thông báo lỗi, vị trí trong mã của chúng tôi nơi nó phát sinh, đường dẫn trang không kèm chuỗi truy vấn, phiên bản trình duyệt và hệ điều hành, và kích thước màn hình của bạn.",
          "Không bao giờ được gửi: tên bạn, địa chỉ email, địa chỉ IP, cookie, vị trí, nội dung bạn đã nhập, hay bất kỳ bản ghi nào về màn hình hoặc thao tác nhấp của bạn.",
          "Session Replay, theo dõi hiệu năng, breadcrumb và tiện ích phản hồi đều bị tắt ngay trong mã, chứ không chỉ là không dùng đến.",
        ],
      },
      {
        heading: "Vì sao, và trên cơ sở pháp lý nào",
        body: [
          "Với người truy cập ở Vương quốc Anh, EEA và Thuỵ Sĩ, GDPR và UK GDPR yêu cầu nêu rõ cơ sở pháp lý cho từng mục đích:",
        ],
        bullets: [
          "Giám sát lỗi — sự đồng ý của bạn, theo Điều 6(1)(a). Bạn có thể rút lại bất cứ lúc nào bằng công tắc ở trên, dễ đúng bằng lúc bạn đồng ý. Việc rút lại không huỷ bỏ những gì đã được xử lý trước đó.",
          "Phục vụ các trang này và giữ trang web hoạt động — lợi ích hợp pháp của chúng tôi trong việc vận hành một trang web chạy được và không bị lạm dụng, theo Điều 6(1)(f).",
          "Ghi nhớ tuỳ chọn của bạn trên thiết bị — hoàn toàn cần thiết để cung cấp điều bạn đã yêu cầu, nên bản thân việc lưu trữ không cần sự đồng ý riêng theo Điều 5(3) của Chỉ thị ePrivacy.",
        ],
      },
      {
        heading: "Còn ai khác tham gia",
        body: [
          "Hai công ty, đều ở Hoa Kỳ, đều chỉ hành động theo chỉ dẫn của chúng tôi dưới một thoả thuận xử lý dữ liệu:",
        ],
        bullets: [
          "Vercel Inc. — lưu trữ và phân phối các trang này.",
          "Functional Software, Inc., hoạt động dưới tên Sentry — báo cáo lỗi, và chỉ khi bạn đã bật chúng.",
        ],
      },
      {
        heading: "Dữ liệu rời khỏi Vương quốc Anh và EEA",
        body: [
          "Cả hai nhà cung cấp đều ở Hoa Kỳ, nên mọi dữ liệu cá nhân họ xử lý đều rời khỏi Vương quốc Anh và EEA. Các lần chuyển dữ liệu đó dựa trên Điều khoản Hợp đồng Tiêu chuẩn của Uỷ ban châu Âu và Phụ lục Vương quốc Anh kèm theo.",
          "Không ai khác nhận được gì. Chúng tôi không bán thông tin cá nhân và không chia sẻ nó cho quảng cáo hành vi xuyên ngữ cảnh, theo cách CCPA và CPRA của California định nghĩa các thuật ngữ đó.",
        ],
      },
      {
        heading: "Lưu giữ trong bao lâu",
        bullets: [
          "Báo cáo lỗi: 90 ngày trên Sentry, sau đó tự động xoá.",
          "Tuỳ chọn trên thiết bị của bạn: cho đến khi bạn đổi nó hoặc xoá dữ liệu của trang này trong trình duyệt.",
          "Nhật ký máy chủ web: do nhà cung cấp giữ trong một thời gian vận hành ngắn, và chúng tôi không sao chép đi đâu cả.",
        ],
        body: [],
      },
      {
        heading: "Quyền của bạn",
        body: [
          "Nếu bạn ở Vương quốc Anh, EEA hoặc Thuỵ Sĩ, bạn có thể hỏi chúng tôi đang giữ gì về bạn, yêu cầu sửa hoặc xoá, hạn chế hoặc phản đối cách sử dụng, nhận dữ liệu ở định dạng có thể chuyển đi, và rút lại sự đồng ý bất cứ lúc nào. Bạn cũng có thể khiếu nại lên cơ quan bảo vệ dữ liệu quốc gia của mình.",
          "Nếu bạn ở California, Colorado, Connecticut, Virginia, Texas hoặc một bang khác của Hoa Kỳ có luật riêng tư người tiêu dùng, bạn có các quyền tương đương để biết, xoá, sửa và từ chối. Chúng tôi tôn trọng tín hiệu Global Privacy Control: nếu trình duyệt của bạn gửi tín hiệu đó, giám sát lỗi vẫn tắt bất kể công tắc nói gì.",
          "Trên thực tế thường không có gì để trao lại. Báo cáo lỗi không mang danh tính nào để chúng tôi tra ra bạn, và đó chính là lý do chúng được thu thập theo cách đó. Hãy viết đến địa chỉ bên dưới và bạn sẽ nhận được trả lời trong vòng 30 ngày, kể cả câu trả lời thành thật rằng chúng tôi không giữ gì cả.",
        ],
      },
      {
        heading: "Trẻ em",
        body: [
          "Trang web này không hướng đến trẻ em và không thu thập từ bất kỳ ai điều gì có thể nhận dạng họ, ở bất kỳ độ tuổi nào.",
        ],
      },
      {
        heading: "Ứng dụng SenseBridge",
        body: [
          "Ứng dụng là một thứ riêng biệt và vẫn chưa phát hành. Nó xử lý dữ liệu camera, micro và chiều sâu hoàn toàn trên thiết bị của bạn và không gửi bất kỳ dữ liệu nào đi đâu cả.",
          "Ứng dụng có cơ chế báo cáo sự cố riêng, tắt theo mặc định, sau cùng một kiểu công tắc trong Cài đặt rồi đến Chẩn đoán. Khi bật, nó gửi báo cáo nếu ứng dụng gặp sự cố hoặc treo: vị trí trong mã nơi điều đó xảy ra, kiểu iPhone của bạn, và phiên bản iOS cùng phiên bản ứng dụng. Không bao giờ là hình ảnh, không bao giờ là nội dung camera đọc được, không bao giờ là âm thanh, không bao giờ là vị trí của bạn.",
        ],
      },
      {
        heading: "Thay đổi đối với thông báo này",
        body: [
          "Nếu những gì được thu thập có thay đổi, trang này sẽ thay đổi trước. Sự đồng ý đã cho theo một mô tả hẹp hơn sẽ được hỏi lại, chứ không âm thầm được mang sang một phạm vi rộng hơn.",
        ],
      },
      {
        heading: "Liên hệ",
        body: [
          "Kevin K. Le, người duy trì dự án, là bên kiểm soát dữ liệu. Hãy viết đến kevinle3212@gmail.com về bất cứ điều gì trên trang này.",
        ],
      },
    ],
  },
  accessibility: {
    heading: "Được xây dựng theo cách mà nó mong muốn được đánh giá",
    body: "Trang web này được xây dựng ưu tiên trình đọc màn hình, theo cùng tiêu chuẩn mà ứng dụng cam kết: cấu trúc ngữ nghĩa, mọi điều khiển đều có nhãn, hỗ trợ đầy đủ bàn phím, WCAG 2.2 AA. Nếu bạn dùng VoiceOver hoặc NVDA, trang này hẳn đã cảm thấy quen thuộc.",
    leadIn: "Bạn thích nghe hơn? Trang này có thể tự đọc to.",
  },
  accessibilityPage: {
    title: "Tuyên bố về khả năng tiếp cận — SenseBridge",
    description:
      "Điều gì đã được kiểm chứng, điều gì chưa, và cách báo cáo một rào cản. Được viết để có thể kiểm chứng, không phải để trấn an.",
    heading: "Tuyên bố về khả năng tiếp cận",
    lede: "SenseBridge là một sản phẩm về khả năng tiếp cận. Điều đó nâng cao tiêu chuẩn mà trang này phải đáp ứng, chứ không hạ thấp nó — nên tuyên bố này được viết để kiểm chứng, không phải để tin. Chỗ nào đã được kiểm chứng, nó nói rõ điều gì đã kiểm chứng. Chỗ nào chưa, nó cũng nói rõ.",
    updated: "Rà soát lần cuối",
    authoritative:
      "Tuyên bố này được công bố bằng nhiều ngôn ngữ. Khi có khác biệt, bản tiếng Anh là bản có hiệu lực.",
    sections: [
      {
        heading: "Những tiêu chuẩn chúng tôi tuân theo",
        body: [
          "WCAG 2.2 mức AA là nền tảng bắt buộc cho trang web này và cho ứng dụng. Mọi kiểm tra tự động nêu dưới đây đều thực thi mức này.",
          "EN 301 549 v3.2.1 — tiêu chuẩn hài hòa của châu Âu, cũng là căn cứ để đánh giá theo Đạo luật Tiếp cận châu Âu — tích hợp chính nền tảng mức AA đó cho nội dung web.",
          "Mức AAA là một mục tiêu hướng tới, đạt được ở những điểm cụ thể và không được tuyên bố là mức tuân thủ. Chính W3C khuyến cáo rằng mức AAA không khả thi cho toàn bộ một trang web như một chính sách chung, và chúng tôi đồng ý.",
        ],
      },
      {
        heading: "Tình trạng tuân thủ",
        body: [
          "Trang web này tuân thủ một phần WCAG 2.2 mức AA và EN 301 549 v3.2.1, đúng theo nghĩa mà các mẫu tuyên bố đó dùng cụm từ này: kiểm thử tự động không phát hiện vi phạm nào, và chưa có bên độc lập nào thực hiện kiểm toán thủ công. Khoảng cách đó được mô tả trong mục « Những gì chưa được làm », vì đó mới là phần hữu ích của một tuyên bố như thế này.",
        ],
      },
      {
        heading: "Những gì được kiểm tra ở mỗi thay đổi",
        body: [
          "Không có mục nào ở đây là một báo cáo làm một lần rồi thôi. Mỗi mục đều chạy trước khi một thay đổi có thể phát hành, và một lỗi sẽ chặn nó lại:",
        ],
        bullets: [
          "Mọi trang đã công bố đều được kiểm tra theo bộ quy tắc WCAG 2.2 mức AA bằng hai công cụ độc lập — HTML CodeSniffer và axe-core — trong một trình duyệt bị buộc vào chế độ giảm chuyển động. Chỉ một lỗi cũng làm hỏng bản dựng.",
          "Mọi trang đã công bố còn được kiểm tra theo bộ quy tắc mức AAA. Lượt kiểm tra đó chỉ báo cáo chứ không chặn, vì lý do nêu bên dưới.",
          "Mỗi trang là một tài liệu hoàn chỉnh, đọc được khi tắt JavaScript. Chuyển động là tùy chọn, và không khởi tạo bất cứ thứ gì khi hệ thống của bạn yêu cầu giảm chuyển động.",
          "Content-Security-Policy của bản chính thức được kiểm nghiệm trên trang đã dựng, để một chính sách âm thầm loại bỏ tệp kiểu dáng không thể được phát hành và bỏ lại các trang này mất định dạng, không đọc nổi.",
          "Bản âm thanh thuyết minh được đối chiếu với văn bản trang, nên một thay đổi câu chữ không thể lặng lẽ để lại phần thuyết minh cũ.",
        ],
      },
      {
        heading: "Những chỗ chúng tôi vượt mức AA",
        body: [
          "Được nêu tên từng mục thay vì tuyên bố cả một mức, bởi một tiêu chí mức AAA đạt được trên một trang không phải là tuân thủ mức AAA:",
        ],
        bullets: [
          "1.4.6 Độ tương phản (nâng cao) — mọi màu mang chữ trên trang này đều đạt tỷ lệ 7:1 của mức AAA, chứ không phải mức sàn 4.5:1 của mức AA, và đạt được so với nền tối nhất mà nó từng được đặt lên, chứ không chỉ so với nền trang.",
          "2.2.3 Không giới hạn thời gian — ở đây không có gì bị giới hạn thời gian.",
          "2.3.2 Ba lần nhấp nháy — không có gì nhấp nháy cả.",
          "2.4.9 Mục đích của liên kết (chỉ riêng liên kết) — các liên kết được viết sao cho hiểu được khi tách khỏi ngữ cảnh, đúng như cách trình đọc màn hình liệt kê chúng.",
          "3.3.5 Trợ giúp — lối báo cáo một rào cản nằm ở chân mỗi trang, không bị giấu trong một mục hỗ trợ.",
        ],
      },
      {
        heading: "Vì sao chúng tôi không tuyên bố mức AAA",
        body: [
          "Tuyên bố mức đó cho toàn trang sẽ đúng là kiểu nói quá mà tuyên bố này tồn tại để tránh. Cụ thể: không có bản ngôn ngữ ký hiệu cho phần âm thanh thuyết minh (1.2.6), và các tiêu chí về trình độ đọc và cách phát âm (từ 3.1.3 đến 3.1.6) đặt ra nghĩa vụ đối với nội dung dịch mà một trang ba ngôn ngữ do một người duy trì không thể bảo đảm một cách trung thực ở mỗi lần thay đổi.",
          "Chỗ nào một tiêu chí mức AAA vừa rẻ vừa bền, chúng tôi nhận lấy. Chỗ nào đáp ứng nó đòi hỏi một lời hứa không thể giữ ở mỗi lần thay đổi, chúng tôi nói ra ở đây thay vì tuyên bố có.",
        ],
      },
      {
        heading: "Những gì chưa được làm",
        body: [
          "Nói thẳng, vì một tuyên bố về khả năng tiếp cận chỉ liệt kê thành tích thì là quảng cáo:",
        ],
        bullets: [
          "Chưa có cuộc kiểm toán khả năng tiếp cận độc lập nào của bên thứ ba, cả với trang web lẫn với ứng dụng.",
          "Chưa hoàn thành việc thẩm định chính thức với người khiếm thị và người thị lực kém. Kiểm tra tự động không thể cho bạn biết một trang có dễ hiểu hay không với người điều hướng bằng tai; chỉ chính họ mới biết. Đây là rủi ro tiếp cận lớn nhất còn bỏ ngỏ của dự án, và nó được ghi nhận đúng như vậy.",
          "Kiểm thử tự động có giới hạn. Các công cụ loại này chỉ phát hiện một phần nhỏ các rào cản thực tế — con số thường được nhắc đến là khoảng một phần ba. Một trang có thể vượt qua mọi quy tắc tự động mà vẫn khó hiểu, gắn nhãn sai, hoặc không dùng được trên thực tế.",
          "Chưa lập VPAT hay Báo cáo Tuân thủ Khả năng Tiếp cận nào.",
        ],
      },
      {
        heading: "Những hạn chế đã biết",
        bullets: [
          "Phần âm thanh thuyết minh chỉ bao gồm nội dung chính của trang chủ, không gồm phần điều hướng hay chân trang.",
          "Các trang tiếng Tây Ban Nha và tiếng Việt được rà soát về độ chính xác của nghĩa, nhưng chưa được thử nghiệm với trình đọc màn hình chạy bằng chính các ngôn ngữ đó.",
          "Khi một điều khiển của trình duyệt hoặc của hệ điều hành xuất hiện, khả năng tiếp cận của nó do bên tạo ra nó quyết định, không phải chúng tôi.",
          "Chế độ hiển thị tương phản cao và màu bắt buộc được triển khai theo thiết lập của chính nền tảng, nhưng chưa được bên ngoài kiểm toán.",
        ],
        body: [],
      },
      {
        heading: "Ứng dụng SenseBridge",
        body: [
          "Chưa tuyên bố mức tuân thủ nào cho ứng dụng. Nó chưa được phát hành công khai, và tuyên bố này sẽ không giả vờ rằng một bản dựng trước khi ra mắt đã được kiểm toán.",
          "Cổng kiểm soát nội bộ của nó nghiêm ngặt hơn một tỷ lệ phần trăm — không một phần tử tương tác nào thiếu nhãn trên mọi màn hình, kèm một lượt rà soát bằng VoiceOver bắt buộc với bất kỳ giao diện nào bị sửa trước khi thay đổi được hợp nhất — nhưng một cổng kiểm soát trong quá trình phát triển không phải là một cuộc kiểm toán tuân thủ.",
        ],
      },
      {
        heading: "Hãy báo cho chúng tôi một rào cản",
        body: [
          "Nếu bất kỳ phần nào của SenseBridge không dùng được với bạn, đó là một lỗi, và nó được xử lý với mức ưu tiên ngang một sự cố sập ứng dụng — không phải như một đề xuất tính năng.",
          "Hãy viết cho kevinle3212@gmail.com. Mô tả bạn đang định làm gì, bạn dùng công nghệ hỗ trợ nào và phiên bản nào nếu bạn biết, và thay vào đó điều gì đã xảy ra. Bạn không cần biết nguyên nhân kỹ thuật, và cũng không cần diễn đạt bằng thuật ngữ chuyên môn về khả năng tiếp cận.",
          "Chúng tôi đặt mục tiêu xác nhận đã nhận trong vòng 5 ngày làm việc, và đưa ra câu trả lời thực chất — một bản sửa lỗi, hoặc một mốc thời gian cho nó — trong vòng 30 ngày. Đây chính là cơ chế phản hồi mà Đạo luật Tiếp cận châu Âu và EN 301 549 yêu cầu một tuyên bố phải nêu tên, và người duy trì dự án đọc nó trực tiếp.",
        ],
      },
      {
        heading: "Nếu chúng tôi không sửa",
        body: [
          "Dự án này chưa ra mắt, miễn phí, và do một người duy trì. Không có cơ quan thực thi chính thức nào tham gia vào nó. Nếu chúng tôi không giải quyết báo cáo của bạn, bạn vẫn giữ mọi lối khiếu nại mà luật nơi bạn sống trao cho bạn — cơ quan giám sát thị trường do Quốc gia Thành viên EU của bạn chỉ định, lối khiếu nại theo Equality Act ở Vương quốc Anh, đơn khiếu nại lên Bộ Tư pháp theo ADA ở Hoa Kỳ, Ủy viên Khả năng Tiếp cận ở Canada, hoặc Ủy ban Nhân quyền Úc.",
          "Không điều gì trong tuyên bố này, và không điều gì trong các điều khoản của chúng tôi, giới hạn bất kỳ lối nào trong số đó.",
        ],
      },
      {
        heading: "Tuyên bố này được giữ trung thực ra sao",
        body: [
          "Nó được rà soát mỗi khi một thay đổi động đến một khâu kiểm tra khả năng tiếp cận, và tối thiểu mười hai tháng một lần. Bản đầy đủ, kèm những đạo luật cụ thể mà nó được viết để đáp ứng, được công bố trong kho mã nguồn của dự án dưới tên legal/ACCESSIBILITY_STATEMENT.md. Không tài liệu nào trong hai tài liệu đó được phép tuyên bố một khâu kiểm tra mà tài liệu kia không có.",
        ],
      },
    ],
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
    replay: "Phát lại hoạt ảnh cây cầu",
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
    privacyLink: "Quyền riêng tư và dữ liệu",
    accessibilityLink: "Tuyên bố về khả năng tiếp cận",
    notAvailable:
      "Chưa có sẵn trên App Store — SenseBridge đang ở giai đoạn trước khi ra mắt và đang trong quá trình phát triển mở.",
    voiceCredit: "Bản đọc giọng tự nhiên được tạo bằng elevenlabs.io.",
    monitoringCredit: "Giám sát lỗi khả dụng qua sentry.io, luôn tắt cho đến khi bạn bật.",
    poweredBy: "Được xây dựng bằng",
    makerPhotoAlt: "Kevin K. Le, hiện là nhà phát triển duy nhất của dự án",
  },
  disclaimer: {
    ariaLabel: "Cảnh báo an toàn",
    text: "SenseBridge giúp bạn nhận thức rõ hơn về môi trường xung quanh. Đây không phải là thiết bị an toàn hỗ trợ di chuyển hay định hướng, và các mô tả của nó có thể sai — hãy luôn sử dụng cùng với phán đoán của chính bạn, gậy dò đường, hoặc chó dẫn đường.",
  },
  errorPages: {
    backHome: "Quay lại trang chủ",
    notFound: {
      heading: "Trang này đã rơi xuống một cái hố.",
      body: "Đâu đó giữa đây và kia, trang này đã đi lạc và rơi xuống một cái hố. Chuyện này xảy ra với cả những trang tốt nhất — phần còn lại của trang web vẫn vững vàng.",
    },
    badRequest: {
      heading: "Có gì đó trong yêu cầu này chưa ổn.",
      body: "Lần này trang không rơi xuống hố — chính yêu cầu đã đi sai hướng trước khi đến đây.",
    },
    serverError: {
      heading: "Có gì đó đã hỏng ở phía chúng tôi. Xin lỗi vì điều đó.",
      body: "Ngay cả một chú bò được vẽ kỹ cũng có ngày không suôn sẻ. Đây không phải lỗi của bạn — hãy thử lại sau một chút.",
    },
    statusLabel: "HTTP {code} · {phrase}",
    classes: {
      informational: {
        heading: "Đây là lúc giao thức đang suy nghĩ thành tiếng.",
        body: "Trạng thái 1xx là phản hồi tạm thời — máy chủ báo rằng nó vẫn đang xử lý phản hồi thật. Bạn hầu như không bao giờ thấy nó trong trình duyệt, nhưng nó vẫn có một trang ở đây.",
      },
      success: {
        heading: "Ở đây không có gì sai cả.",
        body: "Trạng thái 2xx nghĩa là yêu cầu đã thành công. Chú bò rơi xuống vì lý do riêng của nó — trang này chỉ tồn tại để mọi mã trong danh mục đều có một trang.",
      },
      redirect: {
        heading: "Mã này trỏ tới một nơi khác.",
        body: "Trạng thái 3xx nghĩa là thứ bạn yêu cầu nằm ở một địa chỉ khác. Thông thường trình duyệt sẽ tự đi theo mà không bao giờ hiện trang này.",
      },
      client: {
        heading: "Yêu cầu đó chưa tới nơi đúng cách.",
        body: "Trạng thái 4xx nghĩa là có gì đó trong chính yêu cầu chưa ổn — địa chỉ, phương thức, hoặc dữ liệu đi kèm. Phần còn lại của trang web vẫn vững vàng.",
      },
      server: {
        heading: "Có gì đó đã hỏng ở phía chúng tôi.",
        body: "Trạng thái 5xx nghĩa là yêu cầu vẫn ổn còn máy chủ thì không. Đây không phải lỗi của bạn — hãy thử lại sau một chút.",
      },
    },
  },
};
