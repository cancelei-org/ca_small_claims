# frozen_string_literal: true

module FormFinder
  class Recommender
    RECOMMENDATIONS = {
      # Plaintiff situations
      %w[plaintiff new_case] => {
        primary: %w[SC-100],
        conditional: {
          multiple_parties: %w[SC-100A],
          needs_fee_waiver: %w[SC-103]
        },
        workflow: "plaintiff_claim",
        next_steps: [
          "File SC-100 with the court clerk",
          "Pay the filing fee (or submit fee waiver)",
          "Serve the defendant using SC-104"
        ]
      },
      %w[plaintiff modify_claim] => {
        primary: %w[SC-114],
        conditional: {},
        workflow: nil,
        next_steps: [
          "Complete SC-114 with your changes",
          "File with the court before your hearing date",
          "Serve a copy on the other party"
        ]
      },
      %w[plaintiff subpoena_witness] => {
        primary: %w[SC-221],
        conditional: {},
        workflow: nil,
        next_steps: [
          "Complete SC-221 with witness information",
          "File with the court clerk",
          "Have the subpoena personally served on the witness"
        ]
      },

      # Defendant situations
      %w[defendant respond_only] => {
        primary: [],
        conditional: {},
        workflow: nil,
        info: "You don't need to file forms just to respond. Simply appear at your hearing date.",
        next_steps: [
          "Review the plaintiff's claim carefully",
          "Gather evidence to support your defense",
          "Appear at the hearing on the scheduled date"
        ]
      },
      %w[defendant counter_claim] => {
        primary: %w[SC-120],
        conditional: {
          multiple_parties: %w[SC-120A]
        },
        workflow: nil,
        next_steps: [
          "File SC-120 with the court clerk before the hearing",
          "Pay the filing fee",
          "Serve the plaintiff with a copy"
        ]
      },
      %w[defendant modify_claim] => {
        primary: %w[SC-114],
        conditional: {},
        workflow: nil,
        next_steps: [
          "Complete SC-114 with your requested changes",
          "File with the court before your hearing date"
        ]
      },

      # Judgment holder (winner) situations
      %w[judgment_holder record_payment] => {
        primary: %w[SC-132],
        conditional: {},
        workflow: nil,
        next_steps: [
          "Complete SC-132 when judgment is paid in full",
          "File with the court to officially close the case"
        ]
      },
      %w[judgment_holder enforce_judgment] => {
        primary: %w[EJ-001],
        conditional: {},
        workflow: nil,
        next_steps: [
          "Complete EJ-001 to create an Abstract of Judgment",
          "Record with the County Recorder to create a lien",
          "Consider wage garnishment or bank levy if needed"
        ]
      },
      %w[judgment_holder correct_judgment] => {
        primary: %w[SC-108],
        conditional: {},
        workflow: nil,
        next_steps: [
          "Complete SC-108 describing the error",
          "File with the court clerk",
          "Attend the hearing on your request"
        ]
      },

      # Judgment debtor (loser) situations
      %w[judgment_debtor payment_plan] => {
        primary: %w[SC-223],
        conditional: {},
        workflow: nil,
        next_steps: [
          "Complete SC-223 with your proposed payment schedule",
          "File with the court clerk",
          "Attend the hearing on your request"
        ]
      },
      %w[judgment_debtor modify_payments] => {
        primary: %w[SC-225],
        conditional: {},
        workflow: nil,
        next_steps: [
          "Complete SC-225 explaining why you need changes",
          "File with the court clerk",
          "Attend the hearing on your request"
        ]
      },
      %w[judgment_debtor appeal] => {
        primary: %w[SC-300],
        conditional: {},
        workflow: nil,
        info: "Appeals in small claims are limited. You must show the court made a legal error.",
        next_steps: [
          "Review appeal deadlines (usually 30 days)",
          "Complete SC-300 explaining the legal error",
          "File with the appellate division of Superior Court"
        ]
      }
    }.freeze

    def initialize(answers)
      @answers = answers.with_indifferent_access
    end

    def recommend
      key = [ @answers[:role], @answers[:situation] ]
      config = RECOMMENDATIONS[key]

      return empty_recommendation if config.nil?

      build_recommendation(config)
    end

    def forms
      recommend[:forms]
    end

    def workflow
      recommend[:workflow]
    end

    def next_steps
      recommend[:next_steps]
    end

    private

    def build_recommendation(config)
      form_codes = config[:primary].dup

      # Add conditional forms based on answers
      config[:conditional].each do |condition, codes|
        form_codes.concat(codes) if @answers[condition]
      end

      forms = load_forms(form_codes)
      workflow = load_workflow(config[:workflow])

      {
        forms: forms,
        workflow: workflow,
        next_steps: config[:next_steps] || [],
        info: config[:info]
      }
    end

    def load_forms(codes)
      return [] if codes.empty?

      # Build CASE statement with properly sanitized values using ? placeholders
      when_clauses = codes.map.with_index do |_, i|
        "WHEN code = ? THEN #{i.to_i}"
      end.join(" ")

      # Use sanitize_sql_array for safe SQL generation
      safe_sql = ActiveRecord::Base.sanitize_sql_array(
        [ "CASE #{when_clauses} END" ] + codes
      )

      FormDefinition.where(code: codes).order(Arel.sql(safe_sql))
    end

    def load_workflow(slug)
      return nil if slug.blank?

      Workflow.find_by(slug: slug)
    end

    def empty_recommendation
      {
        forms: [],
        workflow: nil,
        next_steps: [],
        info: "We couldn't find specific forms for your situation. Please browse our form catalog or contact the court clerk for assistance."
      }
    end
  end
end
