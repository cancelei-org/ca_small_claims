FactoryBot.define do
  factory :audit_log do
    user { nil }
    event { "MyString" }
    target_type { "MyString" }
    target_id { 1 }
    details { "" }
    ip_address { "MyString" }
    user_agent { "MyString" }
  end
end
