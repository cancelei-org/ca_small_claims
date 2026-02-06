# frozen_string_literal: true

module FormFinderHelper
  SITUATION_OPTIONS = {
    "plaintiff" => [
      {
        value: "new_case",
        label: "Start a new small claims case",
        description: "File a claim to sue someone for money (up to $12,500)",
        icon: "plus-circle"
      },
      {
        value: "modify_claim",
        label: "Modify my existing claim",
        description: "Change the amount, add or remove parties before the hearing",
        icon: "edit"
      },
      {
        value: "subpoena_witness",
        label: "Get a witness to appear",
        description: "Require someone to testify at your hearing",
        icon: "user-plus"
      }
    ],
    "defendant" => [
      {
        value: "respond_only",
        label: "Just respond to the claim",
        description: "Appear at the hearing to defend yourself (no forms needed)",
        icon: "message-circle"
      },
      {
        value: "counter_claim",
        label: "File a counter-claim",
        description: "Sue the plaintiff back as part of the same case",
        icon: "refresh"
      },
      {
        value: "modify_claim",
        label: "Request changes before hearing",
        description: "Ask to change the hearing date or other details",
        icon: "edit"
      }
    ],
    "judgment_holder" => [
      {
        value: "record_payment",
        label: "Record that I was paid",
        description: "File paperwork showing the judgment has been satisfied",
        icon: "check"
      },
      {
        value: "enforce_judgment",
        label: "Collect the money owed",
        description: "Create a lien on property or take enforcement action",
        icon: "dollar"
      },
      {
        value: "correct_judgment",
        label: "Fix an error in the judgment",
        description: "Request correction of clerical or legal errors",
        icon: "alert"
      }
    ],
    "judgment_debtor" => [
      {
        value: "payment_plan",
        label: "Request a payment plan",
        description: "Ask the court to let you pay in installments",
        icon: "calendar"
      },
      {
        value: "modify_payments",
        label: "Change my payment plan",
        description: "Request to modify an existing payment arrangement",
        icon: "edit"
      },
      {
        value: "appeal",
        label: "Appeal the decision",
        description: "Challenge the judgment if the court made a legal error",
        icon: "alert-triangle"
      }
    ]
  }.freeze

  def situation_options_for(role)
    SITUATION_OPTIONS[role] || []
  end

  # Icon name mapping from kebab-case to symbol
  SITUATION_ICON_MAP = {
    "plus-circle" => :plus_circle,
    "edit" => :edit,
    "user-plus" => :user_plus,
    "message-circle" => :message_circle,
    "refresh" => :refresh,
    "check" => :check_circle,
    "dollar" => :dollar_sign,
    "alert" => :alert_circle,
    "calendar" => :calendar,
    "alert-triangle" => :alert_triangle
  }.freeze

  def render_situation_icon(icon_name)
    symbol = SITUATION_ICON_MAP[icon_name] || :question_circle
    icon(symbol, class: "w-6 h-6")
  end
end
