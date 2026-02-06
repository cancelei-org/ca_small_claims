# frozen_string_literal: true

module Admin
  module UsersHelper
    def activity_timeline_icon(activity_type)
      case activity_type
      when "submission_created"
        content_tag(:div, class: "w-5 h-5 rounded-full bg-primary flex items-center justify-center") do
          tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor", class: "w-3 h-3 text-primary-content") do
            tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M12 4.5v15m7.5-7.5h-15")
          end
        end
      when "submission_completed"
        content_tag(:div, class: "w-5 h-5 rounded-full bg-success flex items-center justify-center") do
          tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor", class: "w-3 h-3 text-success-content") do
            tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M4.5 12.75l6 6 9-13.5")
          end
        end
      when "submission_updated"
        content_tag(:div, class: "w-5 h-5 rounded-full bg-info flex items-center justify-center") do
          tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor", class: "w-3 h-3 text-info-content") do
            tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99")
          end
        end
      when "feedback_submitted"
        content_tag(:div, class: "w-5 h-5 rounded-full bg-warning flex items-center justify-center") do
          tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor", class: "w-3 h-3 text-warning-content") do
            tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z")
          end
        end
      when "profile_updated"
        content_tag(:div, class: "w-5 h-5 rounded-full bg-secondary flex items-center justify-center") do
          tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor", class: "w-3 h-3 text-secondary-content") do
            tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z")
          end
        end
      when "account_created"
        content_tag(:div, class: "w-5 h-5 rounded-full bg-neutral flex items-center justify-center") do
          tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor", class: "w-3 h-3 text-neutral-content") do
            tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z")
          end
        end
      else
        content_tag(:div, class: "w-5 h-5 rounded-full bg-base-300 flex items-center justify-center") do
          tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor", class: "w-3 h-3") do
            tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z")
          end
        end
      end
    end

    def activity_timeline_color(activity_type)
      case activity_type
      when "submission_created" then "bg-primary"
      when "submission_completed" then "bg-success"
      when "submission_updated" then "bg-info"
      when "feedback_submitted" then "bg-warning"
      when "profile_updated" then "bg-secondary"
      when "account_created" then "bg-neutral"
      else "bg-base-300"
      end
    end
  end
end
