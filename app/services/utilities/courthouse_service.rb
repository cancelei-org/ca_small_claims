# frozen_string_literal: true

module Utilities
  # Provides information about California courthouses and self-help centers
  class CourthouseService
    include Singleton

    COURTHOUSES = {
      "Alameda": {
        name: "Superior Court of Alameda County",
        address: "1225 Fallon Street, Oakland, CA 94612",
        phone: "(510) 891-6000",
        url: "https://www.alameda.courts.ca.gov/self-help/small-claims"
      },
      "Contra Costa": {
        name: "Superior Court of Contra Costa County",
        address: "725 Court Street, Martinez, CA 94553",
        phone: "(925) 608-1000",
        url: "https://www.cc-courts.org/civil/small-claims.aspx"
      },
      "Fresno": {
        name: "Superior Court of Fresno County",
        address: "1130 O Street, Fresno, CA 93724",
        phone: "(559) 457-2000",
        url: "https://www.fresno.courts.ca.gov/civil/small-claims"
      },
      "Los Angeles": {
        name: "Superior Court of Los Angeles County (Stanley Mosk)",
        address: "111 North Hill Street, Los Angeles, CA 90012",
        phone: "(213) 830-0803",
        url: "https://www.lacourt.org/division/smallclaims/smallclaims.aspx"
      },
      "Orange": {
        name: "Superior Court of Orange County",
        address: "700 Civic Center Drive West, Santa Ana, CA 92701",
        phone: "(657) 622-6878",
        url: "https://www.occourts.org/directory/civil/small-claims.html"
      },
      "Riverside": {
        name: "Superior Court of Riverside County",
        address: "4050 Main Street, Riverside, CA 92501",
        phone: "(951) 777-3147",
        url: "https://www.riverside.courts.ca.gov/SelfHelp/SmallClaims/small-claims.php"
      },
      "Sacramento": {
        name: "Superior Court of Sacramento County",
        address: "720 9th Street, Sacramento, CA 95814",
        phone: "(916) 874-5522",
        url: "https://www.saccourt.ca.gov/small-claims/small-claims.aspx"
      },
      "San Bernardino": {
        name: "Superior Court of San Bernardino County",
        address: "247 West Third Street, San Bernardino, CA 92415",
        phone: "(909) 708-8606",
        url: "https://www.sb-court.org/divisions/civil/small-claims"
      },
      "San Diego": {
        name: "Superior Court of San Diego County",
        address: "330 West Broadway, San Diego, CA 92101",
        phone: "(619) 450-7100",
        url: "https://www.sdcourt.ca.gov/sdcourt/civil2/smallclaims"
      },
      "San Francisco": {
        name: "Superior Court of San Francisco County",
        address: "400 McAllister Street, San Francisco, CA 94102",
        phone: "(415) 551-3800",
        url: "https://sfsuperiorcourt.org/divisions/civil/small-claims"
      },
      "Santa Clara": {
        name: "Superior Court of Santa Clara County",
        address: "191 North First Street, San Jose, CA 95113",
        phone: "(408) 882-2100",
        url: "https://www.scscourt.org/self_help/small_claims/small_claims_home.shtml"
      },
      "Ventura": {
        name: "Superior Court of Ventura County",
        address: "800 South Victoria Avenue, Ventura, CA 93009",
        phone: "(805) 289-8500",
        url: "https://www.ventura.courts.ca.gov/civil/small-claims"
      }
    }.freeze

    def self.counties
      COURTHOUSES.keys.sort
    end

    def self.info_for(county)
      COURTHOUSES[county.to_sym] || COURTHOUSES[county.to_s]
    end

    def self.all_courthouses
      COURTHOUSES
    end
  end
end
