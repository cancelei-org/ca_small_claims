# frozen_string_literal: true

module Api
  module V1
    class FormsController < Api::BaseController
      def index
        forms = Cache::FormMetadataCache.fetch.map do |code, title, category_id|
          { code: code, title: title, category_id: category_id }
        end

        render json: { data: forms }
      end

      def show
        form = FormDefinition.find_by!(code: params[:id].to_s.upcase)
        render json: {
          data: {
            code: form.code,
            title: form.title,
            description: form.description,
            category_id: form.category_id,
            fillable: form.fillable,
            fields: form.field_definitions.order(:position).pluck(:name, :field_type, :required)
          }
        }
      end
    end
  end
end
