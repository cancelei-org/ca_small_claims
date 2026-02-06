# frozen_string_literal: true

# California Small Claims Court Locations
# Data includes major courthouse locations for each county

puts "\n--- Loading Courthouses ---"

# Courthouse data with coordinates for map display
# Coordinates sourced from official court addresses via geocoding
courthouses_data = [
  # Alameda County
  {
    name: "Alameda County Superior Court - Oakland",
    court_type: "small_claims",
    address: "1225 Fallon Street",
    city: "Oakland",
    county: "Alameda",
    zip: "94612",
    phone: "(510) 891-6000",
    hours: "8:30 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.alameda.courts.ca.gov/self-help/small-claims",
    latitude: 37.8003,
    longitude: -122.2652
  },
  {
    name: "Alameda County Superior Court - Fremont Hall of Justice",
    court_type: "small_claims",
    address: "39439 Paseo Padre Parkway",
    city: "Fremont",
    county: "Alameda",
    zip: "94538",
    phone: "(510) 795-2300",
    hours: "8:30 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.alameda.courts.ca.gov",
    latitude: 37.5559,
    longitude: -121.9816
  },

  # Contra Costa County
  {
    name: "Contra Costa County Superior Court - Martinez",
    court_type: "small_claims",
    address: "725 Court Street",
    city: "Martinez",
    county: "Contra Costa",
    zip: "94553",
    phone: "(925) 608-1000",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.cc-courts.org/civil/small-claims.aspx",
    latitude: 37.9986,
    longitude: -122.1343
  },
  {
    name: "Contra Costa County Superior Court - Richmond",
    court_type: "small_claims",
    address: "100 37th Street",
    city: "Richmond",
    county: "Contra Costa",
    zip: "94805",
    phone: "(510) 374-3138",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.cc-courts.org",
    latitude: 37.9336,
    longitude: -122.3542
  },

  # Fresno County
  {
    name: "Fresno County Superior Court - B.F. Sisk Courthouse",
    court_type: "small_claims",
    address: "1130 O Street",
    city: "Fresno",
    county: "Fresno",
    zip: "93724",
    phone: "(559) 457-2000",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.fresno.courts.ca.gov/civil/small-claims",
    latitude: 36.7330,
    longitude: -119.7890
  },

  # Kern County
  {
    name: "Kern County Superior Court - Metropolitan Division",
    court_type: "small_claims",
    address: "1215 Truxtun Avenue",
    city: "Bakersfield",
    county: "Kern",
    zip: "93301",
    phone: "(661) 868-2100",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.kern.courts.ca.gov",
    latitude: 35.3766,
    longitude: -119.0161
  },

  # Los Angeles County - Multiple courthouses
  {
    name: "Stanley Mosk Courthouse (Central District)",
    court_type: "small_claims",
    address: "111 North Hill Street",
    city: "Los Angeles",
    county: "Los Angeles",
    zip: "90012",
    phone: "(213) 830-0803",
    hours: "8:30 AM - 4:30 PM, Monday - Friday",
    website_url: "https://www.lacourt.org/division/smallclaims/smallclaims.aspx",
    latitude: 34.0549,
    longitude: -118.2445
  },
  {
    name: "Compton Courthouse",
    court_type: "small_claims",
    address: "200 West Compton Boulevard",
    city: "Compton",
    county: "Los Angeles",
    zip: "90220",
    phone: "(310) 761-8100",
    hours: "8:30 AM - 4:30 PM, Monday - Friday",
    website_url: "https://www.lacourt.org",
    latitude: 33.8970,
    longitude: -118.2238
  },
  {
    name: "Van Nuys Courthouse East",
    court_type: "small_claims",
    address: "6230 Sylmar Avenue",
    city: "Van Nuys",
    county: "Los Angeles",
    zip: "91401",
    phone: "(818) 374-2100",
    hours: "8:30 AM - 4:30 PM, Monday - Friday",
    website_url: "https://www.lacourt.org",
    latitude: 34.1870,
    longitude: -118.4490
  },
  {
    name: "Torrance Courthouse",
    court_type: "small_claims",
    address: "825 Maple Avenue",
    city: "Torrance",
    county: "Los Angeles",
    zip: "90503",
    phone: "(310) 222-8808",
    hours: "8:30 AM - 4:30 PM, Monday - Friday",
    website_url: "https://www.lacourt.org",
    latitude: 33.8356,
    longitude: -118.3251
  },
  {
    name: "Pasadena Courthouse",
    court_type: "small_claims",
    address: "300 East Walnut Street",
    city: "Pasadena",
    county: "Los Angeles",
    zip: "91101",
    phone: "(626) 396-3306",
    hours: "8:30 AM - 4:30 PM, Monday - Friday",
    website_url: "https://www.lacourt.org",
    latitude: 34.1455,
    longitude: -118.1434
  },
  {
    name: "Santa Monica Courthouse",
    court_type: "small_claims",
    address: "1725 Main Street",
    city: "Santa Monica",
    county: "Los Angeles",
    zip: "90401",
    phone: "(310) 260-3762",
    hours: "8:30 AM - 4:30 PM, Monday - Friday",
    website_url: "https://www.lacourt.org",
    latitude: 34.0110,
    longitude: -118.4936
  },
  {
    name: "Pomona Courthouse South",
    court_type: "small_claims",
    address: "400 Civic Center Plaza",
    city: "Pomona",
    county: "Los Angeles",
    zip: "91766",
    phone: "(909) 802-1100",
    hours: "8:30 AM - 4:30 PM, Monday - Friday",
    website_url: "https://www.lacourt.org",
    latitude: 34.0558,
    longitude: -117.7496
  },
  {
    name: "Long Beach Courthouse",
    court_type: "small_claims",
    address: "275 Magnolia Avenue",
    city: "Long Beach",
    county: "Los Angeles",
    zip: "90802",
    phone: "(562) 491-6038",
    hours: "8:30 AM - 4:30 PM, Monday - Friday",
    website_url: "https://www.lacourt.org",
    latitude: 33.7697,
    longitude: -118.1948
  },

  # Marin County
  {
    name: "Marin County Superior Court",
    court_type: "small_claims",
    address: "3501 Civic Center Drive",
    city: "San Rafael",
    county: "Marin",
    zip: "94903",
    phone: "(415) 444-7020",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.marincourt.org",
    latitude: 37.9989,
    longitude: -122.5310
  },

  # Monterey County
  {
    name: "Monterey County Superior Court",
    court_type: "small_claims",
    address: "1200 Aguajito Road",
    city: "Monterey",
    county: "Monterey",
    zip: "93940",
    phone: "(831) 647-5800",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.monterey.courts.ca.gov",
    latitude: 36.5871,
    longitude: -121.8691
  },

  # Orange County
  {
    name: "Orange County Superior Court - Central Justice Center",
    court_type: "small_claims",
    address: "700 Civic Center Drive West",
    city: "Santa Ana",
    county: "Orange",
    zip: "92701",
    phone: "(657) 622-6878",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.occourts.org/directory/civil/small-claims.html",
    latitude: 33.7488,
    longitude: -117.8695
  },
  {
    name: "Orange County Superior Court - Harbor Justice Center",
    court_type: "small_claims",
    address: "4601 Jamboree Road",
    city: "Newport Beach",
    county: "Orange",
    zip: "92660",
    phone: "(657) 622-5255",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.occourts.org",
    latitude: 33.6478,
    longitude: -117.8618
  },
  {
    name: "Orange County Superior Court - North Justice Center",
    court_type: "small_claims",
    address: "1275 North Berkeley Avenue",
    city: "Fullerton",
    county: "Orange",
    zip: "92832",
    phone: "(657) 622-6225",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.occourts.org",
    latitude: 33.8813,
    longitude: -117.9222
  },

  # Riverside County
  {
    name: "Riverside County Superior Court - Historic Courthouse",
    court_type: "small_claims",
    address: "4050 Main Street",
    city: "Riverside",
    county: "Riverside",
    zip: "92501",
    phone: "(951) 777-3147",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.riverside.courts.ca.gov/SelfHelp/SmallClaims/small-claims.php",
    latitude: 33.9807,
    longitude: -117.3755
  },
  {
    name: "Riverside County Superior Court - Palm Springs",
    court_type: "small_claims",
    address: "3255 East Tahquitz Canyon Way",
    city: "Palm Springs",
    county: "Riverside",
    zip: "92262",
    phone: "(760) 393-2660",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.riverside.courts.ca.gov",
    latitude: 33.8241,
    longitude: -116.5204
  },

  # Sacramento County
  {
    name: "Sacramento County Superior Court - Gordon D. Schaber Courthouse",
    court_type: "small_claims",
    address: "720 9th Street",
    city: "Sacramento",
    county: "Sacramento",
    zip: "95814",
    phone: "(916) 874-5522",
    hours: "8:30 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.saccourt.ca.gov/small-claims/small-claims.aspx",
    latitude: 38.5801,
    longitude: -121.4961
  },

  # San Bernardino County
  {
    name: "San Bernardino County Superior Court - Civil Division",
    court_type: "small_claims",
    address: "247 West Third Street",
    city: "San Bernardino",
    county: "San Bernardino",
    zip: "92415",
    phone: "(909) 708-8606",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sb-court.org/divisions/civil/small-claims",
    latitude: 34.1078,
    longitude: -117.2908
  },
  {
    name: "San Bernardino County Superior Court - Victorville",
    court_type: "small_claims",
    address: "14455 Civic Drive",
    city: "Victorville",
    county: "San Bernardino",
    zip: "92392",
    phone: "(760) 243-8600",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sb-court.org",
    latitude: 34.5226,
    longitude: -117.3197
  },

  # San Diego County
  {
    name: "San Diego County Superior Court - Central Division",
    court_type: "small_claims",
    address: "330 West Broadway",
    city: "San Diego",
    county: "San Diego",
    zip: "92101",
    phone: "(619) 450-7100",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sdcourt.ca.gov/sdcourt/civil2/smallclaims",
    latitude: 32.7197,
    longitude: -117.1647
  },
  {
    name: "San Diego County Superior Court - North County Division",
    court_type: "small_claims",
    address: "325 South Melrose Drive",
    city: "Vista",
    county: "San Diego",
    zip: "92081",
    phone: "(760) 940-4373",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sdcourt.ca.gov",
    latitude: 33.1976,
    longitude: -117.2376
  },
  {
    name: "San Diego County Superior Court - East County Division",
    court_type: "small_claims",
    address: "250 East Main Street",
    city: "El Cajon",
    county: "San Diego",
    zip: "92020",
    phone: "(619) 456-4101",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sdcourt.ca.gov",
    latitude: 32.7943,
    longitude: -116.9595
  },
  {
    name: "San Diego County Superior Court - South County Division",
    court_type: "small_claims",
    address: "500 Third Avenue",
    city: "Chula Vista",
    county: "San Diego",
    zip: "91910",
    phone: "(619) 409-2698",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sdcourt.ca.gov",
    latitude: 32.6394,
    longitude: -117.0827
  },

  # San Francisco County
  {
    name: "San Francisco County Superior Court - Civic Center Courthouse",
    court_type: "small_claims",
    address: "400 McAllister Street",
    city: "San Francisco",
    county: "San Francisco",
    zip: "94102",
    phone: "(415) 551-3800",
    hours: "8:30 AM - 4:30 PM, Monday - Friday",
    website_url: "https://sfsuperiorcourt.org/divisions/civil/small-claims",
    latitude: 37.7805,
    longitude: -122.4168
  },

  # San Joaquin County
  {
    name: "San Joaquin County Superior Court",
    court_type: "small_claims",
    address: "180 East Weber Avenue",
    city: "Stockton",
    county: "San Joaquin",
    zip: "95202",
    phone: "(209) 992-5200",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sjcourts.org",
    latitude: 37.9577,
    longitude: -121.2907
  },

  # San Luis Obispo County
  {
    name: "San Luis Obispo County Superior Court",
    court_type: "small_claims",
    address: "1035 Palm Street",
    city: "San Luis Obispo",
    county: "San Luis Obispo",
    zip: "93408",
    phone: "(805) 781-5421",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.slo.courts.ca.gov",
    latitude: 35.2795,
    longitude: -120.6641
  },

  # San Mateo County
  {
    name: "San Mateo County Superior Court - Hall of Justice",
    court_type: "small_claims",
    address: "400 County Center",
    city: "Redwood City",
    county: "San Mateo",
    zip: "94063",
    phone: "(650) 261-5000",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sanmateocourt.org",
    latitude: 37.4878,
    longitude: -122.2281
  },

  # Santa Barbara County
  {
    name: "Santa Barbara County Superior Court - Anacapa Division",
    court_type: "small_claims",
    address: "1100 Anacapa Street",
    city: "Santa Barbara",
    county: "Santa Barbara",
    zip: "93101",
    phone: "(805) 882-4500",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sbcourts.org",
    latitude: 34.4234,
    longitude: -119.7006
  },
  {
    name: "Santa Barbara County Superior Court - Santa Maria Division",
    court_type: "small_claims",
    address: "312 East Cook Street",
    city: "Santa Maria",
    county: "Santa Barbara",
    zip: "93454",
    phone: "(805) 346-7400",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sbcourts.org",
    latitude: 34.9519,
    longitude: -120.4358
  },

  # Santa Clara County
  {
    name: "Santa Clara County Superior Court - Downtown Courthouse",
    court_type: "small_claims",
    address: "191 North First Street",
    city: "San Jose",
    county: "Santa Clara",
    zip: "95113",
    phone: "(408) 882-2100",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.scscourt.org/self_help/small_claims/small_claims_home.shtml",
    latitude: 37.3370,
    longitude: -121.8891
  },
  {
    name: "Santa Clara County Superior Court - Palo Alto Courthouse",
    court_type: "small_claims",
    address: "270 Grant Avenue",
    city: "Palo Alto",
    county: "Santa Clara",
    zip: "94306",
    phone: "(650) 462-3900",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.scscourt.org",
    latitude: 37.4427,
    longitude: -122.1430
  },

  # Santa Cruz County
  {
    name: "Santa Cruz County Superior Court",
    court_type: "small_claims",
    address: "701 Ocean Street",
    city: "Santa Cruz",
    county: "Santa Cruz",
    zip: "95060",
    phone: "(831) 420-2200",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.santacruzcourt.org",
    latitude: 36.9786,
    longitude: -122.0262
  },

  # Solano County
  {
    name: "Solano County Superior Court - Hall of Justice",
    court_type: "small_claims",
    address: "600 Union Avenue",
    city: "Fairfield",
    county: "Solano",
    zip: "94533",
    phone: "(707) 207-7300",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.solano.courts.ca.gov",
    latitude: 38.2617,
    longitude: -122.0397
  },

  # Sonoma County
  {
    name: "Sonoma County Superior Court - Hall of Justice",
    court_type: "small_claims",
    address: "600 Administration Drive",
    city: "Santa Rosa",
    county: "Sonoma",
    zip: "95403",
    phone: "(707) 521-6500",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.sonomacourt.org",
    latitude: 38.4577,
    longitude: -122.7258
  },

  # Stanislaus County
  {
    name: "Stanislaus County Superior Court",
    court_type: "small_claims",
    address: "800 11th Street",
    city: "Modesto",
    county: "Stanislaus",
    zip: "95354",
    phone: "(209) 530-3100",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.stanct.org",
    latitude: 37.6396,
    longitude: -120.9977
  },

  # Tulare County
  {
    name: "Tulare County Superior Court",
    court_type: "small_claims",
    address: "221 South Mooney Boulevard",
    city: "Visalia",
    county: "Tulare",
    zip: "93291",
    phone: "(559) 730-5000",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.tularecourt.ca.gov",
    latitude: 36.3246,
    longitude: -119.2930
  },

  # Ventura County
  {
    name: "Ventura County Superior Court - Hall of Justice",
    court_type: "small_claims",
    address: "800 South Victoria Avenue",
    city: "Ventura",
    county: "Ventura",
    zip: "93009",
    phone: "(805) 289-8500",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.ventura.courts.ca.gov/civil/small-claims",
    latitude: 34.2600,
    longitude: -119.2285
  },
  {
    name: "Ventura County Superior Court - East County Courthouse",
    court_type: "small_claims",
    address: "3855 Alamo Street",
    city: "Simi Valley",
    county: "Ventura",
    zip: "93063",
    phone: "(805) 289-8500",
    hours: "8:00 AM - 4:00 PM, Monday - Friday",
    website_url: "https://www.ventura.courts.ca.gov",
    latitude: 34.2743,
    longitude: -118.7370
  }
]

# Create or update courthouses
courthouses_data.each do |data|
  courthouse = Courthouse.find_or_initialize_by(
    name: data[:name],
    county: data[:county]
  )

  courthouse.assign_attributes(data)
  courthouse.save!
  puts "  Created/Updated courthouse: #{courthouse.name} (#{courthouse.county} County)"
end

puts "  Total courthouses: #{Courthouse.count}"
