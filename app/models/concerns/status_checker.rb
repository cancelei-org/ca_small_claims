# frozen_string_literal: true

module StatusChecker
  extend ActiveSupport::Concern

  class_methods do
    # Define status query methods based on a status column
    # @param statuses [Array<Symbol>] List of status values
    # @param column [Symbol] The column name (default: :status)
    #
    # @example
    #   define_status_methods :draft, :completed, :submitted
    #   # Generates: draft?, completed?, submitted?
    #
    def define_status_methods(*statuses, column: :status)
      statuses.each do |status|
        define_method("#{status}?") do
          self[column] == status.to_s
        end
      end
    end
  end
end
