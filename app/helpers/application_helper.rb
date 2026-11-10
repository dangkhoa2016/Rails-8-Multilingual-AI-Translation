module ApplicationHelper
  ICONS = {
    "layout-dashboard" => [
      [:rect, { x: 3, y: 3, width: 7, height: 7, rx: 1.5 }],
      [:rect, { x: 14, y: 3, width: 7, height: 7, rx: 1.5 }],
      [:rect, { x: 3, y: 14, width: 7, height: 7, rx: 1.5 }],
      [:rect, { x: 14, y: 14, width: 7, height: 7, rx: 1.5 }]
    ],
    "panel-left-close" => [
      [:rect, { x: 3, y: 3, width: 18, height: 18, rx: 2 }],
      [:path, { d: "M9 3v18m7-13-3 4 3 4" }]
    ],
    "panel-left-open" => [
      [:rect, { x: 3, y: 3, width: 18, height: 18, rx: 2 }],
      [:path, { d: "M9 3v18m4-13 3 4-3 4" }]
    ],
    "download" => [
      [:path, { d: "M12 3v12m0 0 5-5m-5 5-5-5M5 17v4h14v-4" }]
    ],
    "chevron-left" => [[:path, { d: "m15 18-6-6 6-6" }]],
    "book-open" => [
      [:path, { d: "M12 7c-2.3-1.8-5.8-2.4-9-1.5v14c3.2-.9 6.7-.3 9 1.5m0-14c2.3-1.8 5.8-2.4 9-1.5v14c-3.2-.9-6.7-.3-9 1.5m0-14v14" }]
    ],
    "circle-help" => [
      [:circle, { cx: 12, cy: 12, r: 9 }],
      [:path, { d: "M9.5 9a2.7 2.7 0 0 1 5.3.8c0 2-2.8 2.2-2.8 4.2M12 17.5h.01" }]
    ],
    "menu" => [[:path, { d: "M4 6h16M4 12h16M4 18h16" }]],
    "x" => [[:path, { d: "M18 6 6 18M6 6l12 12" }]],
    "languages" => [
      [:path, { d: "m5 8 6 6" }],
      [:path, { d: "m4 14 6-6 2-3H3" }],
      [:path, { d: "M2 5h12" }],
      [:path, { d: "M7 2h1" }],
      [:path, { d: "m13 18 5-10 5 10" }],
      [:path, { d: "M14.5 15h7" }]
    ],
    "globe" => [
      [:circle, { cx: 12, cy: 12, r: 9 }],
      [:path, { d: "M3 12h18M12 3a15 15 0 0 1 0 18M12 3a15 15 0 0 0 0 18" }]
    ],
    "sparkles" => [
      [:path, { d: "m12 3 1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9L12 3Z" }],
      [:path, { d: "m19 16 .8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8L19 16Z" }]
    ],
    "history" => [
      [:path, { d: "M3 12a9 9 0 1 0 3-6.7L3 8" }],
      [:path, { d: "M3 3v5h5M12 7v5l3 2" }]
    ],
    "settings" => [
      [:path, { d: "M3 6h7m4 0h7M3 12h3m4 0h11M3 18h10m4 0h4" }],
      [:circle, { cx: 12, cy: 6, r: 2 }],
      [:circle, { cx: 8, cy: 12, r: 2 }],
      [:circle, { cx: 15, cy: 18, r: 2 }]
    ],
    "shield" => [
      [:path, { d: "m12 2 8 4v6c0 5-3.5 8-8 10-4.5-2-8-5-8-10V6l8-4Z" }],
      [:path, { d: "m9 12 2 2 4-4" }]
    ],
    "sun" => [
      [:circle, { cx: 12, cy: 12, r: 4 }],
      [:path, { d: "M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" }]
    ],
    "moon" => [[:path, { d: "M20.3 15.5A8.6 8.6 0 0 1 8.5 3.7 8.8 8.8 0 1 0 20.3 15.5Z" }]],
    "chevron-down" => [[:path, { d: "m6 9 6 6 6-6" }]],
    "chevron-right" => [[:path, { d: "m9 18 6-6-6-6" }]],
    "arrow-right" => [[:path, { d: "M5 12h14m-6-6 6 6-6 6" }]],
    "arrow-left-right" => [[:path, { d: "M3 7h17m-5-4 5 4-5 4M21 17H4m5-4-5 4 5 4" }]],
    "plus" => [[:path, { d: "M12 5v14M5 12h14" }]],
    "plug" => [[:path, { d: "M7 3v5m10-5v5M5 8h14v4a7 7 0 0 1-14 0V8Zm7 11v3" }]],
    "server" => [
      [:rect, { x: 3, y: 3, width: 18, height: 8, rx: 2 }],
      [:rect, { x: 3, y: 13, width: 18, height: 8, rx: 2 }],
      [:path, { d: "M7 7h.01M7 17h.01M11 7h7M11 17h7" }]
    ],
    "bolt" => [[:path, { d: "m13 2-9 12h7l-1 8 10-12h-7l1-8Z" }]],
    "check-circle" => [
      [:circle, { cx: 12, cy: 12, r: 9 }],
      [:path, { d: "m8 12 3 3 5-6" }]
    ],
    "alert-circle" => [
      [:circle, { cx: 12, cy: 12, r: 9 }],
      [:path, { d: "M12 8v4m0 4h.01" }]
    ],
    "clock" => [
      [:circle, { cx: 12, cy: 12, r: 9 }],
      [:path, { d: "M12 7v5l4 2" }]
    ],
    "lock" => [
      [:rect, { x: 5, y: 10, width: 14, height: 11, rx: 2 }],
      [:path, { d: "M8 10V7a4 4 0 0 1 8 0v3M12 15v2" }]
    ],
    "key" => [
      [:circle, { cx: 7.5, cy: 14.5, r: 4.5 }],
      [:path, { d: "m11 11 10-10m-4 4 3 3m-7 1 3 3" }]
    ],
    "log-out" => [
      [:path, { d: "M10 4H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h5" }],
      [:path, { d: "M15 7l5 5-5 5m5-5H9" }]
    ],
    "copy" => [
      [:rect, { x: 8, y: 8, width: 12, height: 12, rx: 2 }],
      [:path, { d: "M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" }]
    ],
    "search" => [
      [:circle, { cx: 11, cy: 11, r: 7 }],
      [:path, { d: "m16 16 5 5" }]
    ],
    "file-text" => [
      [:path, { d: "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6Z" }],
      [:path, { d: "M14 2v6h6M8 13h8M8 17h8" }]
    ],
    "edit" => [
      [:path, { d: "M12 20h9M16 4a2 2 0 0 1 3 3L9 17l-4 1 1-4L16 4Z" }]
    ],
    "rotate" => [
      [:path, { d: "M20 7v5h-5M4 17v-5h5" }],
      [:path, { d: "M5.7 9A7 7 0 0 1 18 6l2 6M4 12l2 6a7 7 0 0 0 12.3-3" }]
    ],
    "list-checks" => [
      [:path, { d: "m3 6 2 2 3-3M12 7h9m-18 6 2 2 3-3m4 2h9m-18 6 2 2 3-3m4 2h9" }]
    ],
    "eye" => [
      [:path, { d: "M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6Z" }],
      [:circle, { cx: 12, cy: 12, r: 3 }]
    ],
    "external-link" => [
      [:path, { d: "M14 4h6v6M10 14 20 4M20 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h5" }]
    ],
    "user" => [
      [:circle, { cx: 12, cy: 8, r: 4 }],
      [:path, { d: "M4 21a8 8 0 0 1 16 0" }]
    ]
  }.freeze

  def ui_icon(name, size: 20, class_name: "")
    elements = ICONS.fetch(name.to_s, ICONS.fetch("sparkles")).map do |element, attributes|
      tag.public_send(element, **attributes)
    end

    tag.svg(safe_join(elements), xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 24 24", width: size, height: size,
      fill: "none", stroke: "currentColor", stroke_width: 1.8,
      stroke_linecap: "round", stroke_linejoin: "round",
      class: class_name, aria: { hidden: "true" }, focusable: "false")
  end

  def navigation_link(name:, path:, icon:, active:)
    link_to path, class: ["app-nav-link", ("is-active" if active)].compact.join(" "),
      aria: { current: ("page" if active) } do
      safe_join([
        ui_icon(icon, size: 19, class_name: "shrink-0"),
        tag.span(name, class: "app-nav-link-label truncate"),
        ui_icon("chevron-right", size: 14, class_name: "ml-auto opacity-35")
      ])
    end
  end
end
