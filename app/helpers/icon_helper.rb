# frozen_string_literal: true

module IconHelper
  # SVG icon definitions with viewBox and path data
  ICONS = {
    magic_wand: {
      viewBox: "0 0 24 24",
      paths: [
        "M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z"
      ],
      stroke_width: "1.5"
    },
    info_circle: {
      viewBox: "0 0 24 24",
      paths: [ "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" ],
      stroke_width: "2"
    },
    external_link: {
      viewBox: "0 0 24 24",
      paths: [ "M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" ],
      stroke_width: "2"
    },
    chevron_down: {
      viewBox: "0 0 24 24",
      paths: [ "M19 9l-7 7-7-7" ],
      stroke_width: "2"
    },
    microphone: {
      viewBox: "0 0 24 24",
      paths: [ "M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z" ],
      stroke_width: "1.5"
    },
    check: {
      viewBox: "0 0 24 24",
      paths: [ "M5 13l4 4L19 7" ],
      stroke_width: "2"
    },
    x_mark: {
      viewBox: "0 0 24 24",
      paths: [ "M6 18L18 6M6 6l12 12" ],
      stroke_width: "2"
    },
    arrow_left: {
      viewBox: "0 0 24 24",
      paths: [ "M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" ],
      stroke_width: "1.5"
    },
    arrow_right: {
      viewBox: "0 0 24 24",
      paths: [ "M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" ],
      stroke_width: "1.5"
    },
    document: {
      viewBox: "0 0 24 24",
      paths: [ "M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" ],
      stroke_width: "1.5"
    },
    download: {
      viewBox: "0 0 24 24",
      paths: [ "M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" ],
      stroke_width: "1.5"
    },
    # Template icons
    home: {
      viewBox: "0 0 24 24",
      paths: [ "M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" ],
      stroke_width: "1.5"
    },
    car: {
      viewBox: "0 0 24 24",
      paths: [ "M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12" ],
      stroke_width: "1.5"
    },
    dollar_sign: {
      viewBox: "0 0 24 24",
      paths: [ "M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" ],
      stroke_width: "1.5"
    },
    tool: {
      viewBox: "0 0 24 24",
      paths: [ "M11.42 15.17L17.25 21A2.652 2.652 0 0021 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 11-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 004.486-6.336l-3.276 3.277a3.004 3.004 0 01-2.25-2.25l3.276-3.276a4.5 4.5 0 00-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437l1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008z" ],
      stroke_width: "1.5"
    },
    lightning_bolt: {
      viewBox: "0 0 24 24",
      paths: [ "M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" ],
      stroke_width: "1.5"
    },
    # Form finder situation icons
    plus_circle: {
      viewBox: "0 0 24 24",
      paths: [ "M12 9v6m3-3H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" ],
      stroke_width: "1.5"
    },
    edit: {
      viewBox: "0 0 24 24",
      paths: [ "M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" ],
      stroke_width: "1.5"
    },
    user_plus: {
      viewBox: "0 0 24 24",
      paths: [ "M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z" ],
      stroke_width: "1.5"
    },
    message_circle: {
      viewBox: "0 0 24 24",
      paths: [ "M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z" ],
      stroke_width: "1.5"
    },
    refresh: {
      viewBox: "0 0 24 24",
      paths: [ "M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99" ],
      stroke_width: "1.5"
    },
    check_circle: {
      viewBox: "0 0 24 24",
      paths: [ "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" ],
      stroke_width: "1.5"
    },
    alert_circle: {
      viewBox: "0 0 24 24",
      paths: [ "M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" ],
      stroke_width: "1.5"
    },
    calendar: {
      viewBox: "0 0 24 24",
      paths: [ "M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" ],
      stroke_width: "1.5"
    },
    alert_triangle: {
      viewBox: "0 0 24 24",
      paths: [ "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" ],
      stroke_width: "1.5"
    },
    question_circle: {
      viewBox: "0 0 24 24",
      paths: [ "M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z" ],
      stroke_width: "1.5"
    }
  }.freeze

  # Render an SVG icon
  # @param name [Symbol] The icon name (e.g., :magic_wand, :external_link)
  # @param options [Hash] Options for the icon
  # @option options [String] :class CSS classes (default: "w-4 h-4")
  # @option options [String] :stroke Stroke color (default: "currentColor")
  # @option options [String] :fill Fill color (default: "none")
  # @return [String] The SVG HTML
  def icon(name, options = {})
    icon_data = ICONS[name]
    return "" unless icon_data

    css_class = options[:class] || "w-4 h-4"
    stroke = options[:stroke] || "currentColor"
    fill = options[:fill] || "none"
    stroke_width = options[:stroke_width] || icon_data[:stroke_width] || "2"

    content_tag(:svg,
                class: css_class,
                fill: fill,
                stroke: stroke,
                viewBox: icon_data[:viewBox],
                "stroke-width": stroke_width) do
      safe_join(
        icon_data[:paths].map do |path_d|
          content_tag(:path, nil,
                      d: path_d,
                      "stroke-linecap": "round",
                      "stroke-linejoin": "round")
        end
      )
    end
  end

  # Shorthand helpers for common icons
  def magic_wand_icon(options = {})
    options[:class] ||= "w-3.5 h-3.5"
    icon(:magic_wand, options)
  end

  def external_link_icon(options = {})
    options[:class] ||= "w-3 h-3"
    icon(:external_link, options)
  end

  def info_icon(options = {})
    icon(:info_circle, options)
  end

  def chevron_down_icon(options = {})
    icon(:chevron_down, options)
  end

  # Template icon helper - maps template icon names to actual icons
  # @param icon_name [String] The icon name from template YAML (e.g., "home", "car")
  # @param options [Hash] Options for the icon
  def template_icon(icon_name, options = {})
    options[:class] ||= "w-5 h-5 text-primary"

    icon_map = {
      "home" => :home,
      "car" => :car,
      "dollar-sign" => :dollar_sign,
      "tool" => :tool
    }

    symbol = icon_map[icon_name.to_s] || :lightning_bolt
    icon(symbol, options)
  end
end
