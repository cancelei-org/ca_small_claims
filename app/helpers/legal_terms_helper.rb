# frozen_string_literal: true

module LegalTermsHelper
  # Common legal terms used in Small Claims Court forms
  # Each term includes a definition and optional link to CA Courts Self-Help
  LEGAL_TERMS = {
    plaintiff: {
      title: "Plaintiff",
      definition: "The person or business filing the lawsuit (suing). In small claims, " \
                  "this is the person who believes they are owed money or property.",
      link: "https://selfhelp.courts.ca.gov/small-claims/plaintiff"
    },
    defendant: {
      title: "Defendant",
      definition: "The person or business being sued. The defendant must respond to " \
                  "the lawsuit and may owe money or property if the plaintiff wins.",
      link: "https://selfhelp.courts.ca.gov/small-claims/defendant"
    },
    venue: {
      title: "Venue",
      definition: "The court location where your case will be heard. Generally, you must " \
                  "file in the county where the defendant lives or where the issue occurred.",
      link: "https://selfhelp.courts.ca.gov/small-claims/file"
    },
    service: {
      title: "Service of Process",
      definition: "The legal requirement to deliver court papers to the other party. " \
                  "Someone 18+ (not you) must deliver the papers and sign a proof of service.",
      link: "https://selfhelp.courts.ca.gov/small-claims/serve"
    },
    judgment: {
      title: "Judgment",
      definition: "The court's final decision in your case. It states who won and how much " \
                  "money (if any) is owed. Collecting the judgment is your responsibility.",
      link: "https://selfhelp.courts.ca.gov/small-claims/judgment"
    },
    claim: {
      title: "Claim Amount",
      definition: "The total amount of money you are asking for. In California Small Claims, " \
                  "individuals can sue for up to $12,500; businesses up to $6,250.",
      link: "https://selfhelp.courts.ca.gov/small-claims/how-much"
    },
    hearing: {
      title: "Hearing",
      definition: "The court date when you present your case to the judge. Both parties " \
                  "can bring evidence and witnesses. The judge decides the case that day.",
      link: "https://selfhelp.courts.ca.gov/small-claims/hearing"
    },
    appeal: {
      title: "Appeal",
      definition: "A request for a new trial if you disagree with the judgment. Only defendants " \
                  "can appeal in small claims court. Appeals must be filed within 30 days.",
      link: "https://selfhelp.courts.ca.gov/small-claims/appeal"
    },
    continuance: {
      title: "Continuance",
      definition: "A request to postpone your court date. You must have a good reason and " \
                  "ask before your hearing date. The judge decides whether to grant it.",
      link: nil
    },
    garnishment: {
      title: "Wage Garnishment",
      definition: "A court order requiring an employer to withhold part of the defendant's " \
                  "wages to pay the judgment. Used when the defendant won't pay voluntarily.",
      link: "https://selfhelp.courts.ca.gov/small-claims/collect"
    }
  }.freeze

  # Render expandable help for a legal term
  # Usage: <%= legal_term_help(:plaintiff) %>
  def legal_term_help(term_key)
    term = LEGAL_TERMS[term_key.to_sym]
    return nil unless term

    expandable_help(
      term[:title],
      term[:definition],
      link_url: term[:link],
      link_text: "Learn more at CA Courts"
    )
  end

  # Get just the definition text for a legal term (for tooltips)
  def legal_term_definition(term_key)
    term = LEGAL_TERMS[term_key.to_sym]
    term&.dig(:definition)
  end

  # Get the title for a legal term
  def legal_term_title(term_key)
    term = LEGAL_TERMS[term_key.to_sym]
    term&.dig(:title)
  end
end
