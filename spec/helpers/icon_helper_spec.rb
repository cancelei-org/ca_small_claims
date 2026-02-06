# frozen_string_literal: true

require "rails_helper"

RSpec.describe IconHelper, type: :helper do
  describe "#icon" do
    it "renders SVG icon for valid icon name" do
      result = helper.icon(:magic_wand)

      expect(result).to include("<svg")
      expect(result).to include("</svg>")
      expect(result).to include("viewBox")
    end

    it "returns empty string for invalid icon name" do
      result = helper.icon(:nonexistent_icon)
      expect(result).to eq("")
    end

    it "applies custom CSS class" do
      result = helper.icon(:check, class: "w-8 h-8 custom-class")
      expect(result).to include("w-8")
      expect(result).to include("h-8")
      expect(result).to include("custom-class")
    end

    it "uses default class when not specified" do
      result = helper.icon(:check)
      expect(result).to include("w-4 h-4")
    end

    it "sets custom stroke color" do
      result = helper.icon(:arrow_left, stroke: "#FF0000")
      expect(result).to include('stroke="#FF0000"')
    end

    it "uses currentColor stroke by default" do
      result = helper.icon(:arrow_right)
      expect(result).to include('stroke="currentColor"')
    end

    it "sets custom fill color" do
      result = helper.icon(:check, fill: "#00FF00")
      expect(result).to include('fill="#00FF00"')
    end

    it "uses no fill by default" do
      result = helper.icon(:check)
      expect(result).to include('fill="none"')
    end

    it "includes path elements for icon data" do
      result = helper.icon(:check)
      expect(result).to include("<path")
      expect(result).to include("stroke-linecap")
      expect(result).to include("stroke-linejoin")
    end

    it "handles icons with complex paths" do
      result = helper.icon(:magic_wand)
      # Magic wand has 1 complex path
      expect(result.scan(/<path/).count).to eq(1)
      expect(result).to include("<path")
    end
  end

  describe "#magic_wand_icon" do
    it "renders magic wand icon with small size" do
      result = helper.magic_wand_icon
      expect(result).to include("w-3.5")
      expect(result).to include("h-3.5")
    end

    it "allows custom class override" do
      result = helper.magic_wand_icon(class: "w-6 h-6")
      expect(result).to include("w-6")
    end
  end

  describe "#external_link_icon" do
    it "renders external link icon with extra small size" do
      result = helper.external_link_icon
      expect(result).to include("w-3")
      expect(result).to include("h-3")
    end
  end

  describe "#info_icon" do
    it "renders info circle icon" do
      result = helper.info_icon
      expect(result).to include("<svg")
    end
  end

  describe "#chevron_down_icon" do
    it "renders chevron down icon" do
      result = helper.chevron_down_icon
      expect(result).to include("<svg")
    end
  end

  describe "#template_icon" do
    it "renders home icon for home template" do
      result = helper.template_icon("home")
      expect(result).to include("<svg")
      expect(result).to include("text-primary")
    end

    it "renders car icon for car template" do
      result = helper.template_icon("car")
      expect(result).to include("<svg")
    end

    it "renders dollar sign icon for dollar-sign template" do
      result = helper.template_icon("dollar-sign")
      expect(result).to include("<svg")
    end

    it "renders tool icon for tool template" do
      result = helper.template_icon("tool")
      expect(result).to include("<svg")
    end

    it "falls back to lightning bolt for unknown template" do
      result = helper.template_icon("unknown_template")
      # Should render lightning_bolt as fallback
      expect(result).to include("<svg")
    end

    it "applies default size and color classes" do
      result = helper.template_icon("home")
      expect(result).to include("w-5")
      expect(result).to include("h-5")
      expect(result).to include("text-primary")
    end

    it "allows custom class override" do
      result = helper.template_icon("home", class: "w-10 h-10 text-secondary")
      expect(result).to include("w-10")
      expect(result).to include("text-secondary")
    end
  end

  describe "ICONS constant" do
    it "defines all expected icons" do
      expected_icons = %i[
        magic_wand info_circle external_link chevron_down microphone
        check x_mark arrow_left arrow_right document download
        home car dollar_sign tool lightning_bolt
        plus_circle edit user_plus message_circle refresh
        check_circle alert_circle calendar alert_triangle question_circle
      ]

      expected_icons.each do |icon_name|
        expect(described_class::ICONS).to have_key(icon_name)
      end
    end

    it "includes viewBox for all icons" do
      described_class::ICONS.each do |name, data|
        expect(data).to have_key(:viewBox), "Icon #{name} missing viewBox"
      end
    end

    it "includes paths for all icons" do
      described_class::ICONS.each do |name, data|
        expect(data).to have_key(:paths), "Icon #{name} missing paths"
        expect(data[:paths]).to be_an(Array), "Icon #{name} paths not an array"
        expect(data[:paths]).not_to be_empty, "Icon #{name} has no paths"
      end
    end

    it "freezes the icons constant" do
      expect(described_class::ICONS).to be_frozen
    end
  end
end
